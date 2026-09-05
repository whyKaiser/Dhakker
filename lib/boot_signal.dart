/// Tells the host page that the Flutter app has actually painted a frame.
///
/// The web boot watchdog in `web/index.html` needs to distinguish two states
/// that look identical from the DOM:
///
///   * the engine started and inserted its host element, but the app never
///     rendered anything — the viewer sees a flat, empty rectangle;
///   * the app is genuinely up.
///
/// Watching for `flt-glass-pane` cannot tell them apart: the element is
/// inserted by the engine before any widget paints, so it appears in both.
/// The only party that knows the difference is the app itself, which is why
/// the signal is sent from Dart rather than inferred from the DOM.
///
/// On every non-web platform this is a no-op, so `main.dart` can call it
/// unconditionally.

library;

export 'boot_signal_stub.dart'
    if (dart.library.js_interop) 'boot_signal_web.dart';
