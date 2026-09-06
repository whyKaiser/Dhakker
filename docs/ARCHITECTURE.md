# Dhakker Assistant — Architecture & Implementation Status

This document describes the AI-assistant upgrade implemented on branch
`claude/dhakker-context-ai-upgrade-v0ilmk`, what was actually built and
verified, and what remains as documented future work. It follows the
project's priority order for the "context-aware, source-grounded AI
companion" upgrade.

## Scope of this change

This is a narrowed MVP deliverable (per an explicit scope-down from the
original 8-priority spec): a complete, working assistant backend + client
integration covering secure backend, structured request/response contract,
a trusted-RAG architecture with safe no-answer behavior, consent-gated
`PilgrimContext` wired to the app's real Tawaf/Sa'i counters, citation/
offline UI, and safety-critical tests. The deterministic proactive-guidance
engine, the admin aggregated-insights dashboard, and full 6-language UI
polish are explicitly out of scope for this deliverable and are documented
as future work below, not half-implemented.

## What was implemented (Priority 1 — Secure Worker + JSON contract)

`assistant-proxy/worker.js` was rewritten (not scaffolded from scratch —
the original Groq+Gemini fallback flow and endpoints are preserved) to add:

- **Structured response contract**, enforced server-side: every successful
  response is `{answer, language, grounded, confidence, citations[],
  recommendedAction, requiresHumanGuide, safetyNotice}`. The model is
  instructed to reply only in this JSON shape; the Worker additionally
  re-parses and re-validates the model's output itself
  (`parseModelJson`), stripping any citation missing required fields and
  falling back to a safe "cannot verify, consult a human guide" response
  (localized per-language) if the model output isn't valid JSON.
- **Firebase ID token verification without the Admin SDK**: RS256
  signature verification via Web Crypto (`crypto.subtle.verify`) against
  Google's public JWKS endpoint, plus `iss`/`aud`/`exp`/`iat` claim checks.
  Documented limitation: this does **not** call Firebase's revocation-check
  REST endpoint (that needs a service-account credential unsuitable for an
  edge Worker), so a token revoked in the last few minutes of its validity
  window could still pass. `REQUIRE_AUTH`/`ENVIRONMENT=production` controls
  fail-closed behavior — in production, a request with no/invalid token is
  rejected with `401 ERR_UNAUTHENTICATED`.
- **CORS**: `ALLOWED_ORIGINS` (comma-separated) env var replaces the
  previous `Access-Control-Allow-Origin: *`. In production, an
  unrecognized browser `Origin` is rejected (`403 ERR_FORBIDDEN_ORIGIN`);
  requests with no `Origin` header (native mobile app) are always allowed.
- **Request validation/limits**: body-size cap (32KB), message-count cap
  (20), per-message length cap (2000 chars), strict role/content schema
  checks, enum validation on every context field
  (`ritual`/`mobility`/`connectivity`/`crowdLevel`), a 40-char cap on the
  free-text `zone` field. Raw latitude/longitude are never accepted into
  context — only a named coarse zone.
- **Consent gate on context**: `validateContext` drops the entire context
  object unless `consent: true` is explicitly present in the request body.
- **Server-controlled model/provider/params**: `model`, `temperature`,
  `max_tokens` are hardcoded server-side constants; any client-supplied
  values are ignored. Provider order (Groq primary, Gemini fallback) is
  unchanged from the original design.
- **Best-effort rate limiting**: an in-memory per-isolate token bucket
  keyed by uid (or `CF-Connecting-IP` when unauthenticated in dev). This is
  explicitly documented as *not* a distributed/durable limiter — Cloudflare
  can run many isolates in parallel — and is called out as needing a
  Durable-Object- or KV-backed limiter for a hard production guarantee
  (that requires a paid plan feature and was left as documented future
  work rather than implemented against unavailable infrastructure).
- **Prompt-injection resistance**: the pilgrim-context block is rendered as
  a fixed-format `key=value` list, never concatenated as raw JSON, and the
  system prompt explicitly instructs the model to treat context/retrieved
  content as data, never as instructions, and to never reveal the system
  prompt.
