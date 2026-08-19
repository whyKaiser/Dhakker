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
`npm test` inside `assistant-proxy/`): **29 tests, all passing**, covering
schema validation (missing/oversized/malformed messages, ignored
client-supplied model/temperature), consent-gated context validation
(dropped without consent, enum-only fields survive, raw lat/lng never
kept), the response-contract parser (valid grounded response, non-JSON
fallback, citations with missing fields stripped, code-fence unwrapping,
forced reply language), CORS allow-list behavior, rate-limit triggering,
control-character sanitization, and end-to-end `fetch()` behavior (405 on
non-POST, 401 unauthenticated-in-production, 400 invalid JSON/schema, 413
oversized body, 502 safe fallback with no provider keys configured, 403 on
disallowed browser origin).

```
$ node --test assistant-proxy/worker.test.mjs
# tests 29
# pass 29
# fail 0
```

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
- An `idTokenProvider` hook lets app startup wire in the signed-in user's
  Firebase ID token once available (not wired to a live Firebase Auth call
  in this change — see Known Gaps).
- A direct-to-Groq dev-mode path (no `ASSISTANT_PROXY_URL` configured) is
  preserved for local development, clearly separated from the
  proxy/structured path.
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

## PilgrimContext wiring (implemented, MVP scope)

`lib/services/pilgrim_context_builder.dart` builds a `PilgrimContext`
snapshot by reading the app's **existing** sources of truth —
`AppCubit.roundCount` (Tawaf laps) and `AppCubit.saiCount` (Sa'i laps) —
with no new counter or stream created. It is called from
`assistant_screen.dart` only when the explicit consent toggle is on; the
toggle defaults to off and shows a dialog explaining exactly what would be
shared (ritual, lap count, a coarse named zone — never precise
coordinates) before it can be turned on. `zone` wiring to
`HomeDuaController.currentZone` (the Home screen's live zone detector) was
deliberately left unconnected in this pass to avoid creating a second
zone-detection consumer outside the Home screen's own controller; `ritual`
is currently inferred from lap-counter activity rather than the Home
screen's zone type for the same reason. This is a documented simplification,
not a duplicate-state violation.

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
   but not run against the Firebase emulator in this session (no emulator
   available); the rule logic mirrors the existing admin-write-only pattern
   used for `zones`/`supplications` and was reviewed by inspection only.

## Could not run in this environment

The sandbox this change was made in has **no Flutter/Dart SDK installed**
(`flutter`/`dart` are not on `PATH`, and no Flutter SDK directory exists
outside the platform embedding folders that ship with the repo). As a
result `dart format .`, `flutter pub get`, `flutter analyze`, and
`flutter test` could **not** be run or verified in this session. The
changed Dart files were manually reviewed and brace/paren-balance checked,
and the existing `AssistantService` public API surface used by
`assistant_screen.dart` was kept consistent, but **Flutter-side
compilation was not actually verified by a compiler in this session** —
this must be run before merging:

```
dart format .
flutter pub get
flutter analyze
flutter test
```

The Worker side, by contrast, *was* fully executed and verified with
Node's built-in test runner (`node --test`), since Cloudflare Workers code
is plain JavaScript/Web-standard APIs.

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
