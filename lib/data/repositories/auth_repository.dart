import '../models.dart';

/// A sign-in or sign-up problem, with a message ready to show the user.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}

/// Sign-in and the signed-in user's profile.
///
/// Sign-in methods throw [AuthFailure] for problems the user can fix.
abstract interface class AuthRepository {
  /// The profile for a session restored from a previous launch, if any.
  Future<UserProfile?> currentUser();

  Future<UserProfile> signIn({required String email, required String password});

  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Emails [email] a link to set a new password.
  Future<void> sendPasswordReset({required String email});

  /// Checks the [code] from the reset email, sets [newPassword] and signs in.
  Future<UserProfile> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// Changes the signed-in user's password after checking [currentPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  Future<UserProfile> updateProfile(UserProfile profile);
}