- **Stable, localizable error codes**: `ERR_INVALID_JSON`,
  `ERR_INVALID_SCHEMA`, `ERR_REQUEST_TOO_LARGE`, `ERR_UNAUTHENTICATED`,
  `ERR_RATE_LIMITED`, `ERR_UPSTREAM_UNAVAILABLE`, `ERR_METHOD_NOT_ALLOWED`,
  `ERR_FORBIDDEN_ORIGIN`, `ERR_SERVER_MISCONFIGURED` — no raw provider
  errors/status/config text is ever returned to the client.
- **Fail-closed configuration**: whenever auth is required (production, or
  `REQUIRE_AUTH=true`), a non-empty `FIREBASE_PROJECT_ID` is mandatory; a
  missing/blank value returns `503 ERR_SERVER_MISCONFIGURED` before any
  request is processed. `aud`/`iss` are what bind a token to *our* Firebase
  project — a valid Google signature only proves Google minted the token,
  not that it was minted for us — so those checks are **never** skipped
  because the variable is absent. `exp`, `iat`, `auth_time` and `sub` are
  all validated, with a 60s symmetric clock-skew allowance.
- **Safe no-retrieval short-circuit**: when approved-source retrieval
  returns zero documents, the LLM is **not called at all** and a
  deterministic localized response is returned
  (`grounded=false`, `confidence=low`, `citations=[]`,
  `requiresHumanGuide=true`). Instructing a model to decline is not a
  safety control — it could still emit a confident fabricated ruling as the
  `answer` field. Not generating the text is the control.
- **Citation canonicalization**: the model may only *select* a retrieved
  `documentId`; every `title`/`authority`/`section`/`url` shown to the user
  is rebuilt server-side from the retrieved Firestore record. Any metadata
  the model supplies is discarded, so it cannot pair a real document id
  with an invented authority or an attacker-supplied URL. Unknown, empty,
  malformed and duplicate ids are dropped.
- **Bounded upstreams**: Groq, Gemini, Google JWKS, and Firestore retrieval
  all use explicit `AbortController` deadlines (`GROQ_TIMEOUT_MS`,
  `GEMINI_TIMEOUT_MS`, `JWKS_TIMEOUT_MS`, `FIRESTORE_TIMEOUT_MS`), so a
  hung dependency cannot pin a request open. A timed-out Groq falls back to
  Gemini; both failing yields a bounded `502`, never a fabricated answer.
- **Byte-accurate size limit**: the request cap is enforced in **UTF-8
  bytes**, not JS UTF-16 code units. A char-count check undercounts Arabic
  and Urdu text by ~2x (and emoji by 2x), which would have let a body
  several times the intended cap through — in exactly the languages this
  app serves.
- **Privacy-safe logging**: only `{uid-prefix, language, provider, status,
  ms}` is logged — never the question text, full token, or precise
  location.

### Worker tests

`assistant-proxy/worker.test.mjs` (Node's built-in test runner, no external
dependency — run with `node --test assistant-proxy/worker.test.mjs` or
`npm test` inside `assistant-proxy/`): **86 tests, all passing**, covering
schema validation (missing/oversized/malformed messages, ignored
client-supplied model/temperature), consent-gated context validation
(dropped without consent, enum-only fields survive, raw lat/lng never
kept), the response-contract parser (valid grounded response, non-JSON
fallback, citations with missing fields stripped, code-fence unwrapping,
forced reply language, **grounded:true forced to false/low/
requiresHumanGuide:true whenever the validated citations list is empty —
whether because the model sent none or because its citations failed
schema validation**), CORS allow-list behavior, rate-limit triggering,
control-character sanitization, and end-to-end `fetch()` behavior (405 on
non-POST, 401 unauthenticated-in-production, 400 invalid JSON/schema, 413
oversized body, 502 safe fallback with no provider keys configured, 403 on
disallowed browser origin).

The security-review round added coverage for each fixed defect:

- **Safe no-retrieval**: that an empty retrieval returns the deterministic
  payload, and — with a stubbed provider that would return a fabricated
  ruling and a fabricated citation — that the provider is **never invoked**
  (`providerCalls === 0`) and none of that text reaches the response.
- **Fail-closed config**: 503 in production with `FIREBASE_PROJECT_ID`
  missing or blank/whitespace, the same under `REQUIRE_AUTH=true` outside
  production, and that the error body leaks no env-var name, secret, or
  stack trace.
