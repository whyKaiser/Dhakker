# Web build and boot resilience

## The problem this addresses

The released web build fetched two things from `www.gstatic.com` at runtime:

1. **CanvasKit** — the rendering engine.
2. **The Firebase JS SDK** — `firebase-app`, `firebase-auth`, `firebase-firestore`, `firebase-storage`, loaded by the `firebase_core` web plugin.

If either was unreachable, the page stayed **permanently blank with no message**. The app's own Dart error handling never ran, because the failure happened in the JS layer before `main()` was reached — so the `try/catch` around `Firebase.initializeApp` in `lib/main.dart` could not help.

That matters here more than in most apps. `main.dart` enables Firestore
persistence specifically "لأن شبكة مكة تتعطّل أيام الذروة" — the app is
designed for a congested network, but its own boot could not survive one.

## What changed

### 1. CanvasKit is served from our own origin

Build with:

```bash
flutter build web --release --no-web-resources-cdn \
  --dart-define=ASSISTANT_PROXY_URL=<proxy url>
```

`--no-web-resources-cdn` is the supported flag on this project's Flutter
(3.24.2) — confirmed from `flutter build web --help`, not assumed. It makes
the build emit CanvasKit into `build/web/canvaskit/` and reference it
relatively, so no request goes to `gstatic.com` for the renderer.

**Use this flag for every release build.** Without it, the resulting bundle
reintroduces the CDN dependency.

### 2. A boot watchdog in `web/index.html`

`web/index.html` now paints a loading state before any script runs, and
replaces it with a readable bilingual failure screen — with a retry button —
if the app never comes up. It settles on:

- **The app's own first-frame signal** → success, the boot screen is removed.
- A failed resource load, or an unhandled rejection matching an import/fetch/network failure → failure screen.
- A 30-second ceiling → failure screen. Generous on purpose: it ends an indefinite wait, it does not police latency.

### Why success is signalled by the app, not inferred from the DOM

The obvious check — wait for `flt-glass-pane` to appear — **does not work**,
and this was caught by looking at an actual screenshot rather than at the
check's own verdict.

The engine inserts its host element *before any widget paints*. So the
element appears both when the app is up and when the engine starts and the
app then fails to render. The first version of this watchdog treated that
element as success, removed the loading screen, and left the viewer looking
at a flat empty rectangle — dark instead of white, and no better. The smoke
check passed against it.

The only party that can tell the two apart is the app. So
`lib/main.dart` calls `signalAppReady()` in a post-frame callback, which on
web invokes the `window.dhakkerAppReady` hook this page installs
(`lib/boot_signal.dart`, with a no-op stub on every other platform). The
watchdog waits for that and nothing else.

The failure screen is **deliberately generic**. The underlying error can name
internal endpoints and Firebase configuration; that is logged to the console
for a developer and never rendered. The smoke check asserts the screen
contains no `firebase`, `gstatic`, `apiKey`, URL or raw `Error:` text.

## What is fixed, and what is not

| | status |
|---|---|
| CanvasKit fetched from a CDN | **fixed** — measured: 0 CDN requests, 2 from our origin |
| Blank page with no message when boot fails | **fixed** — bilingual screen + retry |
| Firebase JS SDK fetched from `gstatic.com` | **not fixed** — see below |
| App boots with `gstatic.com` unreachable | **no** — see below |

The Firebase JS SDK is loaded by the `firebase_core` web plugin from a URL
that plugin controls:

```
https://www.gstatic.com/firebasejs/11.9.1/firebase-app.js
                                          firebase-auth.js
                                          firebase-firestore.js
                                          firebase-storage.js
```

Self-hosting those would mean overriding plugin-internal loading, which is
out of scope for a resilience fix and would need re-validating on every
plugin upgrade.

**So blocking `gstatic.com` still prevents the app from starting.** What
changed is that the user is now told so, in their language, with a retry —
instead of staring at a blank page. That is a real improvement and it is
also the limit of it. Self-hosting the Firebase SDK, or degrading to a
cached/offline mode when it is unavailable, remains open work.

Note this is web-only. On Android and iOS the Firebase SDK is compiled in,
so none of this applies there.

## The smoke check

```bash
flutter build web --release --no-web-resources-cdn
npm --prefix test_web_boot install
npm --prefix test_web_boot run smoke
```

It serves `build/web` locally and runs three scenarios in Chromium:

| scenario | setup | required outcome |
|---|---|---|
| **A** | `gstatic.com` blocked | CanvasKit comes from **our** origin (0 CDN requests), and the failure screen appears — never a blank page |
| **B** | engine replaced with an empty script | `window.dhakkerAppReady()` removes the boot screen |
| **C** | `gstatic.com` **and** local `canvaskit/` blocked | failure screen, with retry, both languages, no internals leaked |

**B is isolated deliberately.** With nothing loading and nothing failing, the
watchdog has no reason to settle either way, so the hook is the only thing
that can resolve it — which makes it a test of the contract
`lib/boot_signal.dart` depends on, not of whatever the network happened to
do. It also documents that the watchdog is one-shot: once the failure screen
is up it stays up, and a late app-ready signal will not swap a message the
user is already reading for a half-loaded app.

**C matters as much as A.** Without deliberately breaking the boot, the
fallback would never run and could rot untested.

Set `CHROMIUM_PATH` if Chromium is not at one of the paths it probes.

### What the smoke check does not establish

**That the app boots.** It cannot: there is no network, so the Firebase JS
SDK is unreachable and the app never reaches a first frame in this
environment. Scenario B tests the watchdog's success path directly rather
than pretending otherwise. A successful boot, and anything about live
Firebase data, are separate claims that this file does not support — they
need a real browser against a real project.
