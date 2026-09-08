// Sign-up is two writes against two services that share no transaction.
//
// The screen used to create the Firebase Auth account, then write
// `users/{uid}`. A failure between the two left an account with no profile —
// and that is a permanent lockout, not a retryable error:
//
//   * sign-in reads `users/{uid}`, finds nothing, and signs the user out;
//   * signing up again fails with `email-already-in-use`;
//   * nothing else in the app creates the missing document.
//
// One dropped connection on hotel wifi, and the pilgrim can never use that
// email again. These tests pin down that the half that succeeded is undone,
// and that the one case where it cannot be undone is reported rather than
// dressed up as success.

import 'package:flutter_test/flutter_test.dart';

import 'package:dhakker/services/registration.dart';

/// Records what was called, so ordering and rollback are observed rather
/// than inferred.
class Recorder {
  final List<String> calls = <String>[];
  String? profileUid;
}

Future<RegistrationResult> run({
  required Recorder r,
  String? uid = 'uid-1',
  Object? accountThrows,
  Object? profileThrows,
  Object? deleteThrows,
}) {
  return registerPilgrim(
    createAccount: () async {
      r.calls.add('createAccount');
      if (accountThrows != null) throw accountThrows;
      return uid;
    },
    writeProfile: (u) async {
      r.calls.add('writeProfile');
      r.profileUid = u;
      if (profileThrows != null) throw profileThrows;
    },
    deleteAccount: () async {
      r.calls.add('deleteAccount');
      if (deleteThrows != null) throw deleteThrows;
    },
  );
}

void main() {
  group('the happy path', () {
    test('creates the account, then the profile, and deletes nothing',
        () async {
      final r = Recorder();
      final result = await run(r: r);

      expect(result.outcome, RegistrationOutcome.created);
      expect(result.isSuccess, isTrue);
      expect(result.uid, 'uid-1');
      expect(r.calls, ['createAccount', 'writeProfile']);
    });

    test('the profile is written for the uid the account returned', () async {
      final r = Recorder();
      await run(r: r, uid: 'uid-42');
      expect(r.profileUid, 'uid-42');
    });
  });

  group('the account itself fails', () {
    test('nothing is left behind, and no rollback is attempted', () async {
      final r = Recorder();
      final result = await run(r: r, accountThrows: Exception('offline'));

      expect(result.outcome, RegistrationOutcome.accountFailed);
      expect(r.calls, ['createAccount'],
          reason: 'there was nothing to write or undo');
    });

    test('the underlying error is kept for the caller to map', () async {
      // The screen turns a FirebaseAuthException code into a specific
      // message; swallowing it would flatten every cause into "unknown".
      final r = Recorder();
      final boom = StateError('email-already-in-use');
      final result = await run(r: r, accountThrows: boom);

      expect(result.error, same(boom));
    });

    test('a provider that returns no uid is a failure, not a success',
        () async {
      for (final bad in [null, '']) {
        final r = Recorder();
        final result = await run(r: r, uid: bad);

        expect(result.outcome, RegistrationOutcome.accountFailed);
        expect(r.calls, ['createAccount'],
            reason: 'a profile must never be written for an empty uid');
      }
    });
  });

  group('the profile write fails — the regression', () {
    test('the account is deleted, so the email can be used again', () async {
      final r = Recorder();
      final result = await run(r: r, profileThrows: Exception('permission'));

      expect(result.outcome, RegistrationOutcome.rolledBack);
      expect(r.calls, ['createAccount', 'writeProfile', 'deleteAccount']);
    });

    test('it is never reported as success', () async {
      final r = Recorder();
      final result = await run(r: r, profileThrows: Exception('offline'));

      expect(result.isSuccess, isFalse);
      expect(result.uid, isNull,
          reason: 'no uid may be handed back for an account that is gone');
    });

    test('the profile error is kept, not the rollback', () async {
      final r = Recorder();
      final cause = StateError('firestore unavailable');
      final result = await run(r: r, profileThrows: cause);

      expect(result.error, same(cause));
    });
  });

  group('the rollback also fails', () {
    test('it is reported as orphaned, not as rolled back', () async {
      // This is the only case that leaves an account with no profile. It
      // must be visible: telling the user to "try again" would send them
      // into email-already-in-use forever.
      final r = Recorder();
      final result = await run(
        r: r,
        profileThrows: Exception('permission'),
        deleteThrows: Exception('requires-recent-login'),
      );

      expect(result.outcome, RegistrationOutcome.orphaned);
      expect(result.isSuccess, isFalse);
      expect(r.calls, ['createAccount', 'writeProfile', 'deleteAccount']);
    });

    test('it still does not throw — the screen decides what to show', () async {
      final r = Recorder();
      await expectLater(
        run(
          r: r,
          profileThrows: Exception('a'),
          deleteThrows: Exception('b'),
        ),
        completes,
      );
    });
  });

  group('the four outcomes are distinguishable', () {
    test('each failure mode has its own outcome', () async {
      // The screen shows a different message for each; collapsing any two
      // would tell a user to retry when they cannot, or vice versa.
      final outcomes = <RegistrationOutcome>{
        (await run(r: Recorder())).outcome,
        (await run(r: Recorder(), accountThrows: Exception('x'))).outcome,
        (await run(r: Recorder(), profileThrows: Exception('x'))).outcome,
        (await run(
          r: Recorder(),
          profileThrows: Exception('x'),
          deleteThrows: Exception('y'),
        ))
            .outcome,
      };
      expect(outcomes.length, 4);
    });
  });
}