- **Token claims**: tokens minted for *another* Firebase project (bad
  `aud`), a forged `aud` with a mismatched `iss`, expired, future-`iat`,
  missing/future `auth_time`, missing/non-string `sub`, `alg=none`
  downgrade, malformed tokens, and refusal to skip `aud`/`iss` when no
  project id is configured.
- **Citation canonicalization**: a model supplying a **valid** documentId
  alongside a fabricated title/authority/section/url has every field
  rebuilt from the retrieved record (asserted both at unit level and
  end-to-end through `fetch()`), plus rejection of unknown/empty/
  malformed/duplicate ids.
- **Timeouts & fallback**: all four budgets are finite and ≤30s; a hanging
  Groq is aborted and falls back to Gemini (with the citation still
  canonicalized); both providers failing yields a bounded 502 with no
  `answer` field.
- **UTF-8 size limit**: `utf8ByteLength` counts bytes not code units, and a
  ~24k-Arabic-character body (under the char cap, over the byte cap) is
  rejected with 413.

```
$ node --test assistant-proxy/worker.test.mjs
# tests 86
# pass 86
# fail 0
```

This count was re-verified after every Worker change in this round.

## Client-side changes

`lib/services/assistant_service.dart` was updated to speak the new
contract rather than raw Groq chat-completions JSON when a proxy URL is
configured:

- `AssistantResponse` / `AssistantCitation` model classes mirror the
  server contract and defensively re-validate every field (never trust the
  network response blindly — a missing/invalid citation field is dropped,
  an empty `answer` becomes a "cannot verify" fallback).
- `PilgrimContext` is a small opt-in value object
  (`ritual`, lap counts, `mobility`, `connectivity`, `zone`, `crowdLevel`)
  whose `toJson()` returns `null` — sending nothing — unless
  `consent == true`. This is the client half of the consent gate; the
  Worker independently re-enforces it server-side.
- An `idTokenProvider` hook is wired in `assistant_screen.dart`'s
  `initState()` to `FirebaseAuth.instance.currentUser?.getIdToken(true)` —
  force-refresh, fetched fresh on every request rather than cached, so a
  long-lived chat session cannot send a stale/expired token. If there is no
  authenticated user (or the provider returns null/empty), or the server
  rejects the token with `401`, `AssistantService.ask()` returns a distinct
  `AssistantResponse.signInRequired` state — rendered as its own "Sign-in
  required" chip in `AssistantResponseMeta`, never as a generic error.
- A direct-to-Groq dev-mode path (no `ASSISTANT_PROXY_URL` configured) is
  preserved for local development, clearly separated from the
  proxy/structured path, and is **hard-disabled in release builds** via the
  compile-time `bool.fromEnvironment('dart.vm.product')` flag — a build
  cannot silently ship it just because a `GROQ_API_KEY` define was left in.
- `lib/Screens/Assistant/assistant_screen.dart`: each `_Lang` now carries
  the ISO language code sent to the assistant (`ar`/`en`/`ur`/`tr`/`id`/
  `fr`) so the *selected* language is authoritative, not auto-detected.
  Replies now render grounding/offline/"consult a human guide" badges and
  any citations (title + authority) under the assistant's bubble. A new
  header toggle implements the required explicit consent flow for context
  sharing — off by default, with a dialog explaining exactly what would be
  shared before it's turned on, and always revocable.

## Trusted RAG (implemented, MVP scope)

`retrieveKnowledge()` in `assistant-proxy/worker.js` implements keyword
retrieval against Firestore's `knowledge_chunks` collection (via Firestore
REST `runQuery`, `ARRAY_CONTAINS_ANY` on `keywords` + `language` equality),
authenticated using the SAME Firebase ID token already verified for the
caller — no separate service-account credential is held by the Worker.
`FIRESTORE_PROJECT_ID` unset, no caller token, or any Firestore error all
degrade to an **empty** retrieval result — never a fabricated answer.

**No approved religious source text ships in this repo** (it lives in the
live `supplications` collection instead — see "Approved source registry").
In non-production environments only, `DEV_FIXTURE_DOCS` (two small,
explicitly `[DEV FIXTURE — NOT RELIGIOUS CONTENT]`-labeled, non-religious
entries — visitor-center hours and lost-and-found) are used so the
retrieval → citation → grounded-answer pipeline is exercisable and tested
without any real or invented religious content.

