#!/usr/bin/env node
/**
 * Admin-only importer for a source pack (`source_packs/*.json`) into the
 * `supplications` collection.
 *
 * This is the ONLY supported path from a reviewed source pack into Firestore.
 * It is deliberately separate from `scripts/ingest_knowledge.mjs`, which
 * targets the `knowledge_chunks` collection.
 *
 * ── What this script guarantees ─────────────────────────────────────────
 *
 * 1. `zoneKey` and `contentKind` are written on EVERY record. These are not
 *    cosmetic: `contentKind` is what stops a procedural ruling from being
 *    rendered under a «دعاء» heading in the app, and `zoneKey` is the stable
 *    slug that survives an admin renaming a zone's `nameAr`.
 *
 * 2. Nothing is ever written as verified. `verificationStatus` is forced to
 *    "unverified" and `verifiedAt`/`verifiedBy` to null, whatever the input
 *    file says. Verification is a human act performed against the printed
 *    page — an import script must not be able to confer it. Consequently
 *    imported records are NOT retrievable by the assistant (the Worker's
 *    provenance gate rejects them) until a human verifies them.
 *
 * 3. A record whose `zoneKey` is non-empty must name a zone that exists in
 *    `lib/shared/data/hajj_zones_seed.dart`; an unknown slug aborts the run
 *    rather than silently orphaning the record.
 *
 * 4. An empty `zoneKey` is legitimate and means "not tied to any one place"
 *    (a general dua, a mosque-entry text, a text covering several miqats).
 *    Such a record must NOT be given a zone here — attributing a general
 *    text to a specific place is exactly the misattribution this pipeline
 *    exists to prevent. The app surfaces those via the coverage matrix,
 *    labelled as general.
 *
 * ── Usage ───────────────────────────────────────────────────────────────
 *
 * DRY RUN IS THE DEFAULT. Without `--write` the script validates the pack,
 * prints the plan, contacts nothing, and does not even read credentials:
 *
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json
 *
 * A real write needs an explicit destination flag AND `--write`, plus
 * confirmations that must match the printed plan:
 *
 *   export FIREBASE_PROJECT_ID=your-project-id
 *   export FIREBASE_ADMIN_TOKEN=$(gcloud auth print-access-token)
 *
 *   # try a single record in staging first
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json \
 *     --staging --limit 1 --write --confirm-project=<id> --confirm-count=1
 *
 *   # the real thing
 *   node scripts/import_source_pack.mjs source_packs/<pack>.json \
 *     --production --write --confirm-project=<id> --confirm-count=<n>
 *
 * `--staging` always means `supplications_staging` and `--production`
 * always means `supplications`; the collection is never taken from input.
 * `--limit` is refused against production. The script is idempotent: the
 * document id is the record's `duaId`, so re-running updates rather than
 * duplicates.
 */

import { readFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";

// The 19 zone slugs defined by `lib/shared/data/hajj_zones_seed.dart`.
// Kept in sync by `test/source_pack_integrity_test.dart`, which reads both
// files and fails if they diverge.
export const KNOWN_ZONE_KEYS = [
  "mataf",
  "kaaba",
  "maqam_ibrahim",
  "zamzam",
  "hajar_aswad",
  "hijr_ismail",
  "masaa",
  "mina",
  "jamrat_aqabah",
  "jamrat_wusta",
  "jamrat_sughra",
  "muzdalifah",
  "mashar_haram",
  "arafat",
  "jabal_rahmah",
  "masjid_namirah",
  "miqat_dhul_hulayfah",
  "miqat_yalamlam",
  "miqat_qarn_manazil",
];

export const KNOWN_CONTENT_KINDS = [
  "specific_text",
  "general_dua",
  "general_dhikr",
  "mosque_entry",
  "procedural_guidance",
  // A narration the source cites to TEACH, not to be repeated — Umar's
  // words at the Black Stone, for instance. Shipping it as a supplication
  // has pilgrims reciting it; shipping it as guidance hides that it is a
  // narration with a chain, and presents it as ministry prose.
  "contextual_evidence",
];

// Content kinds a pilgrim may recite, and which may therefore be played
// aloud. Everything else renders in its own card with no play button.
export const RECITABLE_CONTENT_KINDS = [
  "specific_text",
  "general_dua",
  "general_dhikr",
  "mosque_entry",
];

// The only usage qualifiers a pack may name. `null`/absent is always
// allowed and means "unqualified". An unknown string is a hard error rather
// than a silent pass-through: a qualifier the app cannot render would
// display as nothing at all, which is indistinguishable from a text the
// source never qualified.
export const SUPPORTED_USAGE_QUALIFIERS = ["optional_addition"];

// ── Structured source references ────────────────────────────────────────
//
// Where the MINISTRY says a text comes from — «أخرجه البخاري (1597)» — as
// data rather than prose buried in an admin-only note.
//
// Two rules matter more than the shape:
//
//   1. `citedBy` records WHO made the citation. We are not vouching for a
//      chain of narration; we are reporting that the reviewed page cites
//      one. A reference nobody printed must never appear here.
//   2. A source named without a number gets `referenceKind: "unspecified"`
//      and NO `reference` key. An empty string would read as "we looked and
//      found nothing", and a number recalled from memory would be an
//      invention dressed as provenance.
export const SUPPORTED_REFERENCE_TYPES = [
  "hadith",
  "athar",
  "quran",
  "book",
  "fatwa",
];

export const SUPPORTED_REFERENCE_KINDS = [
  "hadith_number",
  "page",
  "volume_page",
  "surah_ayah",
  "unspecified",
];

// What the MINISTRY says about a citation's chain. Transcription vocabulary,
// not a grading system we author: a value is added only when a printed page
// uses it. Absence is silence — it never means "authenticated".
export const SUPPORTED_SOURCE_ASSESSMENTS = ["weak_isnad"];

// Where the chain STOPS. Orthogonal to soundness: "mawquf" says a report ends
// at a companion, which is a different fact from whether it is strong.
export const SUPPORTED_ATTRIBUTION_LEVELS = ["mawquf"];

// Whether the stored citation list is everything the page cites. MOIA's
// footnotes sometimes end «وغيرهم» — the list is then NAMED, not complete,
// and must never be read as exhaustive.
export const SUPPORTED_REFERENCE_COMPLETENESS = [
  "named_references_only",
  "named_references_plus_unnamed_others",
];

const REFERENCE_REQUIRED_KEYS = [
  "type",
  "collection",
  "referenceKind",
  "citedBy",
  "citedOnPage",
];
const REFERENCE_KNOWN_KEYS = new Set([
  ...REFERENCE_REQUIRED_KEYS,
  "reference",
  "sourceAssessment",
  "attributionLevel",
  "attributedTo",
]);

/** Validates one entry's sourceReferences array. Throws on the first fault. */
export function validateSourceReferences(refs, where) {
  if (refs === undefined) return;
  if (!Array.isArray(refs)) {
    throw new Error(`${where}: sourceReferences must be an array.`);
  }
  refs.forEach((r, i) => {
    const at = `${where}: sourceReferences[${i}]`;
    if (!r || typeof r !== "object" || Array.isArray(r)) {
      throw new Error(`${at} must be an object.`);
    }
    for (const key of Object.keys(r)) {
      if (!REFERENCE_KNOWN_KEYS.has(key)) {
        throw new Error(`${at}: unknown field "${key}".`);
      }
    }
    for (const key of REFERENCE_REQUIRED_KEYS) {
      if (r[key] === undefined || r[key] === null || r[key] === "") {
        throw new Error(`${at}: missing ${key}.`);
      }
    }
    if (!SUPPORTED_REFERENCE_TYPES.includes(r.type)) {
      throw new Error(`${at}: unknown type "${r.type}".`);
    }
    if (!SUPPORTED_REFERENCE_KINDS.includes(r.referenceKind)) {
      throw new Error(`${at}: unknown referenceKind "${r.referenceKind}".`);
    }
    if ("sourceAssessment" in r) {
      if (!SUPPORTED_SOURCE_ASSESSMENTS.includes(r.sourceAssessment)) {
        throw new Error(
          `${at}: unknown sourceAssessment "${r.sourceAssessment}". ` +
            `Supported: ${SUPPORTED_SOURCE_ASSESSMENTS.join(", ")}.`,
        );
      }
      // The Qur'an's transmission is not assessed by isnad grading, and a
      // record's Quran citation must never carry one.
      if (r.type === "quran") {
        throw new Error(`${at}: sourceAssessment is not valid on a quran reference.`);
      }
    }
    if ("attributionLevel" in r) {
      if (!SUPPORTED_ATTRIBUTION_LEVELS.includes(r.attributionLevel)) {
        throw new Error(
          `${at}: unknown attributionLevel "${r.attributionLevel}". ` +
            `Supported: ${SUPPORTED_ATTRIBUTION_LEVELS.join(", ")}.`,
        );
      }
      if (r.type === "quran") {
        throw new Error(`${at}: attributionLevel is not valid on a quran reference.`);
      }
    }
    if ("attributedTo" in r) {
      if (typeof r.attributedTo !== "string" || !r.attributedTo.trim()) {
        throw new Error(`${at}: attributedTo must be a non-empty string.`);
      }
      // Naming who a report stops at only means something once we have said
      // that it stops there at all.
      if (!("attributionLevel" in r)) {
        throw new Error(`${at}: attributedTo requires an attributionLevel.`);
      }
    }
    if (typeof r.collection !== "string" || !r.collection.trim()) {
      throw new Error(`${at}: collection must be a non-empty string.`);
    }
    if (!Number.isInteger(r.citedOnPage) || r.citedOnPage <= 0) {
      throw new Error(`${at}: citedOnPage must be a positive integer.`);
    }
    if ("reference" in r) {
      // Never "" — an empty reference is indistinguishable from a missing
      // one, and the two mean different things.
      if (typeof r.reference !== "string" || !r.reference.trim()) {
        throw new Error(`${at}: reference must be a non-empty string, or absent.`);
      }
      if (r.referenceKind === "unspecified") {
        throw new Error(
          `${at}: referenceKind "unspecified" must not carry a reference.`,
        );
      }
    } else if (r.referenceKind !== "unspecified") {
      throw new Error(
        `${at}: referenceKind "${r.referenceKind}" requires a reference; ` +
          'use "unspecified" when the printed page names no number.',
      );
    }
  });
}

// ── Recitation policy ───────────────────────────────────────────────────
//
// HOW a text is performed: how many times, when, and whether anything comes
// between repetitions. Deliberately NOT folded into `usageQualifier`, which
// describes what a text IS (an optional addition). "Permissible" and "three
// times" are not competing values of one field; they are separate facts that
// can both be true of one text.
//
// This object never makes a record recitable — `contentKind` decides that
// and stays authoritative — and it never touches verification.
export const SUPPORTED_FREQUENCIES = ["once_per_ritual", "repeat_count"];
export const SUPPORTED_TRIGGERS = [
  "first_safa_approach",
  "each_marwah_arrival",
  "on_entry",
];
export const SUPPORTED_INTERLEAVES = ["personal_dua"];

// What automatic playback the app can honestly perform for this record
// TODAY. `manual_only_until_trigger_supported` means: never auto-play.
//
// The case that forced it: `trigger: "first_safa_approach"` has no matching
// event. The Sa'i zone `masaa` is ONE polygon covering the whole corridor,
// so entering it does not establish that the pilgrim is at Safa, let alone
// approaching it for the first time — they may be at Marwah or mid-corridor.
// A once-per-ritual memory guard stops repetition; it cannot make the FIRST
// firing correct. Fail closed: show the text, let the pilgrim start it.
//
// Written explicitly in the pack. Never inferred from a title or an id.
// What a relationship MEANS. Declared, never inferred from the ids: a
// pointer whose purpose is unstated cannot be validated against, and the
// only check worth having here depends on the purpose.
export const SUPPORTED_RELATED_RECORD_ROLES = ["recitation_link"];

export const SUPPORTED_AUTOPLAY_CAPABILITIES = [
  "manual_only_until_trigger_supported",
];

const POLICY_KNOWN_KEYS = new Set([
  "frequency",
  "repeatCount",
  "trigger",
  "interleave",
  "autoRepeat",
  "autoPlayCapability",
]);

/** Validates one entry's recitationPolicy. Throws on the first fault. */
/**
 * Validates one entry's relatedRecordIds.
 *
 * The Marwah guidance points at the canonical Safa dhikr rather than
 * repeating it, so a dangling pointer is not cosmetic: the pilgrim would
 * be shown an instruction to say something the app can no longer show.
 * Every fault below is a hard error — the importer never publishes a
 * relationship it cannot resolve inside the very pack being imported.
 *
 * `knownIds` is the set of duaIds in THIS pack. Cross-pack references are
 * refused for the same reason: the importer cannot verify them.
 */
export function validateRelatedRecordIds(
  raw,
  selfId,
  byId,
  role,
  where,
) {
  const knownIds = byId instanceof Map ? new Set(byId.keys()) : byId;
  if (role !== undefined && role !== null) {
    if (!SUPPORTED_RELATED_RECORD_ROLES.includes(role)) {
      throw new Error(
        `${where}: unknown relatedRecordRole "${role}". ` +
          `Supported: ${SUPPORTED_RELATED_RECORD_ROLES.join(", ")}.`,
      );
    }
  }
  if (raw === undefined || raw === null) return;
  if (!Array.isArray(raw)) {
    throw new Error(`${where}: relatedRecordIds must be an array.`);
  }
  // A pointer with no declared purpose cannot be checked, and the UI would
  // have to guess how to render it. Refuse rather than guess.
  if (raw.length > 0 && !role) {
    throw new Error(
      `${where}: relatedRecordIds requires a relatedRecordRole.`,
    );
  }
  const seen = new Set();
  for (const id of raw) {
    if (typeof id !== "string" || !id.trim()) {
      throw new Error(
        `${where}: relatedRecordIds entries must be non-empty strings.`,
      );
    }
    const v = id.trim();
    if (v === selfId) {
      throw new Error(`${where}: relatedRecordIds must not reference itself.`);
    }
    if (seen.has(v)) {
      throw new Error(`${where}: duplicate relatedRecordId "${v}".`);
    }
    seen.add(v);
    if (!knownIds.has(v)) {
      throw new Error(
        `${where}: relatedRecordId "${v}" is not present in this pack.`,
      );
    }
    // A "say the like of what was said there" link must land on something
    // the pilgrim can actually say. Pointing it at guidance would put a
    // recitation link on a card that has no recitation and no play button —
    // an arrow to a dead end, dressed as an instruction.
    if (role === "recitation_link" && byId instanceof Map) {
      const targetKind = byId.get(v);
      if (!RECITABLE_CONTENT_KINDS.includes(targetKind)) {
        throw new Error(
          `${where}: relatedRecordId "${v}" has contentKind ` +
            `"${targetKind}", which is not recitable — a recitation_link ` +
            "must point at a text the pilgrim may say.",
        );
      }
    }
  }
}

/**
 * Validates the record-level citation-completeness declaration.
 *
 * Its whole purpose is to stop a NAMED list from being read as a COMPLETE
 * one. Declaring completeness with no references at all would say something
 * about a list that does not exist, so it is refused.
 */
export function validateReferenceCompleteness(raw, refs, where) {
  if (raw === undefined || raw === null) return;
  if (!SUPPORTED_REFERENCE_COMPLETENESS.includes(raw)) {
    throw new Error(
      `${where}: unknown sourceReferencesCompleteness "${raw}". ` +
        `Supported: ${SUPPORTED_REFERENCE_COMPLETENESS.join(", ")}.`,
    );
  }
  if (!Array.isArray(refs) || refs.length === 0) {
    throw new Error(
      `${where}: sourceReferencesCompleteness needs at least one reference.`,
    );
  }
}

/** Validates one entry's usageNoteAr: absent, or a non-empty string. */
export function validateUsageNote(raw, where) {
  if (raw === undefined || raw === null) return;
  if (typeof raw !== "string") {
    throw new Error(`${where}: usageNoteAr must be a string.`);
  }
  // An empty string would render as a blank instruction line, which reads
  // as "there is guidance here" while saying nothing. Omit the field.
  if (raw.trim() === "") {
    throw new Error(`${where}: usageNoteAr must not be empty — omit it.`);
  }
  if (raw.length > 400) {
    throw new Error(`${where}: usageNoteAr exceeds 400 characters.`);
  }
}

export function validateRecitationPolicy(policy, where) {
  if (policy === undefined || policy === null) return;
  if (typeof policy !== "object" || Array.isArray(policy)) {
    throw new Error(`${where}: recitationPolicy must be an object or null.`);
  }
  for (const key of Object.keys(policy)) {
    if (!POLICY_KNOWN_KEYS.has(key)) {
      throw new Error(`${where}: recitationPolicy has unknown field "${key}".`);
    }
  }
  if (!SUPPORTED_FREQUENCIES.includes(policy.frequency)) {
    throw new Error(
      `${where}: recitationPolicy.frequency must be one of ` +
        `${SUPPORTED_FREQUENCIES.join(", ")}.`,
    );
  }
  if (policy.frequency === "repeat_count") {
    if (!Number.isInteger(policy.repeatCount) ||
        policy.repeatCount < 1 || policy.repeatCount > 10) {
      throw new Error(
        `${where}: recitationPolicy.repeatCount must be an integer 1-10.`,
      );
    }
  } else if ("repeatCount" in policy) {
    throw new Error(
      `${where}: recitationPolicy.repeatCount belongs only with ` +
        'frequency "repeat_count".',
    );
  }
  if ("trigger" in policy && !SUPPORTED_TRIGGERS.includes(policy.trigger)) {
    throw new Error(`${where}: unknown recitationPolicy.trigger "${policy.trigger}".`);
  }
  if ("interleave" in policy &&
      !SUPPORTED_INTERLEAVES.includes(policy.interleave)) {
    throw new Error(
      `${where}: unknown recitationPolicy.interleave "${policy.interleave}".`,
    );
  }
  if ("autoPlayCapability" in policy &&
      !SUPPORTED_AUTOPLAY_CAPABILITIES.includes(policy.autoPlayCapability)) {
    throw new Error(
      `${where}: unknown recitationPolicy.autoPlayCapability ` +
        `"${policy.autoPlayCapability}".`,
    );
  }
  // A trigger the app cannot detect must say so. Declaring a trigger while
  // leaving auto-play enabled is the exact gap this field exists to close:
  // the app would fire on the nearest coarse event it has and call it the
  // trigger the source named.
  if (policy.trigger === "first_safa_approach" &&
      policy.autoPlayCapability !== "manual_only_until_trigger_supported") {
    throw new Error(
      `${where}: trigger "first_safa_approach" has no supporting event; ` +
        'set autoPlayCapability "manual_only_until_trigger_supported".',
    );
  }
  if ("autoRepeat" in policy && typeof policy.autoRepeat !== "boolean") {
    throw new Error(`${where}: recitationPolicy.autoRepeat must be a boolean.`);
  }
  // A repetition the pilgrim fills with their own dua cannot be performed by
  // a player on their behalf.
  if (policy.autoRepeat === true && "interleave" in policy) {
    throw new Error(
      `${where}: recitationPolicy.autoRepeat must stay false when ` +
        "interleave is present.",
    );
  }
}

// ── The document schema ─────────────────────────────────────────────────
//
// Every field written to Firestore is listed here explicitly. This replaces
// an earlier hand-written object literal that silently dropped any field the
// packs gained later — `ritualKey` and `appliesToZoneKeys` (the two fields
// that stop the Talbiyah being pinned to one miqat) and the whole Quranic
// provenance block were being lost on import, so imported records were
// poorer than the reviewed pack and nothing said so.
//
// A whole-object spread would have "fixed" that while creating a worse
// problem: any typo or stray key in a pack would flow straight into
// production documents. So the schema is explicit in both directions —
// listed fields are copied, unlisted fields are a hard error.

/** Forced by the importer regardless of what the pack says. */
const FORCED_FIELDS = {
  // Verification is a human act performed against the printed page. An
  // import script must never be able to confer it.
  verificationStatus: "unverified",
  verifiedAt: null,
  verifiedBy: null,
  revokedAt: null,
  // Playback/analytics defaults owned by the app, not by the source.
  audioMode: "tts",
  audioUrl: "",
  usage_count: 0,
};

/** Must be present and non-empty in the pack. */
const REQUIRED_FIELDS = ["duaId", "contentKind", "zoneKey", "title", "text"];

/**
 * Copied when present. The default applies ONLY when the key is absent from
 * the pack entry — an explicit `null` or `""` is preserved as written,
 * because in this data those carry meaning: `zoneKey: ""` says "not tied to
 * any one place", and a null `contentHash` says "not yet computed". Coercing
 * either would turn a deliberate statement into a guess.
 */
const OPTIONAL_FIELDS = {
  zoneId: "",
  zoneNameAr: "",
  tagsAr: [],
  tagsEn: [],
  languageCodes: ["ar"],
  isActive: true,

  // Ministry (context) provenance.
  authority: "",
  sourceUrl: "",
  sourceVersion: "",
  sourceLanguage: "",
  sourceSection: "",
  printedPage: null,
  contentHash: null,
  contextAuthority: "",
  contextSourceUrl: "",

  // Ritual scope: a text the source ties to a rite spanning several zones
  // rather than to one spot. Dropping these two silently re-attached such a
  // text to a single place — the exact misattribution this pipeline exists
  // to prevent.
  ritualKey: "",
  appliesToZoneKeys: [],

  // How the source describes the text's USE, as opposed to what it is.
  // Default `null` means "the source described no usage" — deliberately
  // NOT "mandatory". There is no mandatory value and there will not be
  // one: most texts in the book carry no such description, and labelling
  // them obligatory merely for lacking one would assert a ruling nobody
  // made. See SUPPORTED_USAGE_QUALIFIERS.
  usageQualifier: null,

  // Where the ministry says the text comes from. Empty array = the page
  // cited nothing, which is different from "we have not looked".
  sourceReferences: [],

  // How the source says the text is performed. null = it did not say.
  recitationPolicy: null,

  // Pointer to the canonical recitable record this guidance refers to,
  // by ID only. Empty = this record stands alone.
  relatedRecordIds: [],

  // What the pointer means. Required whenever relatedRecordIds is non-empty.
  relatedRecordRole: null,

  // Usage guidance lifted from the printed page. Empty = the page said
  // nothing beyond the text itself.
  usageNoteAr: "",

  // Is the stored citation list everything the page cites? null = not stated.
  sourceReferencesCompleteness: null,

  // Quranic text authority (King Fahd Complex) — see
  // source_packs/QURAN_TEXT_AUTHORITY.md.
  quranRef: null,
  isPortionOfAyah: false,
  textAuthority: "",
  textAuthoritySourceUrl: "",
  textRiwayah: "",
  textRasm: "",
  textEdition: "",
  textEditionDate: "",

  // Classification and review aids the human verifier needs in the console.
  isGeneralSupplication: false,
  reviewNotes: "",
  visuallyUncertain: [],
};

/** Every key a pack entry may legitimately carry. */
export const KNOWN_PACK_FIELDS = new Set([
  ...REQUIRED_FIELDS,
  ...Object.keys(OPTIONAL_FIELDS),
  // A pack may restate a forced field (they all carry verificationStatus);
  // the value is ignored, but the key is not an error.
  ...Object.keys(FORCED_FIELDS),
]);

// ── Field ownership ─────────────────────────────────────────────────────
//
// Who owns each of the 47 fields decides what an import may overwrite. The
// question only became urgent once there were live documents: a PATCH with
// no updateMask REPLACES the document, so every field absent from the
// payload is deleted. That silently reset `usage_count`, wiped a hand-set
// `audioUrl`, and removed any admin field this script has never heard of.
//
// The four classes below are exhaustive over the payload and are asserted to
// be so at module load. D is the class that cannot be enumerated — which is
// exactly why it needs an updateMask rather than a list.

/**
 * A — owned by the source pack. The pack is the authority; an import may
 * freely overwrite these, because that is the whole point of importing.
 */
export const PACK_OWNED_FIELDS = Object.freeze([
  ...REQUIRED_FIELDS,
  ...Object.keys(OPTIONAL_FIELDS),
]);

/**
 * B — operational. Owned by the running app and its admins, never by the
 * pack. On a NEW document the importer seeds them; on an EXISTING one it
 * must leave whatever is there alone.
 *
 *   audioMode / audioUrl  a recording an admin uploaded by hand. Re-importing
 *                         the text is not a reason to unpublish the audio.
 *   usage_count           live analytics the pilgrim's own client increments
 *                         (firestore.rules allows exactly this one field).
 */
export const OPERATIONAL_FIELDS = Object.freeze([
  "audioMode",
  "audioUrl",
  "usage_count",
]);

/**
 * C — verification. Always written, on create AND on update, always to the
 * unverified state. Re-importing content invalidates any prior approval: the
 * bytes a human approved are not necessarily the bytes now being written, so
 * the record must fall out of the pilgrim's view until someone re-approves
 * it. This is a fail-closed reset, not a preservation.
 */
export const VERIFICATION_FIELDS = Object.freeze([
  "verificationStatus",
  "verifiedAt",
  "verifiedBy",
  "revokedAt",
]);

/**
 * D — unknown administrative fields. Not listed, because they cannot be:
 * anything the admin console or a future migration adds lives here. They are
 * protected structurally — by never appearing in the updateMask — rather
 * than by enumeration. A list would be wrong the moment someone adds a field.
 */
export const UNKNOWN_ADMIN_FIELDS_ARE_PRESERVED = true;

/** The mask used when a document already exists: A ∪ C, never B, never D. */
export const UPDATE_MASK_FIELDS = Object.freeze([
  ...PACK_OWNED_FIELDS,
  ...VERIFICATION_FIELDS,
]);

// The classification must cover the payload exactly — no field unclassified,
// none claimed twice. Checked here so a new field cannot be added to the
// schema without someone deciding who owns it.
{
  const classified = [
    ...PACK_OWNED_FIELDS,
    ...OPERATIONAL_FIELDS,
    ...VERIFICATION_FIELDS,
  ];
  const dupes = classified.filter((f, i) => classified.indexOf(f) !== i);
  if (dupes.length) {
    throw new Error(`Field claimed by two ownership classes: ${dupes}`);
  }
  const payload = new Set([
    ...REQUIRED_FIELDS,
    ...Object.keys(OPTIONAL_FIELDS),
    ...Object.keys(FORCED_FIELDS),
  ]);
  const missing = [...payload].filter((f) => !classified.includes(f));
  const extra = classified.filter((f) => !payload.has(f));
  if (missing.length || extra.length) {
    throw new Error(
      `Field ownership does not cover the payload. Unclassified: ` +
        `${missing.join(", ") || "none"}. Not in payload: ` +
        `${extra.join(", ") || "none"}.`,
    );
  }
}

/**
 * Validates a pack and returns the Firestore-shaped records to write.
 * Throws on the first structural problem — a partial import is worse than
 * no import.
 */
export function buildRecords(pack) {
  const entries = pack?.entries;
  if (!Array.isArray(entries) || entries.length === 0) {
    throw new Error("Pack has no `entries` array.");
  }

  // Every duaId in THIS pack, gathered before validation so a relationship
  // may point forwards as well as backwards.
  const knownIds = new Map(
    entries
      .filter((e) => typeof e?.duaId === "string" && e.duaId.trim())
      .map((e) => [
        e.duaId.trim(),
        typeof e?.contentKind === "string" ? e.contentKind.trim() : "",
      ]),
  );

  const seen = new Set();
  return entries.map((entry, index) => {
    const where = `entry #${index} (${entry?.duaId || "no duaId"})`;

    // Unknown keys are refused, never dropped. A field nobody planned for is
    // either a typo or a schema change; both need a human, and silently
    // discarding it is how the previous bug went unnoticed.
    for (const key of Object.keys(entry ?? {})) {
      if (!KNOWN_PACK_FIELDS.has(key)) {
        throw new Error(
          `${where}: unknown field "${key}". Add it to OPTIONAL_FIELDS in ` +
            "scripts/import_source_pack.mjs if it is meant to be imported.",
        );
      }
    }

    const duaId = String(entry?.duaId || "").trim();
    if (!duaId) throw new Error(`${where}: missing duaId.`);
    if (seen.has(duaId)) throw new Error(`${where}: duplicate duaId.`);
    seen.add(duaId);

    const contentKind = String(entry?.contentKind || "").trim();
    if (!KNOWN_CONTENT_KINDS.includes(contentKind)) {
      throw new Error(`${where}: unknown contentKind "${contentKind}".`);
    }

    // `zoneKey` must be present on every entry. Absent is an error, because
    // absence is ambiguous — we cannot tell "not tied to a place" from
    // "someone forgot". Empty string is the explicit way to say the former.
    if (!Object.prototype.hasOwnProperty.call(entry, "zoneKey")) {
      throw new Error(`${where}: missing zoneKey (use "" if not zone-tied).`);
    }
    const zoneKey = String(entry.zoneKey || "").trim();
    if (zoneKey && !KNOWN_ZONE_KEYS.includes(zoneKey)) {
      throw new Error(`${where}: unknown zoneKey "${zoneKey}".`);
    }

    // Every zone a ritual-scoped text claims must exist too, or the text
    // would surface at a place the seed does not define.
    const appliesTo = entry.appliesToZoneKeys;
    if (appliesTo !== undefined) {
      if (!Array.isArray(appliesTo)) {
        throw new Error(`${where}: appliesToZoneKeys must be an array.`);
      }
      for (const key of appliesTo) {
        if (!KNOWN_ZONE_KEYS.includes(String(key))) {
          throw new Error(`${where}: appliesToZoneKeys has unknown "${key}".`);
        }
      }
    }

    // A usage qualifier the app cannot render would show as no badge at
    // all — the same as a text the source never qualified. Refuse rather
    // than let the distinction disappear.
    const qualifier = entry.usageQualifier;
    if (qualifier !== undefined && qualifier !== null) {
      if (typeof qualifier !== "string") {
        throw new Error(`${where}: usageQualifier must be a string or null.`);
      }
      if (!SUPPORTED_USAGE_QUALIFIERS.includes(qualifier)) {
        throw new Error(
          `${where}: unknown usageQualifier "${qualifier}". ` +
            `Supported: ${SUPPORTED_USAGE_QUALIFIERS.join(", ")}.`,
        );
      }
    }

    validateSourceReferences(entry.sourceReferences, where);
    validateReferenceCompleteness(
      entry.sourceReferencesCompleteness,
      entry.sourceReferences,
      where,
    );
    validateRecitationPolicy(entry.recitationPolicy, where);
    validateRelatedRecordIds(
      entry.relatedRecordIds,
      duaId,
      knownIds,
      entry.relatedRecordRole ?? null,
      where,
    );
    validateUsageNote(entry.usageNoteAr, where);

    const textAr = String(entry?.text?.ar || "").trim();
    if (!textAr) throw new Error(`${where}: empty Arabic text.`);

    const record = {
      duaId,
      contentKind,
      zoneKey,
      title: entry.title,
      text: entry.text,
    };

    for (const [key, fallback] of Object.entries(OPTIONAL_FIELDS)) {
      // hasOwnProperty, not `??` — an explicit null must survive as null.
      record[key] = Object.prototype.hasOwnProperty.call(entry, key)
        ? entry[key]
        : fallback;
    }

    for (const [key, value] of Object.entries(FORCED_FIELDS)) {
      record[key] = value;
    }

    return record;
  });
}

// ── The wire ────────────────────────────────────────────────────────────
//
// Every request goes through these three helpers so a test can hand in a
// fake `fetch` and drive the whole write path with no network and no
// credential. `plan.token` is passed in a header and never logged; the
// helpers below never print a URL or a response body.

export function documentUrl(plan, duaId) {
  return (
    `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
    `/databases/${plan.database}/documents/${plan.collection}` +
    `/${encodeURIComponent(duaId)}`
  );
}

/**
 * Does the document already exist? Never guessed — a 404 from a real GET is
 * the only thing that licenses a create, and anything else is an error we
 * must not paper over by writing.
 */
export async function readExisting(duaId, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const res = await doFetch(documentUrl(plan, duaId), {
    headers: { Authorization: `Bearer ${plan.token}` },
  });
  if (res.status === 404) return null;
  if (!res.ok) {
    throw new Error(`read of ${duaId} failed: HTTP ${res.status}`);
  }
  const body = await res.json();
  const out = {};
  for (const [k, v] of Object.entries(body.fields ?? {})) {
    out[k] = fromFirestoreValue(v);
  }
  return out;
}

/**
 * The request for one record, given whether the document already exists.
 *
 *   create  every field, including the operational seeds.
 *   update  updateMask = A ∪ C. B is absent from mask AND body, so the live
 *           values survive; D is absent from the mask, so unknown admin
 *           fields survive too.
 *
 * The verification fields are in the mask on BOTH paths and are serialised
 * as nullValue rather than omitted: a masked field missing from the body is
 * DELETED by Firestore, which would leave the document with no verifiedAt at
 * all. Writing null keeps the field present and explicitly empty, which is
 * what the schema and the security rules expect.
 */
export function buildWriteRequest(record, existing, plan) {
  const isCreate = existing === null || existing === undefined;
  const bodyFields = isCreate
    ? Object.keys(record)
    : UPDATE_MASK_FIELDS.filter((f) => f in record);

  const fields = {};
  for (const k of bodyFields) fields[k] = toFirestoreValue(record[k]);

  let url = documentUrl(plan, record.duaId);
  if (!isCreate) {
    const mask = bodyFields
      .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
      .join("&");
    url = `${url}?${mask}`;
  }
  return { url, isCreate, maskFields: isCreate ? null : bodyFields, fields };
}

export async function writeRecords(records, plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  let created = 0;
  let updated = 0;
  let writes = 0;

  for (const record of records) {
    const existing = await readExisting(record.duaId, plan, deps);
    const req = buildWriteRequest(record, existing, plan);

    const res = await doFetch(req.url, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${plan.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: req.fields }),
    });
    writes += 1;

    if (!res.ok) {
      throw new Error(
        `write of ${record.duaId} failed: HTTP ${res.status}`,
      );
    }
    if (req.isCreate) {
      created += 1;
      console.log(`created ${record.duaId}`);
    } else {
      updated += 1;
      console.log(
        `updated ${record.duaId} (${req.maskFields.length} field(s); ` +
          `kept ${OPERATIONAL_FIELDS.join(", ")} and any admin fields)`,
      );
    }
  }
  return { created, updated, writes };
}

/** Fields whose value must match the payload exactly after a write. */
export const VERIFIED_AFTER_WRITE = Object.freeze([
  "duaId",
  "contentKind",
  "verificationStatus",
  "verifiedAt",
  "verifiedBy",
  "revokedAt",
]);

/**
 * Read one document back and prove it holds what was sent. Compares the
 * text by hash rather than by printing it, and never prints audioUrl or any
 * other value — a mismatch names the field, not its contents.
 */
export async function verifyWritten(record, plan, deps = {}) {
  const doc = await readExisting(record.duaId, plan, deps);
  if (doc === null) {
    throw new Error(`${record.duaId}: not found after write`);
  }
  for (const f of VERIFIED_AFTER_WRITE) {
    const want = record[f] ?? null;
    const got = doc[f] ?? null;
    if (want !== got) {
      throw new Error(
        `${record.duaId}: field "${f}" does not match what was sent`,
      );
    }
  }
  if (doc.verificationStatus !== "unverified") {
    throw new Error(
      `${record.duaId}: verificationStatus is "${doc.verificationStatus}", ` +
        `not "unverified"`,
    );
  }
  const wantHash = contentHashOf(record);
  const gotHash = contentHashOf(doc);
  if (wantHash !== gotHash) {
    throw new Error(
      `${record.duaId}: stored text hash ${gotHash.slice(0, 12)} does not ` +
        `match the payload hash ${wantHash.slice(0, 12)}`,
    );
  }
  return true;
}

// ── Reconciliation ──────────────────────────────────────────────────────
//
// The importer only ever writes. That leaves a hole nothing else covered: a
// hold stops the NEXT write, it does not retract the last one. A record that
// was imported and verified months ago, and has since been blocked or
// dropped from the pack, stays live in front of pilgrims — and no dry-run,
// log line or test said so, because every one of them reasons about the pack
// and the ledger while the live collection is never read.
//
// This mode reads. It never writes, deletes or revokes: there is no flag in
// this file that can make it do so. Retraction is a human decision, and this
// exists so that decision can be made on evidence.

export const RECONCILE_CASES = Object.freeze([
  "expected_and_present",
  "expected_missing",
  "present_but_excluded",
  "present_but_removed_from_pack",
  "text_changed",
]);

/** Cases that must never be seen in production. Both mean a live document
 *  contradicts the ledger, and no amount of writing fixes either. */
export const PRODUCTION_BLOCKING_CASES = Object.freeze([
  "present_but_excluded",
  "present_but_removed_from_pack",
]);

export async function listCollection(plan, deps = {}) {
  const doFetch = deps.fetch ?? globalThis.fetch;
  const base =
    `https://firestore.googleapis.com/v1/projects/${plan.projectId}` +
    `/databases/${plan.database}/documents/${plan.collection}`;
  const docs = [];
  let pageToken;
  do {
    const url = pageToken
      ? `${base}?pageSize=300&pageToken=${encodeURIComponent(pageToken)}`
      : `${base}?pageSize=300`;
    const res = await doFetch(url, {
      headers: { Authorization: `Bearer ${plan.token}` },
    });
    if (!res.ok) throw new Error(`list failed: HTTP ${res.status}`);
    const body = await res.json();
    for (const d of body.documents ?? []) {
      const fields = {};
      for (const [k, v] of Object.entries(d.fields ?? {})) {
        fields[k] = fromFirestoreValue(v);
      }
      docs.push({ documentId: (d.name ?? "").split("/").pop(), ...fields });
    }
    pageToken = body.nextPageToken;
  } while (pageToken);
  return docs;
}

/**
 * Compares the live collection against the pack and the ledger. Pure: it is
 * handed the live documents rather than fetching them, so the whole
 * classification is testable without a network.
 *
 * Reports `documentId` and a case. It deliberately prints no field VALUES —
 * not audioUrl (which can carry a download token), not text, not tokens.
 */
export function reconcile({ live, cleared, excluded, packIds }) {
  const clearedById = new Map(cleared.map((r) => [r.duaId, r]));
  const excludedById = new Map(excluded.map((e) => [e.duaId, e]));
  const liveById = new Map(live.map((d) => [d.documentId ?? d.duaId, d]));
  const findings = [];

  for (const [id, record] of clearedById) {
    const doc = liveById.get(id);
    if (!doc) {
      findings.push({ documentId: id, case: "expected_missing" });
      continue;
    }
    const changed = contentHashOf(record) !== contentHashOf(doc);
    findings.push({
      documentId: id,
      case: changed ? "text_changed" : "expected_and_present",
      verificationStatus: doc.verificationStatus ?? null,
    });
  }

  for (const [id, doc] of liveById) {
    if (clearedById.has(id)) continue;
    const held = excludedById.get(id);
    if (held) {
      findings.push({
        documentId: id,
        case: "present_but_excluded",
        verificationStatus: doc.verificationStatus ?? null,
        reason: held.reasons.join("; "),
      });
    } else if (!packIds.has(id)) {
      findings.push({
        documentId: id,
        case: "present_but_removed_from_pack",
        verificationStatus: doc.verificationStatus ?? null,
      });
    }
  }
  return findings;
}

export function printReconcile(findings, collection) {
  console.log(`\nReconciling ${collection} — READ ONLY, nothing is written.`);
  const byCase = {};
  for (const f of findings) (byCase[f.case] ??= []).push(f);
  for (const c of RECONCILE_CASES) {
    const rows = byCase[c] ?? [];
    console.log(`\n${c}: ${rows.length}`);
    if (c === "expected_and_present") continue;
    for (const r of rows) {
      const bits = [r.documentId];
      if (r.verificationStatus) bits.push(`verification=${r.verificationStatus}`);
      if (r.reason) bits.push(r.reason);
      console.log(`  - ${bits.join("  |  ")}`);
    }
  }
  console.log("\nNo document was written, deleted or revoked.");
}

/**
 * The production preflight. A live document that the ledger holds back, or
 * that the pack no longer contains, is not something a write can correct —
 * so the run stops and a human decides what to retract.
 */
export function assertReconciledForProduction(findings) {
  const blocking = findings.filter((f) =>
    PRODUCTION_BLOCKING_CASES.includes(f.case),
  );
  if (blocking.length) {
    throw new Error(
      "Refusing to write to production: the live collection holds " +
        `${blocking.length} document(s) the ledger does not clear:\n` +
        blocking.map((b) => `  - ${b.documentId}: ${b.case}`).join("\n") +
        "\nRetraction is a human decision; this importer will not make it.",
    );
  }
}

export function fromFirestoreValue(v) {
  if (v == null) return null;
  if ("nullValue" in v) return null;
  if ("booleanValue" in v) return v.booleanValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("stringValue" in v) return v.stringValue;
  if ("arrayValue" in v) {
    return (v.arrayValue.values ?? []).map(fromFirestoreValue);
  }
  if ("mapValue" in v) {
    const out = {};
    for (const [k, x] of Object.entries(v.mapValue.fields ?? {})) {
      out[k] = fromFirestoreValue(x);
    }
    return out;
  }
  return null;
}

function toFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === "boolean") return { booleanValue: value };
  if (typeof value === "number") {
    return Number.isInteger(value)
      ? { integerValue: String(value) }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(toFirestoreValue) } };
  }
  if (typeof value === "object") {
    const fields = {};
    for (const [k, v] of Object.entries(value)) fields[k] = toFirestoreValue(v);
    return { mapValue: { fields } };
  }
  return { stringValue: String(value) };
}

