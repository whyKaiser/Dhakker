// Startup failure handling and resource lifecycle.
//
// Three defects, one theme: the app claimed a state it had not reached, or
// held a resource it had finished with.
//
//   1. `signalAppReady()` ran unconditionally, so a failed
//      Firebase.initializeApp still tore down the web boot screen and handed
//      the viewer a UI whose every data call failed in silence. The error
//      handlers were installed inside the same try, AFTER initialization, so
//      the one failure that most needed reporting also disabled reporting.
//   2. The Qibla compass subscription was never cancelled — the magnetometer
//      stayed powered and the State stayed alive for the process lifetime.
//   3. DuaPlaybackService.dispose() called stop() but never disposed the
//      AudioPlayer or its onPlayerComplete subscription.
//
// Each test below fails against the previous code; the mutation checks are
// recorded in the pull request.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/Screens/Piligram/Home/services/dua_playback_service.dart';
import 'package:dhakker/Screens/Piligram/Qibla/qibla_screen.dart';
import 'package:dhakker/startup.dart';

// ── 3 · Playback engine teardown ──────────────────────────────────────────

/// DuaPlaybackService with its engine seams recorded rather than driven, so
/// the real dispose ordering runs without an AudioPlayer or a TTS engine.
class _RecordingPlayback extends DuaPlaybackService {
  final List<String> calls = <String>[];

  @override
  Future<void> stopEngines() async => calls.add('stopEngines');

  @override
  Future<void> disposeEngines() async => calls.add('disposeEngines');
}

// ── 1 · Startup ───────────────────────────────────────────────────────────

/// AppStartup with every seam driven from the test, so the real sequencing
/// logic runs without Firebase, a browser, or a device.
class _TestStartup extends AppStartup {
  _TestStartup({this.failTimes = 0});

  /// How many initialization attempts should throw before one succeeds.
  int failTimes;

  int attempts = 0;
  int readyCalls = 0;
  int failedCalls = 0;
  final List<Object> recorded = <Object>[];

  @override
  Future<void> initializeFirebase() async {
    attempts++;
    if (failTimes > 0) {
      failTimes--;
      throw StateError('firebase unavailable');
    }
  }

  @override
  void notifyReady() => readyCalls++;

  @override
  void notifyFailed() => failedCalls++;

  @override
  void recordError(Object error, StackTrace? stack, {bool fatal = false}) {
    recorded.add(error);
  }
}

