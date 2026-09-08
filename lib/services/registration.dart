/// Signing up is two writes, and it used to be able to finish half done.
///
/// `register_screen.dart` created the Firebase Auth account first, then wrote
/// `users/{uid}`. If the second write failed — offline, quota, a rules change,
/// anything — the account existed with no profile document, and the user was
/// left in a state they could not get out of:
///
///   * signing in reads `users/{uid}`, finds nothing, signs them straight
///     back out with "no profile document";
///   * registering again fails with `email-already-in-use`;
///   * nothing in the app creates the missing document.
///
/// A permanent lockout from one transient network error, on the screen a
/// pilgrim uses once, probably on hotel wifi.
///
/// Firestore and Auth are separate services with no shared transaction, so
/// "both or neither" cannot be asked for. What can be done is to undo the
/// half that succeeded: the account is deleted, and the user is told to try
/// again. That is the conservative direction — an orphaned account is a dead
/// end, while no account is simply a retry.
///
/// The alternative, letting sign-in create the missing document, was not
/// taken: it would mean an account whose registration failed silently becomes
/// valid later, and the failure would never be seen at all.
library;

/// What happened, in terms the caller can turn into a message.
enum RegistrationOutcome {
  /// Account and profile both exist.
  created,

  /// The account could not be created. Nothing was left behind.
  accountFailed,

  /// The profile write failed and the account was rolled back. The user can
  /// safely try again with the same email.
  rolledBack,

  /// The profile write failed AND the rollback failed. An account now exists
  /// with no profile. This is the case that must never be reported as
  /// success, and the one the user has to be told about honestly, because
  /// only an administrator can clear it.
  orphaned,
}

/// Result of an attempted registration.
class RegistrationResult {
  const RegistrationResult(this.outcome, {this.uid, this.error});

  final RegistrationOutcome outcome;

  /// Set only when [outcome] is [RegistrationOutcome.created].
  final String? uid;

  /// The underlying failure, kept rather than swallowed.
  final Object? error;

  bool get isSuccess => outcome == RegistrationOutcome.created;
}

/// Creates an account and its profile document as one unit, undoing the
/// account if the profile cannot be written.
///
/// Every side effect is injected, so the whole decision table runs in a test
/// without Firebase, a network, or a device.
///
/// * [createAccount] returns the new uid, or null if the provider gave none.
/// * [writeProfile] writes `users/{uid}`.
/// * [deleteAccount] removes the just-created account. Called only on the
///   profile-write failure path.
Future<RegistrationResult> registerPilgrim({
  required Future<String?> Function() createAccount,
  required Future<void> Function(String uid) writeProfile,
  required Future<void> Function() deleteAccount,
}) async {
  String? uid;
  try {
    uid = await createAccount();
  } catch (e) {
    return RegistrationResult(RegistrationOutcome.accountFailed, error: e);
  }
  if (uid == null || uid.isEmpty) {
    return const RegistrationResult(RegistrationOutcome.accountFailed);
  }

  try {
    await writeProfile(uid);
    return RegistrationResult(RegistrationOutcome.created, uid: uid);
  } catch (profileError) {
    // The account exists and the profile does not. Undo the half that
    // succeeded so the user can simply try again.
    try {
      await deleteAccount();
      return RegistrationResult(
        RegistrationOutcome.rolledBack,
        error: profileError,
      );
    } catch (_) {
      // Both failed. Say so — reporting success here is what would strand
      // the user, and a vague error would send them to try the same thing
      // again forever.
      return RegistrationResult(
        RegistrationOutcome.orphaned,
        error: profileError,
      );
    }
  }
}
