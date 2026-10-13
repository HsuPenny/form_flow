import '../models.dart';
import 'auth_repository.dart';

/// Accepts any email and password and keeps the profile in memory.
///
/// With [confirmEmail], new accounts need a verification code (any code
/// works) before they can sign in, like Supabase's "Confirm email".
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({Role role = Role.admin, this.confirmEmail = false})
    : _profile = UserProfile(
        id: 'me',
        role: role,
        email: 'lisa.wang@northstar.co',
        displayName: '王莉莎',
        department: '營運管理',
      );

  final bool confirmEmail;

  UserProfile _profile;
  bool _signedIn = false;

  /// Signed-up emails still waiting for their code.
  final _unconfirmed = <String>{};

  @override
  Future<UserProfile?> currentUser() async => _signedIn ? _profile : null;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    if (_unconfirmed.contains(email)) throw const EmailNotConfirmed();
    _signedIn = true;
    return _profile = _withEmail(email);
  }

  @override
  Future<UserProfile?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _profile = _withEmail(
      email,
    ).copyWith(displayName: displayName, department: '');
    if (confirmEmail) {
      _unconfirmed.add(email);
      return null;
    }
    _signedIn = true;
    return _profile;
  }

  @override
  Future<UserProfile> verifySignUp({
    required String email,
    required String code,
  }) async {
    _unconfirmed.remove(email);
    _signedIn = true;
    return _profile = _withEmail(email);
  }

  @override
  Future<void> resendSignUpCode({required String email}) async {}

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  /// The address from [verifyRecoveryCode], signed in by [resetPassword].
  String? _recovering;

  @override
  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) async => _recovering = email;

  @override
  Future<UserProfile> resetPassword({required String newPassword}) =>
      signIn(email: _recovering!, password: newPassword);

  @override
  Future<void> cancelPasswordReset() async => _recovering = null;

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> signOut() async => _signedIn = false;

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async =>
      _profile = profile;

  UserProfile _withEmail(String email) => UserProfile(
    id: _profile.id,
    role: _profile.role,
    email: email,
    displayName: _profile.displayName,
    department: _profile.department,
    notifyAssigned: _profile.notifyAssigned,
    weeklyDigest: _profile.weeklyDigest,
  );
}