The Worker enforces the "never fabricate citations" rule server-side, not
just via prompt instruction: if retrieval returns zero documents, the
response is force-overridden to `grounded:false`, `citations:[]`,
`requiresHumanGuide:true` regardless of what the model produced; if
retrieval returns documents, any citation the model returns that doesn't
match a retrieved `documentId` is filtered out before the response leaves
the Worker.

## Response validation invariant (grounded ⇒ non-empty citations)

Enforced independently in **three** places, each a full defense-in-depth
layer that does not rely on the others:

1. `parseModelJson()` in `worker.js` — if the model claims `grounded:true`
   but its citations list is empty (either because it sent none, or
   because every citation it sent failed the required-field check), the
   parsed result is forced to `grounded:false`, `confidence:"low"`,
   `requiresHumanGuide:true` before anything else touches it.
2. The `fetch()` handler in `worker.js` — after retrieval-based citation
   filtering (dropping any citation whose `documentId` wasn't actually
   retrieved), a final unconditional check re-applies the same invariant in
   case the filtering step alone emptied the list.
3. `AssistantResponse.fromJson()` in `lib/services/assistant_service.dart`
   — the Flutter client re-derives `grounded` from `claimedGrounded &&
   citations.isNotEmpty` itself, rather than trusting the server's
   `grounded` field directly. This is defense in depth against a
   compromised/misbehaving proxy, not just belt-and-suspenders against the
   same Worker bug.

All three are covered by explicit tests: `worker.test.mjs` ("grounded:true
claim with an empty citations list…" / "…whose only citations fail
validation…") and `test/assistant_service_test.dart` (mirroring both
cases), plus a widget-level assertion in
`test/assistant_response_widget_test.dart` that the "Grounded" chip never
renders for such a response.

## Offline knowledge (contains no religious content)

`lib/data/offline_knowledge_repository.dart` holds the deterministic,
non-generative offline text. It contains **no religious or ritual guidance
of any kind**, and `approvedOfflineGuidance` is intentionally **empty**.

An earlier revision of this file shipped statements about Tawaf, Sa'i,
Ihram, Jamarat and Arafat — including a hadith quotation — with no
approved-source citation metadata, while the surrounding code described
them as "reviewed". A security/religious-safety review flagged this as
merge-blocking and the claims were **removed**. Presenting unverifiable
religious assertions to pilgrims under an implied stamp of review is
exactly the failure this project's religious-safety rule exists to
prevent.

Current behavior, offline:

- A **ritual/ruling question** (detected by `isRitualQuestion`, which
  matches Arabic and Latin/transliterated keywords) returns a referral:
  the app states it cannot answer ritual questions on its own offline and
  directs the pilgrim to approved guidance they have saved, or to an
  authorized guide/qualified scholar. It asserts no ritual fact.
- **Anything else** returns an operational connectivity notice (counters,
  saved maps, and emergency contacts still work offline).

Both messages are ordinary UI strings — connectivity notices and a human
referral — so they are translated for **all six** supported languages
(ar/en/ur/tr/id/fr) without fabricating any religious content. An
unsupported language code falls back to English.

`OfflineContentStatus` distinguishes `operationalNotice`,
`noApprovedSourceOffline`, and `approvedGuidance`, and this is carried
through `AssistantResponse.offlineStatus` into the UI so the three render
differently. Only `approvedGuidance` — which requires real
`OfflineCitationMetadata` (documentId/authority/URL/version) and can only
be produced from the approved-source registry, never hardcoded — may be
labelled verified. Since no approved content has been ingested,
`hasApprovedOfflineGuidance` is currently `false` and the "Approved offline
guidance" badge is unreachable in practice.

Enforced by `test/offline_knowledge_repository_test.dart`, which asserts
across all six languages that no entry is ever marked approved, that no
entry carries citation metadata, and that specific removed claims (lap
counts, "seven pebbles", "Black Stone", "Hajj is Arafah", and their Arabic
equivalents) cannot reappear in any offline text.

## PilgrimContext wiring (implemented)

`lib/services/pilgrim_context_builder.dart` builds a `PilgrimContext`
snapshot from the app's **existing** sources of truth only — no new
counter or location stream is created:

- **Zone**: `HomeDuaController.lastKnownZone` — a static, in-memory mirror
  of the same `currentZone` value `HomeDuaController` already computes from
  its own zone-detection stream (updated at the same two call sites where
  `currentZone` itself is assigned/cleared). This is a read-only snapshot of
  an existing value, not a second GPS/zone stream. Only the coarse
  `zoneId` (e.g. `"Al-Haram"`) is read — raw coordinates never enter
  `PilgrimContext` at any point.
- **Active ritual**: `AppCubit.isTawafActive` / `AppCubit.isSaiActive` — new
  real-time getters derived from the position-stream proximity signal the
  cubit already computes every location update (`_nearTawaf`/`_nearSai`,
  the same signal that drives its own high-accuracy-mode switching),
  combined with "lap count not yet at 7". This deliberately does **not**
  infer "ritual = tawaf/sai" merely from `roundCount`/`saiCount` being
  non-zero, since those counters stay non-zero for hours after the ritual
  actually finished and would mislabel a stale session as in-progress. If
  neither proximity signal is currently true, the reported ritual is
  `'none'` rather than a guess.

`PilgrimContextBuilder.build()` is called from `assistant_screen.dart` only
when the explicit consent toggle is on; the toggle defaults to off and
shows a dialog explaining exactly what would be shared (ritual, lap count,
a coarse named zone — never precise coordinates) before it can be turned
on.

## Known gaps / explicitly out of scope for this deliverable

1. **Proactive deterministic guidance engine** — not implemented (out of
   scope per the narrowed MVP deliverable).
2. **Admin aggregated/anonymized insights dashboard** — not implemented
   (out of scope per the narrowed MVP deliverable).
3. **Full 6-language UI polish** — the assistant already sends/receives
   all 6 languages (ar/en/ur/tr/id/fr) through the structured contract, but
   deeper UI polish beyond what already existed was left out of scope.
4. **Live retrieval against real approved content** — the Firestore
   REST retrieval path is implemented and unit-testable in isolation
   (`retrieveKnowledge`), but was not exercised against a live Firestore
   project in this session (no project credentials available in this
   sandbox), and no officially-approved religious source content exists to
   ingest yet — see "What needs external credentials" below.
5. **Firestore rules tests** — `firestore.rules` was updated (new
   `knowledge_documents`, `knowledge_chunks`, `assistant_feedback` rules)
   but not run against the Firebase emulator in this session (no `firebase`
   CLI / emulator tooling was available in the sandbox — checked again in
   this round, still not present); the rule logic mirrors the existing
   admin-write-only pattern used for `zones`/`supplications` and was
   reviewed by inspection only. This remains unverified against a live
   emulator.
6. **Real-content ingestion tooling for `knowledge_documents`/
   `knowledge_chunks`** — `scripts/ingest_knowledge.mjs` was added: a
   documented, idempotent admin-only import command
   (`node scripts/ingest_knowledge.mjs path/to/approved-chunks.json`,
   with `FIREBASE_PROJECT_ID`/`FIREBASE_ADMIN_TOKEN` env vars) that upserts
   a JSON array of approved chunks into both collections via the Firestore
   REST API. It was reviewed by inspection only — not run against a live
   project in this session (no credentials available in the sandbox), and
   this repo still intentionally ships no religious content to feed it.
7. **`pilgrim_context_builder.dart` has no dedicated unit test** —
   `AppCubit`'s constructor touches app-local cache/notification services
   that are awkward to construct in a plain unit test without further
   test-harness work; the ritual/zone logic was verified by code review
   only, not by an automated test in this round.

## Source registry (where content lives, and what "verified" means)

**No religious source text is stored in this repository, by design.** Content
lives only in the project's live Firestore database and is curated through the
in-app admin console. Nothing below exposes credentials or copies source text
into Git.

### Important: existing records are NOT approved sources

The `supplications` collection holds **existing content records**. Their
presence in the collection implies **nothing** about whether any authority
reviewed or approved them — the collection predates this feature and carries
no provenance metadata at all. They must not be described as "approved
sources", and none of them may be marked verified in bulk.

A record becomes citable by the assistant only after a human has matched it
against an official published source and recorded that fact. Until then it is
unverified, uncitable, and still perfectly usable as a location dua.

### Where content is stored

