import '../models.dart';

/// A sign-in or sign-up problem, with a message ready to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}

/// Sign-in was refused because the email hasn't been verified yet; the user
/// has to enter the code from the sign-up email first.
class EmailNotConfirmed extends AuthFailure {
  const EmailNotConfirmed() : super('這個信箱還沒完成驗證，請輸入寄到信箱的驗證碼');
}

/// Sign-in and the signed-in user's profile.
///
/// Sign-in methods throw [AuthFailure] for problems the user can fix, and
/// [EmailNotConfirmed] when the account still needs its sign-up code.
abstract interface class AuthRepository {
  /// The profile for a session restored from a previous launch, if any.
  Future<UserProfile?> currentUser();

  Future<UserProfile> signIn({required String email, required String password});

  /// Creates the account and signs in, or returns null when a verification
  /// code was emailed instead; [verifySignUp] then finishes signing in.
  Future<UserProfile?> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Checks the [code] from the sign-up email and signs in.
  Future<UserProfile> verifySignUp({
    required String email,
    required String code,
  });

  /// Emails [email] a new sign-up verification code.
  Future<void> resendSignUpCode({required String email});

  /// Emails [email] a code for setting a new password.
  Future<void> sendPasswordReset({required String email});

  /// Checks the [code] from the reset email. On success [resetPassword] may
  /// set the new password, or [cancelPasswordReset] gives up.
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  });

  /// Sets [newPassword] after [verifyRecoveryCode] and signs in.
  Future<UserProfile> resetPassword({required String newPassword});

  /// Drops what [verifyRecoveryCode] allowed, so the user stays signed out.
  Future<void> cancelPasswordReset();

  /// Changes the signed-in user's password after checking [currentPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  Future<UserProfile> updateProfile(UserProfile profile);
}