// ── Destinations ────────────────────────────────────────────────────────
//
// The collection is NEVER taken from user input. Two fixed destinations
// exist, each behind its own explicit flag, so a typo can never invent a
// collection and `--staging` can never silently become production.

// ── The review ledger, as an operational gate ───────────────────────────
//
// `review/human_review_ledger.json` records what a human checked against the
// printed page, and which records must NOT be shipped. Until now that was
// documentation only: nothing stopped this script from writing a record the
// ledger had rejected. A hold nobody enforces is a hold that expires the
// first time someone runs an import in a hurry.
//
// Three independent grounds for exclusion, kept separate because they mean
// different things:
//
//   reviewStatus: "blocked"   → something is wrong with the TEXT.
//   excludedFromImport: true  → the explicit instruction, whatever the cause.
//   deploymentBlocked: true   → the text is fine; the APP cannot yet present
//                               it correctly.
//
// Any one of them is disqualifying.

export const LEDGER_PATH = "review/human_review_ledger.json";

export function loadLedger(pathOrNull = LEDGER_PATH) {
  if (!existsSync(pathOrNull)) return null;
  return JSON.parse(readFileSync(pathOrNull, "utf8"));
}

/** sha256(ar + NUL + en) — the same construction the admin screen uses. */
export function contentHashOf(record) {
  const ar = record?.text?.ar ?? "";
  const en = record?.text?.en ?? "";
  return createHash("sha256").update(`${ar}\u0000${en}`, "utf8").digest("hex");
}

