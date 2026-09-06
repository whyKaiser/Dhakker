// KalmanLatLong — the GPS smoother every Tawaf and Sa'i circuit is counted on.
//
// It had no tests. It is also the one piece of pure arithmetic in the location
// path: `dart:math` is its only import, so it can be driven directly with no
// device, no plugin and no Firebase.
//
// These tests pin the properties the counters depend on, not the exact numbers
// the current constants happen to produce. A filter that stopped converging,
// or that let a single wild fix drag the estimate, would break circuit
// counting in a way that is very hard to see from the app.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/shared/location/location_smoother.dart';

/// Rough metres-per-degree near Makkah (21.42°N). Good enough to talk about
/// distances in metres in assertions without pulling in a geo package.
const double _mPerDegLat = 111320.0;
double _mPerDegLng(double lat) => 111320.0 * cos(lat * pi / 180.0);

const double kaabaLat = 21.422487;
const double kaabaLng = 39.826206;

double _metresBetween(double aLat, double aLng, double bLat, double bLng) {
  final dLat = (aLat - bLat) * _mPerDegLat;
  final dLng = (aLng - bLng) * _mPerDegLng(aLat);
  return sqrt(dLat * dLat + dLng * dLng);
}

void main() {
  group('initial state', () {
    test('starts uninitialised and holds no position', () {
      final k = KalmanLatLong();
      expect(k.isInitialized, isFalse);
      expect(k.lat, isNull);
      expect(k.lng, isNull);
    });

    test('accuracy is 0 rather than NaN before the first fix', () {
      // `accuracy` takes sqrt of the variance, which starts at -1. Guarding
      // that matters: a NaN would propagate silently into any UI reading it.
      final k = KalmanLatLong();
      expect(k.accuracy, 0);
      expect(k.accuracy.isNaN, isFalse);
    });

    test('the first fix is adopted exactly, not blended with anything', () {
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 5, 1000);
      expect(k.isInitialized, isTrue);
      expect(k.lat, kaabaLat);
      expect(k.lng, kaabaLng);
      expect(k.accuracy, closeTo(5, 1e-9));
    });
  });

  group('smoothing', () {
    test('a single wild fix moves the estimate far less than the jump', () {
      // The behaviour circuit counting actually relies on: one bad fix must
      // not teleport the pilgrim across the mataf.
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 5, 0);

      const jumpLat = kaabaLat + 0.0009; // ~100 m north
      k.process(jumpLat, kaabaLng, 50, 1000); // poor accuracy: 50 m

      final moved = _metresBetween(k.lat!, k.lng!, kaabaLat, kaabaLng);
      final jump = _metresBetween(jumpLat, kaabaLng, kaabaLat, kaabaLng);

      expect(jump, greaterThan(90));
      expect(moved, lessThan(jump / 2),
          reason: 'a 50m-accuracy outlier should be heavily discounted');
    });

    test('a precise fix is trusted more than an imprecise one', () {
      double moveFor(double accuracy) {
        final k = KalmanLatLong();
        k.process(kaabaLat, kaabaLng, 5, 0);
        k.process(kaabaLat + 0.0009, kaabaLng, accuracy, 1000);
        return _metresBetween(k.lat!, k.lng!, kaabaLat, kaabaLng);
      }

      // Same jump, same elapsed time — only the reported accuracy differs.
      expect(moveFor(3), greaterThan(moveFor(50)));
    });

    test('repeated fixes at one point converge on that point', () {
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 20, 0);
      const trueLat = kaabaLat + 0.0005;
      const trueLng = kaabaLng + 0.0005;

      for (var i = 1; i <= 60; i++) {
        k.process(trueLat, trueLng, 5, i * 1000);
      }

      expect(_metresBetween(k.lat!, k.lng!, trueLat, trueLng), lessThan(1.0),
          reason: 'sixty consistent fixes should settle within a metre');
    });

    test('reported accuracy improves as consistent fixes accumulate', () {
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 20, 0);
      final first = k.accuracy;

      for (var i = 1; i <= 20; i++) {
        k.process(kaabaLat, kaabaLng, 5, i * 1000);
      }

      expect(k.accuracy, lessThan(first));
      expect(k.accuracy, greaterThan(0),
          reason: 'the filter must never claim perfect certainty');
    });

    test('the estimate always stays between the prior and the new fix', () {
      // A Kalman gain outside 0..1 would overshoot. Checked across a range of
      // accuracies rather than at one convenient value.
      for (final accuracy in <double>[1, 3, 10, 30, 100]) {
        final k = KalmanLatLong();
        k.process(kaabaLat, kaabaLng, 10, 0);
        const newLat = kaabaLat + 0.001;
        k.process(newLat, kaabaLng, accuracy, 1000);

        expect(k.lat, greaterThanOrEqualTo(kaabaLat));
        expect(k.lat, lessThanOrEqualTo(newLat),
            reason: 'overshoot at accuracy=$accuracy means gain left [0,1]');
      }
    });
  });

  group('time handling', () {
    test('a longer gap makes the filter trust the new fix more', () {
      // Uncertainty grows with elapsed time, so after a long silence a fresh
      // fix should carry more weight than after a moment.
      double moveAfter(int gapMs) {
        final k = KalmanLatLong();
        k.process(kaabaLat, kaabaLng, 5, 0);
        k.process(kaabaLat + 0.0009, kaabaLng, 5, gapMs);
        return _metresBetween(k.lat!, k.lng!, kaabaLat, kaabaLng);
      }

      expect(moveAfter(60000), greaterThan(moveAfter(100)));
    });

    test('out-of-order and duplicate timestamps do not corrupt the estimate',
        () {
      // Android delivers fixes out of order often enough to matter, and the
      // guard is a single `if (dtMs > 0)`.
      //
      // The symptom of losing it is NOT a NaN — it is OVERSHOOT. A negative
      // delta drives the variance negative, the Kalman gain leaves [0,1], and
      // the estimate lands beyond the fix it was correcting toward. Verified
      // by removing the guard: the estimate went to 21.4234898 for a fix at
      // 21.423487, i.e. past it. So the bound is what this asserts.
      const priorLat = kaabaLat;
      const laterLat = kaabaLat + 0.001;

      final k = KalmanLatLong();
      k.process(priorLat, kaabaLng, 5, 1000000);
      k.process(laterLat, kaabaLng, 5, 0); // 1000 seconds backwards

      expect(k.lat!.isNaN, isFalse);
      expect(k.lng!.isNaN, isFalse);
      expect(k.accuracy.isNaN, isFalse);
      expect(k.lat, greaterThanOrEqualTo(priorLat));
      expect(k.lat, lessThanOrEqualTo(laterLat),
          reason: 'a backwards timestamp must not push the gain outside [0,1]');

      // A duplicate timestamp is the same case with dt == 0.
      k.process(laterLat, kaabaLng, 5, 0);
      expect(k.lat, lessThanOrEqualTo(laterLat));
      expect(k.accuracy, greaterThan(0));
    });
  });

  group('degenerate inputs', () {
    test('an accuracy of zero does not divide by zero', () {
      // Some devices report 0. The floor is 1 m; without it the gain is 0/0.
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 0, 0);
      expect(k.accuracy, closeTo(1.0, 1e-9),
          reason: 'accuracy is floored at 1 m');

      k.process(kaabaLat + 0.0001, kaabaLng, 0, 1000);
      expect(k.lat!.isNaN, isFalse);
      expect(k.accuracy.isNaN, isFalse);
    });

    test('a negative accuracy is floored too', () {
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, -5, 0);
      expect(k.accuracy, closeTo(1.0, 1e-9));
    });
  });

  group('reset', () {
    test('reset returns the filter to its uninitialised state', () {
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 5, 0);
      k.process(kaabaLat + 0.0001, kaabaLng, 5, 1000);
      expect(k.isInitialized, isTrue);

      k.reset();

      expect(k.isInitialized, isFalse);
      expect(k.lat, isNull);
      expect(k.lng, isNull);
      expect(k.accuracy, 0);
    });

    test('after reset the next fix is adopted exactly, not blended', () {
      // Starting a new Tawaf must not inherit the previous session's estimate.
      final k = KalmanLatLong();
      k.process(kaabaLat, kaabaLng, 5, 0);
      k.reset();

      const elsewhereLat = 21.3891; // Masjid al-Haram is behind us
      const elsewhereLng = 39.8579;
      k.process(elsewhereLat, elsewhereLng, 5, 1000);

      expect(k.lat, elsewhereLat);
      expect(k.lng, elsewhereLng);
    });
  });

  group('configuration', () {
    test('the default process noise matches what the app constructs', () {
      // lib/bloc/cubit.dart builds KalmanLatLong(qMetresPerSecond: 3); the
      // default is the same, so the two cannot silently diverge.
      expect(KalmanLatLong().qMetresPerSecond, 3);
    });

    test('a higher process noise makes the filter more responsive', () {
      double moveWith(double q) {
        final k = KalmanLatLong(qMetresPerSecond: q);
        k.process(kaabaLat, kaabaLng, 5, 0);
        k.process(kaabaLat + 0.0009, kaabaLng, 5, 5000);
        return _metresBetween(k.lat!, k.lng!, kaabaLat, kaabaLng);
      }

      expect(moveWith(10), greaterThan(moveWith(1)),
          reason: 'q is the expected walking speed: higher = less smoothing');
    });
  });
}
