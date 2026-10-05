import '../models.dart';
import 'auth_repository.dart';

/// Accepts any email and password and keeps the profile in memory.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({Role role = Role.admin})
    : _profile = UserProfile(
        id: 'me',
        role: role,
        email: 'lisa.wang@northstar.co',
        displayName: '王莉莎',
        department: '營運管理',
      );

  UserProfile _profile;
  bool _signedIn = false;

  @override
  Future<UserProfile?> currentUser() async => _signedIn ? _profile : null;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    _signedIn = true;
    return _profile = _withEmail(email);
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _signedIn = true;
    return _profile = _withEmail(
      email,
    ).copyWith(displayName: displayName, department: '');
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {}

  @override
  Future<UserProfile> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => signIn(email: email, password: newPassword);

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