/**
 * Classifies every record for a PRODUCTION write. Fail-closed: a record is
 * included only if the ledger positively says a human passed its text and
 * nothing holds it back. Everything else lands in one of three excluded
 * buckets, each reported separately because they need different actions.
 *
 * Absence from the ledger is `unreviewed`, not `fine`. That is the whole
 * difference between this and the staging path: staging may write a record
 * nobody has read yet (that is what a trial is for), production may not.
 */
export function classifyForProduction(records, ledger) {
  const byId = new Map();
  for (const r of ledger?.reviews ?? []) byId.set(r.recordId, r);

  const reviewedIncluded = [];
  const unreviewedExcluded = [];
  const blockedExcluded = [];
  const deploymentHeld = [];

  for (const record of records) {
    const review = byId.get(record.duaId);
    if (!review) {
      unreviewedExcluded.push(record.duaId);
      continue;
    }
    if (review.reviewStatus === "blocked" || review.reviewStatus === "failed") {
      blockedExcluded.push(record.duaId);
      continue;
    }
    if (review.deploymentBlocked === true) {
      deploymentHeld.push(record.duaId);
      continue;
    }
    if (review.excludedFromImport === true) {
      // Excluded without either specific flag — treat as blocked rather than
      // guessing which bucket it belongs to.
      blockedExcluded.push(record.duaId);
      continue;
    }
    const passed =
      review.reviewStatus === "passed" || review.textReviewStatus === "passed";
    if (!passed) {
      unreviewedExcluded.push(record.duaId);
      continue;
    }
    reviewedIncluded.push(record);
  }

  return {
    reviewedIncluded,
    unreviewedExcluded,
    blockedExcluded,
    deploymentHeld,
  };
}

