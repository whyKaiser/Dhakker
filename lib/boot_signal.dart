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
/// The same applies in reverse: `signalAppFailed` tells the page that startup
/// will not complete, so it can show its failure state immediately rather
/// than waiting out the watchdog. Startup sends exactly one of the two.
///
/// On every non-web platform both are no-ops, so `main.dart` can call them
/// unconditionally.

library;

export 'boot_signal_stub.dart'
    if (dart.library.js_interop) 'boot_signal_web.dart';
