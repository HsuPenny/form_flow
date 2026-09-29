import 'package:flutter/widgets.dart';

import 'mock_data.dart';
import 'models.dart';

/// In-memory app state for the demo. Nothing is persisted.
class AppState extends ChangeNotifier {
  Role? role;
  String email = 'lisa.wang@northstar.co';
  String displayName = '王莉莎';
  String department = '營運管理';
  bool notifyAssigned = true;
  bool weeklyDigest = false;

  final List<Member> members = MockData.members;
  final List<FormItem> forms = MockData.forms();

  bool get isLoggedIn => role != null;
  bool get isAdmin => role == Role.admin;
  String get initials =>
      displayName.length <= 2 ? displayName : displayName.substring(0, 2);

  void login(String email, Role role) {
    this.email = email;
    this.role = role;
    notifyListeners();
  }

  void logout() {
    role = null;
    notifyListeners();
  }

  void switchRole() {
    role = isAdmin ? Role.member : Role.admin;
    notifyListeners();
  }

  void updateProfile({
    required String name,
    required String email,
    required String department,
  }) {
    displayName = name;
    this.email = email;
    this.department = department;
    notifyListeners();
  }

  void setNotifyAssigned(bool v) {
    notifyAssigned = v;
    notifyListeners();
  }

  void setWeeklyDigest(bool v) {
    weeklyDigest = v;
    notifyListeners();
  }

  void addForm(FormItem form) {
    forms.insert(0, form);
    notifyListeners();
  }

  void replaceForm(FormItem old, FormItem updated) {
    final i = forms.indexOf(old);
    i < 0 ? forms.insert(0, updated) : forms[i] = updated;
    notifyListeners();
  }

  void deleteForm(FormItem form) {
    forms.remove(form);
    notifyListeners();
  }

  void submitResponse(FormItem form, Answers answers) {
    final me = Member(displayName, department);
    form.responses.removeWhere((r) => r.member.name == me.name);
    form.responses.add(
      FormResponse(member: me, submittedAt: DateTime.now(), answers: answers),
    );
    if (!form.recipients.any((m) => m.name == me.name)) {
      form.recipients.add(me);
    }
    if (form.respondedCount >= form.totalCount) {
      form.status = FormStatus.completed;
    }
    notifyListeners();
  }
}

/// Exposes [AppState] to the widget tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