/**
 * Splits built records into what may be written and what may not.
 * Pure: takes the ledger as data so tests need no filesystem.
 */
export function applyLedger(records, ledger) {
  const byId = new Map();
  for (const r of ledger?.reviews ?? []) byId.set(r.recordId, r);

  const included = [];
  const excluded = [];
  for (const record of records) {
    const review = byId.get(record.duaId);
    const reasons = [];
    if (review) {
      if (review.reviewStatus === "blocked") {
        reasons.push(
          `review blocked (${review.blockReason || "no reason recorded"})`,
        );
      }
      if (review.deploymentBlocked === true) {
        reasons.push(
          `deployment blocked (${review.deploymentBlockReason || "no reason recorded"})`,
        );
      }
      if (review.excludedFromImport === true) {
        reasons.push("excludedFromImport");
      }
    }
    if (reasons.length) {
      excluded.push({ duaId: record.duaId, reasons });
    } else {
      included.push(record);
    }
  }
  return { included, excluded };
}

/**
 * Production refuses to guess. A missing ledger, an entry naming a record the
 * pack does not contain, or a recorded hash that no longer matches the text
 * all mean the reviews on file no longer describe what is about to be
 * written — and a review that does not describe the text is not a review.
 */
export function assertLedgerMatchesPack(ledger, records, { strict }) {
  if (!strict) return;
  if (!ledger) {
    throw new Error(
      `A production write requires ${LEDGER_PATH}, and it was not found. ` +
        "Writing records nobody has reviewed is exactly what the ledger exists to prevent.",
    );
  }
  const byId = new Map(records.map((r) => [r.duaId, r]));
  const problems = [];
  for (const review of ledger.reviews ?? []) {
    const record = byId.get(review.recordId);
    if (!record) {
      problems.push(`${review.recordId}: reviewed but absent from the pack`);
      continue;
    }
    const actual = contentHashOf(record);
    if (review.reviewedTextHash && review.reviewedTextHash !== actual) {
      problems.push(
        `${review.recordId}: text changed since review ` +
          `(reviewed ${review.reviewedTextHash.slice(0, 12)}…, ` +
          `pack now ${actual.slice(0, 12)}…)`,
      );
    }
    // Page provenance: a reviewer who read page 71 has not vouched for a
    // record that now cites page 94. The citation and the review must
    // describe the same page.
    const reviewedPages = review.reviewedPages ?? [review.reviewedPage];
    if (review.reviewedPage != null && record.printedPage != null) {
      if (reviewedPages[0] !== record.printedPage) {
        problems.push(
          `${review.recordId}: reviewed page ${reviewedPages[0]} but the ` +
            `record now cites page ${record.printedPage}`,
        );
      }
    }
  }
  if (problems.length) {
    throw new Error(
      "The review ledger no longer matches the pack:\n  " +
        problems.join("\n  "),
    );
  }
}

