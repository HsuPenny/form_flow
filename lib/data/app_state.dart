import 'dart:collection';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'models.dart';
import 'paged_feed.dart';
import 'repositories/auth_repository.dart';
import 'repositories/form_repository.dart';
import 'text_size_store.dart';
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
    TextSizeStore? textSizeStore,
    TextSize textSize = TextSize.standard,
  }) : _auth = auth,
       _formRepo = forms,
       _themeStore = themeStore ?? MemoryThemeModeStore(),
       _themeMode = themeMode,
       _textSizeStore = textSizeStore ?? MemoryTextSizeStore(),
       _textSize = textSize;

  final AuthRepository _auth;
  final FormRepository _formRepo;
  final ThemeModeStore _themeStore;
  ThemeMode _themeMode;
  final TextSizeStore _textSizeStore;
  TextSize _textSize;

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

  /// 文字大小 (小 / 標準 / 大 / 特大). Device-local, so it survives logging out.
  TextSize get textSize => _textSize;

  /// Applies right away; like [setThemeMode], a failed save is only logged.
  Future<void> setTextSize(TextSize size) async {
    if (size == _textSize) return;
    _textSize = size;
    notifyListeners();
    try {
      await _textSizeStore.save(size);
    } catch (e) {
      debugPrint('Could not save text size: $e');
    }
  }

  bool _signedIn = false;
  bool _restoring = false;
  UserProfile? _profile;
  List<Member> _members = [];
  List<String> _departments = [];

  List<Member> get members => UnmodifiableListView(_members);
  List<String> get departments => UnmodifiableListView(_departments);

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
    // Forms aren't loaded here: every page asks the backend for just the
    // batch it shows (see [fetchMyForms], [fetchPublishedForms]).
    final (members, departments) = await (
      _formRepo.fetchMembers(),
      // Only the settings dropdown needs these; don't block sign-in on them.
      _formRepo.fetchDepartments().catchError((Object e) {
        debugPrint('Could not load departments: $e');
        return <String>[];
      }),
    ).wait;
    _members = members;
    _departments = departments;
    _signedIn = true;
    notifyListeners();
  }

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

  /// Creates [form], or updates the existing form with the same id, and
  /// returns it as saved.
  ///
  /// AppState keeps no list of forms, so the form write methods hand the
  /// updated form back and the page showing it swaps it in.
  Future<FormItem> saveForm(FormItem form) => _formRepo.saveForm(form);

  Future<void> deleteForm(FormItem form) => _formRepo.deleteForm(form.id);

  /// Reloads the member directory, e.g. to pick up people who just joined.
  /// Pages reload their own forms.
  Future<void> refreshMembers() async {
    _members = await _formRepo.fetchMembers();
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

  /// 草稿 for 表單管理, all at once; see [FormRepository.fetchDrafts].
  Future<List<FormItem>> fetchDrafts() => _formRepo.fetchDrafts();

  /// One batch of 完成進度; see [FormRepository.fetchPublishedForms].
  Future<PageResult<FormItem>> fetchPublishedForms({
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) =>
      _formRepo.fetchPublishedForms(query: query, offset: offset, limit: limit);

  /// One batch of 最新回覆; see [FormRepository.fetchResponses].
  Future<PageResult<ResponseEntry>> fetchResponses({
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) => _formRepo.fetchResponses(query: query, offset: offset, limit: limit);

  Future<ProgressSummary> fetchProgressSummary() =>
      _formRepo.fetchProgressSummary();

  /// The write methods below return the updated form; see [saveForm].
  Future<FormItem> addRecipients(FormItem form, List<Member> members) =>
      _formRepo.addRecipients(form.id, members);

  Future<FormItem> extendDeadline(FormItem form, DateTime deadline) =>
      _formRepo.extendDeadline(form.id, deadline);

  Future<FormItem> closeForm(FormItem form) => _formRepo.closeForm(form.id);

  Future<FormItem> submitResponse(FormItem form, Answers answers) =>
      _formRepo.submitResponse(
        form.id,
        FormResponse(member: me, submittedAt: DateTime.now(), answers: answers),
      );
}

/// Exposes [AppState] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
