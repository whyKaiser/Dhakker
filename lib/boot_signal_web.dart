import 'dart:js_interop';

/// The hook installed by `web/index.html`. Read as a nullable value rather
/// than called blindly: a stale `index.html`, or a page that already removed
/// its boot screen, simply has nothing here, and that must not throw during
/// startup.
@JS('dhakkerAppReady')
external JSFunction? get _dhakkerAppReady;

/// Notifies the host page that the first frame has been painted.
///
/// Deliberately swallows every failure. This is a cosmetic signal to the
/// loading screen; nothing about the app's behaviour may depend on it, and
/// it must never be the reason a startup fails.
void signalAppReady() {
  try {
    _dhakkerAppReady?.callAsFunction();
  } catch (_) {
    // The boot screen will fall back to its timeout. Not worth reporting.
  }
}