export const STAGING_COLLECTION = "supplications_staging";
export const PRODUCTION_COLLECTION = "supplications";

/**
 * Turns argv into a validated plan, or throws with the reason.
 *
 * The safety rules, in one place so they can be tested without touching a
 * network:
 *
 *   1. Dry-run is the DEFAULT. Without `--write` nothing is ever sent, and
 *      no credentials are even read. `--dry-run` is accepted as an explicit
 *      spelling of the default.
 *   2. `--write` demands exactly one destination: `--staging` or
 *      `--production`. "Write somewhere sensible by default" is how the
 *      wrong collection gets filled.
 *   3. `--limit` is a staging-only affordance for trying one record. It is
 *      REFUSED against production: a partial production import leaves a
 *      collection that is neither empty nor complete, which is the worst of
 *      both.
 *   4. A real write must restate what it is about to do:
 *      `--confirm-project` must equal FIREBASE_PROJECT_ID and
 *      `--confirm-count` must equal the number of records to be written.
 *      A confirmation the operator has to type from the printed plan is the
 *      point — it cannot be satisfied by muscle memory.
 */
export function resolvePlan(argv, env = {}) {
  const flags = argv.filter((a) => a.startsWith("--"));
  const positional = argv.filter((a) => !a.startsWith("--"));

  const known = new Set([
    "--dry-run", "--write", "--staging", "--production", "--limit",
    "--confirm-project", "--confirm-count", "--database", "--reconcile",
  ]);
  for (const f of flags) {
    const name = f.split("=")[0];
    if (!known.has(name)) throw new Error(`Unknown flag: ${name}`);
  }

  const has = (n) => flags.some((f) => f === n || f.startsWith(`${n}=`));
  const valueOf = (n) => {
    const hit = flags.find((f) => f.startsWith(`${n}=`));
    if (hit) return hit.slice(n.length + 1);
    const i = argv.indexOf(n);
    return i !== -1 ? argv[i + 1] : undefined;
  };

  const inputPath = positional.find((a) => a.endsWith(".json"));
  if (!inputPath) throw new Error("No source pack given.");

  const write = has("--write");
  const reconcile = has("--reconcile");
  const staging = has("--staging");
  const production = has("--production");

  if (reconcile && write) {
    throw new Error(
      "--reconcile is read-only and cannot be combined with --write.",
    );
  }

  if (staging && production) {
    throw new Error("--staging and --production are mutually exclusive.");
  }

  let limit;
  if (has("--limit")) {
    const raw = valueOf("--limit");
    limit = Number(raw);
    if (!Number.isInteger(limit) || limit < 1) {
      throw new Error(`--limit must be a positive integer, got "${raw}".`);
    }
    if (production) {
      throw new Error(
        "--limit cannot be used with --production. A partial production " +
          "import leaves the collection neither empty nor complete.",
      );
    }
    if (!staging) {
      throw new Error("--limit is only meaningful with --staging.");
    }
  }

  if (reconcile) {
    if (!staging && !production) {
      throw new Error(
        "--reconcile requires a destination to read: --staging or --production.",
      );
    }
    const projectId = (env.FIREBASE_PROJECT_ID || "").trim();
    const token = (env.FIREBASE_ADMIN_TOKEN || "").trim();
    if (!projectId || !token) {
      throw new Error(
        "--reconcile reads the live collection: set FIREBASE_PROJECT_ID and " +
          "FIREBASE_ADMIN_TOKEN. It still writes nothing.",
      );
    }
    const database = (valueOf("--database") || "(default)").trim();
    return {
      mode: "reconcile",
      inputPath,
      collection: production ? PRODUCTION_COLLECTION : STAGING_COLLECTION,
      projectId,
      token,
      database,
    };
  }

  if (!write) {
    // Dry run: destination is only informational, credentials are not read.
    return {
      mode: "dry-run",
      inputPath,
      limit,
      collection: production
        ? PRODUCTION_COLLECTION
        : staging
          ? STAGING_COLLECTION
          : null,
    };
  }

  if (!staging && !production) {
    throw new Error(
      "--write requires an explicit destination: --staging or --production.",
    );
  }

  const collection = production ? PRODUCTION_COLLECTION : STAGING_COLLECTION;
  const projectId = (env.FIREBASE_PROJECT_ID || "").trim();
  const token = (env.FIREBASE_ADMIN_TOKEN || "").trim();
  if (!projectId || !token) {
    throw new Error("Set FIREBASE_PROJECT_ID and FIREBASE_ADMIN_TOKEN.");
  }

  // Firestore database id. Defaults to the only database most projects
  // have. Constrained to Firestore's own id grammar so a stray value cannot
  // be spliced into the REST path.
  const database = (valueOf("--database") || "(default)").trim();
  if (database !== "(default)" && !/^[a-z][a-z0-9-]{2,62}$/.test(database)) {
    throw new Error(
      `--database "${database}" is not a valid Firestore database id.`,
    );
  }

  return {
    mode: "write",
    inputPath,
    limit,
    collection,
    projectId,
    token,
    database,
    confirmProject: valueOf("--confirm-project"),
    confirmCount: valueOf("--confirm-count"),
  };
}