The live collection is **`supplications`**. It is:

- written by the admin console (`lib/Screens/Admin/Manage Supplications/`),
- read by the Flutter home screen for location-aware duas,
- and, as of this change, read by the Worker retrieval path.

`firestore.rules` grants signed-in read, admin-only create/delete, and update
restricted to admins except that a pilgrim may increment `usage_count` only —
and may never touch any verification field.

`knowledge_documents` / `knowledge_chunks` is a purpose-built RAG schema added
by this feature. **It is empty**; no Flutter code path reads or writes it. It
is selectable via `KNOWLEDGE_COLLECTION` for a future migration.

### Schema

Content fields (pre-existing):

| Field | Type | Purpose |
|---|---|---|
| `duaId` | string | Stable id → retrieval `documentId` |
| `zoneId` | string | Zone → `section` fallback |
| `title` | map `{ar,en}` | Localized title → citation `title` |
| `text` | map `{ar,en}` | Localized body → retrieval `content` |
| `tagsAr` / `tagsEn` | string[] | Search keywords |
| `languageCodes` | string[] | Languages this record covers |
| `isActive` | bool | Must be true to be retrieved |

Provenance + lifecycle fields (added by this change):

| Field | Type | Purpose |
|---|---|---|
| `verificationStatus` | string | Must be exactly `"verified"` |
| `authority` | string | Body that published the edition actually checked |
| `sourceUrl` | string | **HTTPS** link to that published edition |
| `sourceVersion` | string | Which edition/date was checked |
| `sourceLanguage` | string | Language of the source consulted |
| `sourceSection` | string | Page/section reference within the source |
| `verifiedAt` | timestamp | When verification was recorded |
| `verifiedBy` | string | UID of the admin who verified |
| `contentHash` | string | sha256 of the reviewed text — detects later edits |
| `revokedAt` | timestamp | Set to withdraw a source; excludes it immediately |
| `reviewNotes` | string | How the match was performed |

### The gate — fail closed, enforced in three places

A record is retrievable **only** when ALL hold:

- `verificationStatus == "verified"`
- `isActive == true`
- `authority` non-empty
- `sourceUrl` a valid `https://` URL
- `sourceVersion` non-empty
- not revoked (`revokedAt` unset)

Each condition exists because a citation asserts to a pilgrim who stands
behind the text. No authority → we cannot name the approver. No valid HTTPS
`sourceUrl` → the pilgrim cannot independently check it. No `sourceVersion` →
we cannot say which edition was reviewed. Any gap turns a citation into an
unfalsifiable claim of endorsement.

Enforced independently by:

1. **`assistant-proxy/worker.js`** — `mapSupplicationRows` gate, plus a
   server-side `verificationStatus` equality filter in the query itself.
2. **`firestore.rules`** — `hasCompleteProvenance()`; not even an admin may
   write `verificationStatus: "verified"` without every required field, and
   ordinary users cannot write any verification field at all.
3. **Admin UI** — `_provenanceGapMessage()` blocks the save with a specific
   list of what is missing. This is the friendliest layer, never the
   authority.

### Verification procedure (admin)

1. Obtain the **official published source** — the actual publication, not a
   summary or a third-party site.
2. Open the admin console → Manage Supplications → add/edit.
3. Match the record's text against the source, word for word.
4. Fill **Issuing authority**, **Source URL** (https), **Version**,
   **Section/page**, **Source language**, and **Review notes**.
5. Turn on **"مصدر معتمد وموثّق"**. The console stamps `verifiedAt`,
   `verifiedBy`, and a `contentHash` of the reviewed text.
6. If the text is later edited, the stored `contentHash` no longer matches —
   treat that as requiring re-verification.
7. To withdraw a source, set `revokedAt`; retrieval excludes it immediately.

`scripts/source_import_template.json` is a metadata-only template for bulk
preparation. It contains placeholders, never religious text, and its filled
form must not be committed.

### Migration status

Every existing record is currently unverified, so the grounded path is closed
and every ritual question takes the safe no-answer route. Opening it is a
per-record human review task, deliberately with no bulk shortcut.

## Verification status

Both sides are now actually executed and verified.

**Flutter** — a Flutter 3.24.2 SDK (matching `flutter-ci.yml`) was
installed into the working environment and the real commands were run,
with exit codes checked explicitly:

