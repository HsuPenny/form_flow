import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'models.dart';
import 'repositories/auth_repository.dart';
import 'repositories/form_repository.dart';

/// App-wide view state. Reads and writes go through the repositories; this
/// class keeps the latest results so widgets can read them synchronously.
///
/// Write methods throw when the backend rejects them; callers show the error.
class AppState extends ChangeNotifier {
  AppState({required AuthRepository auth, required FormRepository forms})
    : _auth = auth,
      _formRepo = forms;

  final AuthRepository _auth;
  final FormRepository _formRepo;

  bool _signedIn = false;
  bool _restoring = false;
  UserProfile? _profile;
  List<Member> _members = [];
  List<FormItem> _forms = [];

  List<Member> get members => UnmodifiableListView(_members);
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

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async => _enter(
    await _auth.signUp(
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  Future<void> _enter(UserProfile profile) async {
    _profile = profile;
    final (members, forms) = await (
      _formRepo.fetchMembers(),
      _formRepo.fetchForms(),
    ).wait;
    _members = members;
    _forms = forms;
    _signedIn = true;
    notifyListeners();
  }

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