/** Checks the operator's confirmations against the resolved plan. */
export function assertConfirmations(plan, recordCount) {
  if (plan.confirmProject !== plan.projectId) {
    throw new Error(
      `--confirm-project must equal FIREBASE_PROJECT_ID ("${plan.projectId}"), ` +
        `got "${plan.confirmProject ?? "nothing"}".`,
    );
  }
  if (String(plan.confirmCount) !== String(recordCount)) {
    throw new Error(
      `--confirm-count must equal the number of records to write ` +
        `(${recordCount}), got "${plan.confirmCount ?? "nothing"}".`,
    );
  }
}

function printProductionPlan(plan, c) {
  console.log(`Pack:       ${plan.inputPath}`);
  console.log(`Collection: ${plan.collection}`);
  console.log("");
  console.log(`reviewedIncluded:    ${c.reviewedIncluded.length}`);
  for (const r of c.reviewedIncluded) console.log(`  + ${r.duaId}`);
  console.log(`unreviewedExcluded:  ${c.unreviewedExcluded.length}`);
  for (const id of c.unreviewedExcluded) console.log(`  - ${id}`);
  console.log(`blockedExcluded:     ${c.blockedExcluded.length}`);
  for (const id of c.blockedExcluded) console.log(`  - ${id}`);
  console.log(`deploymentHeld:      ${c.deploymentHeld.length}`);
  for (const id of c.deploymentHeld) console.log(`  - ${id}`);
  console.log("");
  console.log("verificationStatus: unverified for every record written.");
  console.log("A reviewed record is imported unverified; an admin verifies it");
  console.log("afterwards in the app. Import never confers verification.");
}

