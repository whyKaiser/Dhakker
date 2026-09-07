import 'dart:async';
import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'boot_signal.dart';

/// How the app starts, and what it does when it cannot.
///
/// This exists as its own unit because the failure path used to be a
/// `debugPrint` inside a `catch` in `main()`, and nothing downstream could
/// see it. The consequences were worse than a lost log line:
///
///   * `signalAppReady()` ran unconditionally after `runApp`, so on the web
///     the boot screen was torn down and the viewer got an app that looked
///     finished while every Firestore call failed silently. That is exactly
///     the "looks ready, is not" state the boot screen was built to prevent.
///   * `FlutterError.onError` and `PlatformDispatcher.onError` were assigned
///     INSIDE the same `try`, after `Firebase.initializeApp`. When
///     initialization threw, neither was ever installed — so the one failure
///     mode that most needed reporting also disabled error reporting.
///
/// Both are inverted here: error handlers are installed before anything can
/// throw, and the ready signal is sent only on success.
///
/// The seams below are overridable so the whole sequence can be exercised in
/// a test without a real Firebase, a browser, or a device.
class AppStartup {
  AppStartup();

  /// Whether the last [run] reached a usable state.
  bool get firebaseReady => _firebaseReady;
  bool _firebaseReady = false;

  /// The error that stopped startup, or null. Kept for the failure screen —
  /// it is shown to a developer through a log, never rendered to a pilgrim.
  Object? get lastError => _lastError;
  Object? _lastError;

  // ── seams ───────────────────────────────────────────────────────────────
  //
  // Each is a one-line forward to the real thing. A test overrides these and
  // every other line below runs for real.

  /// Brings Firebase up. Throws if it cannot.
  @protected
  @visibleForTesting
  Future<void> initializeFirebase() async {
    throw UnimplementedError('initializeFirebase must be provided');
  }

  /// Tells the host page the first frame painted. No-op off the web.
  @protected
  @visibleForTesting
  void notifyReady() => signalAppReady();

  /// Tells the host page startup failed, so the boot screen shows its
  /// bilingual failure state instead of waiting out the 30s watchdog.
  /// No-op off the web.
  @protected
  @visibleForTesting
  void notifyFailed() => signalAppFailed();

  /// Records an uncaught error. Overridden in tests; forwards to Crashlytics
  /// in production, but only once Firebase is actually up — see
  /// [installErrorHandlers].
  @protected
  @visibleForTesting
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    if (!_firebaseReady) {
      // No Crashlytics to report to. Losing the error entirely is worse than
      // printing it, and this is the exact window in which startup failures
      // occur.
      FlutterError.presentError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
      return;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }

  /// Installs the global error handlers.
  ///
  /// Called before any initialization is attempted, so a crash during startup
  /// is still caught. [recordError] decides at call time whether Crashlytics
  /// is available, which is why installing early is safe.
  void installErrorHandlers() {
    FlutterError.onError = (details) {
      recordError(details.exception, details.stack, fatal: true);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Attempts initialization. Returns true on success.
  ///
  /// Never rethrows: the caller decides what to render. The error is kept in
  /// [lastError] rather than swallowed.
  Future<bool> run() async {
    try {
      await initializeFirebase();
      _firebaseReady = true;
      _lastError = null;
    } catch (e) {
      _firebaseReady = false;
      _lastError = e;
      debugPrint('Firebase initialization failed: $e');
    }
    return _firebaseReady;
  }

  /// Signals the outcome to the host page. Ready is sent ONLY on success.
  void signalOutcome() {
    if (_firebaseReady) {
      notifyReady();
    } else {
      notifyFailed();
    }
  }
}

/// Shown when the app cannot start. Bilingual, with a retry.
///
/// Deliberately depends on nothing but Flutter: no localization delegates, no
/// theme controller, no Firebase. Everything it might otherwise reach for is
/// part of what may have failed.
class StartupFailureScreen extends StatefulWidget {
  const StartupFailureScreen({
    super.key,
    required this.onRetry,
  });

  /// Re-attempts startup. Resolves true when the app is usable.
  final Future<bool> Function() onRetry;

  @override
  State<StartupFailureScreen> createState() => _StartupFailureScreenState();
}

class _StartupFailureScreenState extends State<StartupFailureScreen> {
  bool _retrying = false;
  bool _retryFailed = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryFailed = false;
    });
    final ok = await widget.onRetry();
    if (!mounted) return;
    setState(() {
      _retrying = false;
      // On success the caller swaps this screen out; if it is still here,
      // the retry did not work and the pilgrim should be told so rather
      // than left looking at a button that appears to do nothing.
      _retryFailed = !ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFC9A227);
    const ink = Color(0xFF0E1116);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: ink,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚠️', style: TextStyle(fontSize: 44)),
                  const SizedBox(height: 20),
                  const Text(
                    'تعذّر تشغيل التطبيق',
                    key: Key('startup-failure-title-ar'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: gold,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تحقّق من اتصالك بالإنترنت وأعد المحاولة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'The app could not start',
                    key: Key('startup-failure-title-en'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: gold,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  if (_retryFailed) ...[
                    const Text(
                      'ما زالت المحاولة تفشل · Still failing',
                      key: Key('startup-retry-failed'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                  ],
                  FilledButton(
                    key: const Key('startup-retry-button'),
                    onPressed: _retrying ? null : _retry,
                    style: FilledButton.styleFrom(
                      backgroundColor: gold,
                      foregroundColor: ink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 14),
                    ),
                    child: _retrying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ink,
                            ),
                          )
                        : const Text('إعادة المحاولة · Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
