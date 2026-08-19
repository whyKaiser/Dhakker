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
  `ERR_FORBIDDEN_ORIGIN` — no raw provider errors/status/config text is
  ever returned to the client.
- **Privacy-safe logging**: only `{uid-prefix, language, provider, status,
  ms}` is logged — never the question text, full token, or precise
  location.

### Worker tests

`assistant-proxy/worker.test.mjs` (Node's built-in test runner, no external
dependency — run with `node --test assistant-proxy/worker.test.mjs` or
`npm test` inside `assistant-proxy/`): **41 tests, all passing**, covering
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

```
$ node --test assistant-proxy/worker.test.mjs
# tests 41
# pass 41
# fail 0
```

This count was re-verified after every Worker change in this round — see
the "Response validation" section below for the specific grounded/citations
invariant fix that added the two new `parseModelJson` tests.

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

**No officially-approved religious source content ships with this repo.**
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

## Offline knowledge (restructured)

`lib/data/offline_knowledge_repository.dart` now holds the deterministic,
non-generative offline fallback facts previously inlined in
`AssistantService._offlineReply`. It is versioned (`version` constant),
keyed by topic + language, and every entry is explicitly labeled via
`OfflineKnowledgeEntry.sourceLabel`/`isVerified` as **unverified general
knowledge, not a citation-backed ruling** — none of it is tied to a real
`knowledge_documents` source record, so none of it is marked verified.
Reviewed translations exist today for English and Arabic; a topic with no
reviewed translation in the requested language honestly falls back to the
reviewed English text (`isFallbackTranslation: true`) rather than
fabricating an unreviewed translation for Urdu/Turkish/Indonesian/French.

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

## Could not run in this environment

The sandbox this change was made in has **no Flutter/Dart SDK installed**
(`flutter`/`dart` are not on `PATH`, and no Flutter SDK directory exists
outside the platform embedding folders that ship with the repo — checked
again in this round with the same result). As a result `dart format .`,
`flutter pub get`, `flutter analyze`, and `flutter test` could **not** be
run or verified in this session, in this round either. The changed Dart
files were manually reviewed and brace/paren-balance checked, and the
existing `AssistantService`/`AssistantScreen` public API surface was kept
consistent, but **Flutter-side compilation was not actually verified by a
compiler in this session**.

To close this gap without a local SDK, `.github/workflows/flutter-ci.yml`
was added, running on every push/PR to this branch:

```
dart format --output=none --set-exit-if-changed .
flutter pub get
flutter analyze
flutter test
```

plus a second job running `node --test assistant-proxy/worker.test.mjs`.
This session has no way to observe the resulting GitHub Actions run from
the sandbox — its pass/fail result must be checked externally (in the
GitHub Actions tab for this branch) before treating the branch as
merge-ready. **Do not treat a Flutter change on this branch as verified
until that CI run (or a local `flutter test` run) is actually green.**

The Worker side, by contrast, *was* fully executed and verified with
Node's built-in test runner (`node --test`) in this session, since
Cloudflare Workers code is plain JavaScript/Web-standard APIs — see the
Worker tests section above for the current, actually-run count.

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