/**
 * The last thing standing between a held-back record and production.
 *
 * Everything above is a filter, and a filter can be bypassed by a flag
 * nobody thought about. This is an assertion on the final set: if any id in
 * it is one the classifier excluded, the run dies rather than writes.
 */
export function assertProductionSetIsClean(records, classification) {
  const forbidden = new Set([
    ...classification.unreviewedExcluded,
    ...classification.blockedExcluded,
    ...classification.deploymentHeld,
  ]);
  const leaked = records.map((r) => r.duaId).filter((id) => forbidden.has(id));
  if (leaked.length) {
    throw new Error(
      "Refusing to write: records the ledger holds back reached the " +
        `production set: ${leaked.join(", ")}`,
    );
  }
}

function printPlan(plan, records, excluded = [], clearedCount = null) {
  console.log(`Pack:       ${plan.inputPath}`);
  // Both numbers, always. Printing only the post-limit count made the log of
  // a `--limit 1` run read "Included: 1", which is true of the write and
  // silent about the ledger: the reader could not tell whether 1 or 73
  // records had passed review. The limit is a slice taken AFTER the ledger,
  // and the log now says so.
  if (clearedCount !== null) {
    console.log(`Cleared by ledger (before --limit): ${clearedCount}`);
  }
  console.log(`Included:   ${records.length}  (zone-tied: ` +
    `${records.filter((r) => r.zoneKey).length})`);
  console.log(`Excluded:   ${excluded.length}  (held back by the review ledger)`);
  for (const e of excluded) {
    console.log(`  - ${e.duaId}: ${e.reasons.join("; ")}`);
  }
  console.log(`Project:    ${plan.projectId ?? "(not read in dry-run)"}`);
  console.log(`Database:   ${plan.database ?? "(not read in dry-run)"}`);
  console.log(`Collection: ${plan.collection ?? "(none — dry-run)"}`);
  if (plan.limit) {
    console.log(
      `Limit:      ${plan.limit}  ` +
        `(${clearedCount ?? "?"} cleared → ${records.length} to write)`,
    );
  }
  console.log("verificationStatus: unverified for every record.");
}

async function main() {
  let plan;
  try {
    plan = resolvePlan(process.argv.slice(2), process.env);
  } catch (err) {
    console.error(err.message);
    console.error(
      "\nUsage:\n" +
        "  node scripts/import_source_pack.mjs <pack.json>            # dry run (default)\n" +
        "  ... --staging --limit 1 --write --confirm-project=<id> --confirm-count=1\n" +
        "  ... --production --write --confirm-project=<id> --confirm-count=<n>",
    );
    process.exit(1);
  }

  const pack = JSON.parse(readFileSync(plan.inputPath, "utf8"));
  const all = buildRecords(pack);

  // The ledger is applied BEFORE --limit. Slicing first could hand the one
  // staging slot to a record the ledger holds back, which is precisely the
  // accident the hold exists to prevent.
  const ledger = loadLedger();
  try {
    assertLedgerMatchesPack(ledger, all, {
      strict: plan.collection === PRODUCTION_COLLECTION && plan.mode === "write",
    });
  } catch (err) {
    console.error(`\n${err.message}`);
    process.exit(1);
  }
  const isProduction = plan.collection === PRODUCTION_COLLECTION;

  // ── Reconcile: read the live collection, report, write nothing ────────
  if (plan.mode === "reconcile") {
    const r = applyLedger(all, ledger);
    let live;
    try {
      live = await listCollection(plan);
    } catch (err) {
      console.error(`\n${err.message}`);
      process.exit(1);
    }
    const findings = reconcile({
      live,
      cleared: r.included,
      excluded: r.excluded,
      packIds: new Set(all.map((x) => x.duaId)),
    });
    printReconcile(findings, plan.collection);
    const blocking = findings.filter((f) =>
      PRODUCTION_BLOCKING_CASES.includes(f.case),
    );
    if (isProduction && blocking.length) {
      console.error(
        `::error::production preflight FAILED: ${blocking.length} live ` +
          `document(s) the ledger does not clear.`,
      );
      process.exit(1);
    }
    return;
  }

  let records;
  let excluded;
  if (isProduction) {
    // Fail-closed. Anything the ledger does not positively clear stays out,
    // including every record nobody has read yet.
    const c = classifyForProduction(all, ledger);
    records = c.reviewedIncluded;
    excluded = [
      ...c.blockedExcluded.map((id) => ({ duaId: id, reasons: ["blocked"] })),
      ...c.deploymentHeld.map((id) => ({ duaId: id, reasons: ["deployment hold"] })),
      ...c.unreviewedExcluded.map((id) => ({ duaId: id, reasons: ["unreviewed"] })),
    ];
    printProductionPlan(plan, c);

    // Preflight: a live document the ledger holds back, or one the pack no
    // longer contains, cannot be corrected by writing. Stop and let a human
    // decide what to retract. Read-only — it lists, it never deletes.
    if (plan.mode === "write") {
      try {
        const live = await listCollection(plan);
        const findings = reconcile({
          live,
          cleared: c.reviewedIncluded,
          excluded: [
            ...c.blockedExcluded.map((id) => ({ duaId: id, reasons: ["blocked"] })),
            ...c.deploymentHeld.map((id) => ({ duaId: id, reasons: ["deployment hold"] })),
            ...c.unreviewedExcluded.map((id) => ({ duaId: id, reasons: ["unreviewed"] })),
          ],
          packIds: new Set(all.map((x) => x.duaId)),
        });
        printReconcile(findings, plan.collection);
        assertReconciledForProduction(findings);
      } catch (err) {
        console.error(`\n${err.message}`);
        process.exit(1);
      }
    }
    // Belt and braces: prove the set about to be written really is the
    // cleared set, whatever any flag above may have done to `records`.
    assertProductionSetIsClean(records, c);
  } else {
    const r = applyLedger(all, ledger);
    excluded = r.excluded;
    const cleared = r.included.length;
    records = plan.limit ? r.included.slice(0, plan.limit) : r.included;
    if (!ledger) {
      console.log(`(no ${LEDGER_PATH} found — nothing is held back)`);
    }
    printPlan(plan, records, excluded, cleared);
  }

  if (plan.mode === "dry-run") {
    console.log("\nDRY RUN — validated only. Nothing was sent anywhere.");
    return;
  }

  try {
    assertConfirmations(plan, records.length);
  } catch (err) {
    console.error(`\n${err.message}`);
    process.exit(1);
  }

  console.log(`\nWriting ${records.length} record(s) to ${plan.collection}...`);
  const summary = await writeRecords(records, plan);
  console.log(
    `\ncreated: ${summary.created}  updated: ${summary.updated}  ` +
      `writes: ${summary.writes}`,
  );
  if (summary.writes !== records.length) {
    console.error(
      `::error::expected exactly ${records.length} write(s), performed ` +
        `${summary.writes}.`,
    );
    process.exit(1);
  }

  // Post-write verification. A write that returns 200 proves the request was
  // accepted, not that the document holds what we meant. Read each one back
  // through the same credential and compare.
  console.log("\nVerifying what was written...");
  for (const record of records) {
    try {
      await verifyWritten(record, plan);
      console.log(`verified ${record.duaId}`);
    } catch (err) {
      console.error(`::error::${err.message}`);
      process.exit(1);
    }
  }
}

// Only run when invoked directly, so tests can import `buildRecords`.
if (process.argv[1] && process.argv[1].endsWith("import_source_pack.mjs")) {
  main().catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