void main() {
  group('startup outcome', () {
    test('a successful initialization reports ready, never failed', () async {
      final s = _TestStartup();

      expect(await s.run(), isTrue);
      s.signalOutcome();

      expect(s.firebaseReady, isTrue);
      expect(s.lastError, isNull);
      expect(s.readyCalls, 1);
      expect(s.failedCalls, 0);
    });

    test('a failed initialization reports failed, and NEVER ready', () async {
      // The regression that matters: "ready" was previously sent no matter
      // what, which is what made a broken app look finished.
      final s = _TestStartup(failTimes: 1);

      expect(await s.run(), isFalse);
      s.signalOutcome();

      expect(s.firebaseReady, isFalse);
      expect(s.readyCalls, 0, reason: 'a failed start must not report ready');
      expect(s.failedCalls, 1);
    });

    test('the failure is kept, not swallowed', () async {
      final s = _TestStartup(failTimes: 1);
      await s.run();

      expect(s.lastError, isA<StateError>());
    });

    test('run() never rethrows — the caller decides what to render', () async {
      final s = _TestStartup(failTimes: 1);
      await expectLater(s.run(), completion(isFalse));
    });

    test('a later success clears the earlier failure', () async {
      final s = _TestStartup(failTimes: 1);
      expect(await s.run(), isFalse);

      expect(await s.run(), isTrue);
      expect(s.lastError, isNull, reason: 'a stale error must not linger');
      expect(s.attempts, 2);
    });
  });

  group('error handlers', () {
    test('are installed before initialization can throw', () async {
      // Previously assigned inside the try, after Firebase.initializeApp, so
      // a failed initialization left no handler at all.
      final s = _TestStartup(failTimes: 1);
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      s.installErrorHandlers();
      await s.run();

      expect(s.firebaseReady, isFalse);
      FlutterError.onError!(
        FlutterErrorDetails(exception: ArgumentError('after a failed start')),
      );
      expect(s.recorded, hasLength(1),
          reason: 'errors must still be recorded when startup failed');
    });

    test('the installed handler survives a successful start too', () async {
      final s = _TestStartup();
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);

      s.installErrorHandlers();
      await s.run();

      FlutterError.onError!(
        FlutterErrorDetails(exception: ArgumentError('after a good start')),
      );
      expect(s.recorded, hasLength(1));
    });
  });

  group('StartupFailureScreen', () {
    testWidgets('states the failure in both languages, with a retry',
        (tester) async {
      await tester.pumpWidget(
        StartupFailureScreen(onRetry: () async => false),
      );

      expect(find.byKey(const Key('startup-failure-title-ar')), findsOneWidget);
      expect(find.byKey(const Key('startup-failure-title-en')), findsOneWidget);
      expect(find.byKey(const Key('startup-retry-button')), findsOneWidget);
    });

    testWidgets('retry re-attempts startup', (tester) async {
      var attempts = 0;
      await tester.pumpWidget(StartupFailureScreen(onRetry: () async {
        attempts++;
        return false;
      }));

      await tester.tap(find.byKey(const Key('startup-retry-button')));
      await tester.pumpAndSettle();

      expect(attempts, 1);
    });

    testWidgets('a retry that fails again says so instead of going quiet',
        (tester) async {
      await tester.pumpWidget(
        StartupFailureScreen(onRetry: () async => false),
      );
      expect(find.byKey(const Key('startup-retry-failed')), findsNothing);

      await tester.tap(find.byKey(const Key('startup-retry-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('startup-retry-failed')), findsOneWidget);
    });

    testWidgets('a successful retry does not show the failed notice',
        (tester) async {
      await tester.pumpWidget(
        StartupFailureScreen(onRetry: () async => true),
      );

      await tester.tap(find.byKey(const Key('startup-retry-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('startup-retry-failed')), findsNothing);
    });

    testWidgets('the button is disabled while a retry is in flight',
        (tester) async {
      final gate = Completer<bool>();
      var attempts = 0;
      await tester.pumpWidget(StartupFailureScreen(onRetry: () async {
        attempts++;
        return gate.future;
      }));

      await tester.tap(find.byKey(const Key('startup-retry-button')));
      await tester.pump();

      // A second tap while the first is still running must not queue another.
      await tester.tap(find.byKey(const Key('startup-retry-button')));
      await tester.pump();
      expect(attempts, 1);

      gate.complete(false);
      await tester.pumpAndSettle();
    });
  });

  // ── 2 · Qibla compass subscription ──────────────────────────────────────

  group('QiblaScreen compass subscription', () {
    testWidgets('is released when the screen is disposed', (tester) async {
      // A broadcast controller reports its listeners, so cancellation is
      // observed directly rather than inferred. No CompassEvent is needed —
      // the question is whether the subscription outlives the widget.
      final controller = StreamController<CompassEvent>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        MaterialApp(home: QiblaScreen(compassEvents: controller.stream)),
      );
      // The subscription is opened after an awaited location lookup (which
      // fails in a test, as it should — there is no plugin), so let the
      // microtasks that follow it run before observing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.hasListener, isTrue,
          reason: 'the screen should be following the compass while shown');

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(controller.hasListener, isFalse,
          reason: 'the compass subscription outlived the screen');
    });

    testWidgets('does not hold the stream open across repeated visits',
        (tester) async {
      // The leak compounds: the screen is opened many times in a day, and
      // every visit used to add a listener that never went away.
      final controller = StreamController<CompassEvent>.broadcast();
      addTearDown(controller.close);

      for (var i = 0; i < 3; i++) {
        await tester.pumpWidget(
          MaterialApp(home: QiblaScreen(compassEvents: controller.stream)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();
      }

      expect(controller.hasListener, isFalse);
    });
  });

  // ── 3 · Playback engine teardown ────────────────────────────────────────

  group('DuaPlaybackService.dispose', () {
    test('releases the engines, not just stops them', () async {
      // dispose() used to be `await stop();` alone, so the AudioPlayer and
      // its onPlayerComplete subscription stayed alive with native resources
      // held. Every playback screen leaked one.
      final s = _RecordingPlayback();

      await s.dispose();

      expect(s.calls, contains('disposeEngines'),
          reason: 'the player was stopped but never released');
    });

    test('stops before releasing', () async {
      // Disposing a player before stopping it is a use of a released object;
      // the order is the fix, not an accident of where the line was added.
      final s = _RecordingPlayback();

      await s.dispose();

      expect(s.calls, ['stopEngines', 'disposeEngines']);
    });

    test('leaves the service reporting not-playing', () async {
      // Teardown must not skip the state update stop() performs, or a
      // listening screen is left believing audio is still running.
      final s = _RecordingPlayback();

      await s.dispose();

      expect(s.isPlaying, isFalse);
    });

    test('is safe to call twice', () async {
      // A screen disposed twice (or a service torn down after an error)
      // must not throw on the already-cancelled subscription.
      final s = _RecordingPlayback();

      await s.dispose();
      await expectLater(s.dispose(), completes);
    });
  });
}
