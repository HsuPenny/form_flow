import 'dart:collection';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'paged_feed.dart';
import 'repositories/auth_repository.dart';
import 'repositories/form_repository.dart';
import 'theme_mode_store.dart';

/// App-wide view state. Reads and writes go through the repositories; this
/// class keeps the latest results so widgets can read them synchronously.
///
/// Write methods throw when the backend rejects them; callers show the error.
class AppState extends ChangeNotifier {
  AppState({
    required AuthRepository auth,
    required FormRepository forms,
    ThemeModeStore? themeStore,
    ThemeMode themeMode = ThemeMode.system,
  }) : _auth = auth,
       _formRepo = forms,
       _themeStore = themeStore ?? MemoryThemeModeStore(),
       _themeMode = themeMode;

  final AuthRepository _auth;
  final FormRepository _formRepo;
  final ThemeModeStore _themeStore;
  ThemeMode _themeMode;

  /// 淺色 / 深色 / 跟隨系統. Device-local, so it survives logging out.
  ThemeMode get themeMode => _themeMode;

  /// Applies right away; a failed save only means the choice is forgotten on
  /// the next launch, so it is logged instead of thrown.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      await _themeStore.save(mode);
    } catch (e) {
      debugPrint('Could not save theme mode: $e');
    }
  }

  bool _signedIn = false;
  bool _restoring = false;
  UserProfile? _profile;
  List<Member> _members = [];
  List<FormItem> _forms = [];
  List<String> _departments = [];

  List<Member> get members => UnmodifiableListView(_members);
  List<String> get departments => UnmodifiableListView(_departments);

  /// Every form, for 表單管理. Only admins load it; members' pages ask the
  /// backend for one [FormCategory] batch at a time ([fetchMyForms]).
  List<FormItem> get forms => UnmodifiableListView(_forms);

  /// Kept after logout so the shell can still render while it animates out.
  Role? get role => _profile?.role;
  Member get me => _profile!.asMember;
  String get email => _profile?.email ?? '';
  String get displayName => _profile?.displayName ?? '';
  String get department => _profile?.department ?? '';
  bool get notifyAssigned => _profile?.notifyAssigned ?? true;
  bool get weeklyDigest => _profile?.weeklyDigest ?? false;

  bool get isLoggedIn => _signedIn;

  /// True while [restoreSession] runs, before we know which page to show.
  bool get isRestoring => _restoring;
  bool get isAdmin => role == Role.admin;
  String get initials =>
      displayName.length <= 2 ? displayName : displayName.substring(0, 2);

  /// Signs back in with the session saved by a previous launch, if any.
  /// Stays signed out when that fails (e.g. offline).
  Future<void> restoreSession() async {
    _restoring = true;
    notifyListeners();
    try {
      final profile = await _auth.currentUser();
      if (profile != null) await _enter(profile);
    } catch (e) {
      debugPrint('Could not restore session: $e');
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async =>
      _enter(await _auth.signIn(email: email, password: password));

  /// Returns false when the account needs the emailed code first; pass it
  /// to [verifySignUp] to finish signing in.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final profile = await _auth.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (profile == null) return false;
    await _enter(profile);
    return true;
  }

  Future<void> verifySignUp({
    required String email,
    required String code,
  }) async => _enter(await _auth.verifySignUp(email: email, code: code));

  Future<void> resendSignUpCode({required String email}) =>
      _auth.resendSignUpCode(email: email);

  Future<void> sendPasswordReset({required String email}) =>
      _auth.sendPasswordReset(email: email);

  Future<void> verifyRecoveryCode({
    required String email,
    required String code,
  }) => _auth.verifyRecoveryCode(email: email, code: code);

  Future<void> resetPassword({required String newPassword}) async =>
      _enter(await _auth.resetPassword(newPassword: newPassword));

  Future<void> cancelPasswordReset() => _auth.cancelPasswordReset();

  Future<void> _enter(UserProfile profile) async {
    _profile = profile;
    final (members, forms, departments) = await (
      _formRepo.fetchMembers(),
      _fetchAllForms(profile.role),
      // Only the settings dropdown needs these; don't block sign-in on them.
      _formRepo.fetchDepartments().catchError((Object e) {
        debugPrint('Could not load departments: $e');
        return <String>[];
      }),
    ).wait;
    _members = members;
    _forms = forms;
    _departments = departments;
    _signedIn = true;
    notifyListeners();
  }

  /// 只有管理員的表單管理需要全部表單；成員的畫面都依分類分批向後端要，
  /// 登入與重新整理時就不必整包下載。
  Future<List<FormItem>> _fetchAllForms(Role? role) async =>
      role == Role.admin ? _formRepo.fetchForms() : <FormItem>[];

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _auth.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  Future<void> logout() async {
    await _auth.signOut();
    _signedIn = false;
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String department,
  }) => _saveProfile(
    (p) => p.copyWith(displayName: name, department: department),
  );

  Future<void> setNotifyAssigned(bool v) =>
      _saveProfile((p) => p.copyWith(notifyAssigned: v));

  Future<void> setWeeklyDigest(bool v) =>
      _saveProfile((p) => p.copyWith(weeklyDigest: v));

  Future<void> _saveProfile(UserProfile Function(UserProfile) edit) async {
    _profile = await _auth.updateProfile(edit(_profile!));
    notifyListeners();
  }

  /// Creates [form], or updates the existing form with the same id.
  Future<void> saveForm(FormItem form) async {
    _putForm(await _formRepo.saveForm(form));
    notifyListeners();
  }

  Future<void> deleteForm(FormItem form) async {
    await _formRepo.deleteForm(form.id);
    _forms.removeWhere((f) => f.id == form.id);
    notifyListeners();
  }

  /// Reloads forms and members, e.g. to pick up newly assigned forms and
  /// other people's replies.
  Future<void> refreshForms() async {
    final (members, forms) = await (
      _formRepo.fetchMembers(),
      _fetchAllForms(role),
    ).wait;
    _members = members;
    _forms = forms;
    notifyListeners();
  }

  /// One batch of the signed-in user's [kind] forms; see [FormCategory].
  Future<PageResult<FormItem>> fetchMyForms(
    FormCategory kind, {
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) => _formRepo.fetchMyForms(
    memberId: me.id,
    kind: kind,
    query: query,
    offset: offset,
    limit: limit,
  );

  Future<void> addRecipients(FormItem form, List<Member> members) async {
    _putForm(await _formRepo.addRecipients(form.id, members));
    notifyListeners();
  }

  Future<void> extendDeadline(FormItem form, DateTime deadline) async {
    _putForm(await _formRepo.extendDeadline(form.id, deadline));
    notifyListeners();
  }

  Future<void> closeForm(FormItem form) async {
    _putForm(await _formRepo.closeForm(form.id));
    notifyListeners();
  }

  Future<void> submitResponse(FormItem form, Answers answers) async {
    final response = FormResponse(
      member: me,
      submittedAt: DateTime.now(),
      answers: answers,
    );
    _putForm(await _formRepo.submitResponse(form.id, response));
    notifyListeners();
  }

  void _putForm(FormItem form) {
    final i = _forms.indexWhere((f) => f.id == form.id);
    i < 0 ? _forms.insert(0, form) : _forms[i] = form;
  }
}

/// Exposes [AppState] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