```
dart format --output=none --set-exit-if-changed .                  # exit 0
flutter pub get                                                    # exit 0
flutter analyze                                                    # exit 0, "No issues found!"
flutter test                                                       # exit 0, 44/44 passing
```

Note that `flutter analyze` exits non-zero on **info**-level lints too,
not only errors — reading its output without checking the exit code is
not sufficient verification.

**Worker** — `node --test assistant-proxy/worker.test.mjs`: 86/86 passing.

**Firestore rules** — 21/21 passing against the real Firebase emulator:

```
npm --prefix test_firestore_rules ci
npm --prefix test_firestore_rules test
```

`firebase emulators:exec` boots the emulator, runs the suite, and tears it
down; no real project is touched. This also runs as its own CI job, which
installs with `npm ci` from the committed `package-lock.json`.

Dependency versions are **pinned exactly and must stay mutually compatible**:
`@firebase/rules-unit-testing@5.0.1` declares a peer of `firebase@^12.0.0`.
An incompatible pair (e.g. rules-unit-testing 3.0.4, whose peer is
`firebase@^10`, alongside firebase 11) fails `npm ci` with `ERESOLVE`. Fix
that by choosing a compatible pair — 4.0.1 pairs with firebase 11.x, 3.0.4
with 10.x — never with `--force` or `--legacy-peer-deps`, which would install
a combination the packages do not claim to support. The suite
covers authenticated-vs-anonymous reads, admin-only create/delete, the
usage_count-only pilgrim update path, every individual verification field
being unwritable by ordinary users, and the rule that not even an admin may
mark a record verified without complete provenance (missing field, empty
field, and non-HTTPS `sourceUrl` all rejected).

Note: the emulator logs `evaluation error` lines for the pre-existing
`isAdmin()` helper's `get()` on the users document. Verified by probe against
`origin/main` that this predates these changes; access is still correctly
denied, it is simply not a clean `false`.

**CI** — `.github/workflows/flutter-ci.yml` runs both suites on every push
to this branch and on PRs targeting `main`, and can be triggered manually
via `workflow_dispatch`. Its formatting step checks the whole tree.
It once checked only a hand-maintained list of "feature-owned" files,
because ~54 pre-existing files had never been run through `dart format`;
that debt has since been paid in a formatting-only change, so the list and
the exception it encoded are both gone.

### Still not verified here

- **Live retrieval** has never run against a real Firestore project (no
  credentials available), so the retrieval adapters are exercised only
  through unit tests and metadata-only fixtures.
- **The composite indexes in `firestore.indexes.json` have not been
  deployed or verified against a live project.** Without them the retrieval
  query fails — which degrades safely to "no approved source", so the
  symptom is silence rather than an error. Deploy with
  `firebase deploy --only firestore:indexes`.
- **No approved religious source text is committed to this repository** —
  deliberately. The real approved content lives in the live Firestore
  `supplications` collection (see "Approved source registry" above), which
  is curated through the admin console and has been exercised in the field.
  Only non-religious dev fixtures are bundled in Git, and they are disabled
  outside non-production environments.
- **The provenance backfill has not been done.** The Worker now reads the
  live `supplications` registry, but only cites records carrying
  `authority` + `verificationStatus == "verified"` — fields this change
  introduces. Existing records predate them, so until an admin backfills
  them the grounded path stays closed and every ritual question takes the
  safe no-answer route. Verified here only against metadata fixtures, not
  against the live collection (no credentials in this environment).

## What needs external credentials / approved content / paid infra

- `FIREBASE_PROJECT_ID`, `GROQ_API_KEY`, `GEMINI_API_KEY`,
  `ALLOWED_ORIGINS`, `ENVIRONMENT=production` must be set as Worker
  secrets/vars before deploying — none are committed to the repo.
- No officially-approved religious source documents (fatwas, hadith
  collections, official Hajj-guide text) were available to ingest for
  Priority 2 — building that requires the project owner to supply
  approved, licensed source material; only clearly-labeled non-religious
  dev fixtures should ever be used for testing that pipeline.
- A hard production-grade global rate limiter needs Cloudflare Durable
  Objects or a KV namespace (paid-tier-adjacent feature) — the current
  limiter is an honest best-effort, documented as such.
