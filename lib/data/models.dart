import 'package:flutter/material.dart';

enum Role { admin, member }

extension RoleLabel on Role {
  String get label => this == Role.admin ? '管理員' : '團隊成員';
}

enum QuestionType {
  /// 簡答：短篇文字，如姓名、電話、電子郵件。
  shortText,

  /// 段落：長篇、開放式意見回饋。
  paragraph,

  /// 選擇題：單選，可加「其他」選項。
  single,

  /// 核取方塊：多選。
  multiple,

  /// 下拉式選單：單選，以下拉選單呈現。
  dropdown,

  /// 日期：年月日。
  date,
}

extension QuestionTypeInfo on QuestionType {
  String get label => switch (this) {
    QuestionType.shortText => '簡答',
    QuestionType.paragraph => '段落',
    QuestionType.single => '選擇題',
    QuestionType.multiple => '核取方塊',
    QuestionType.dropdown => '下拉式選單',
    QuestionType.date => '日期',
  };

  IconData get icon => switch (this) {
    QuestionType.shortText => Icons.short_text,
    QuestionType.paragraph => Icons.notes,
    QuestionType.single => Icons.radio_button_checked,
    QuestionType.multiple => Icons.check_box_outlined,
    QuestionType.dropdown => Icons.arrow_drop_down_circle_outlined,
    QuestionType.date => Icons.event_outlined,
  };

  /// Whether the question needs an option list.
  bool get hasOptions =>
      this == QuestionType.single ||
      this == QuestionType.multiple ||
      this == QuestionType.dropdown;
}

enum FormStatus { draft, pending, completed }

class Member {
  const Member(this.id, this.name, this.department);

  final String id;
  final String name;
  final String department;

  @override
  bool operator ==(Object other) => other is Member && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Two-character avatar label, as shown in the demo ("林郁婷" → "林郁").
  String get initials => name.length <= 2 ? name : name.substring(0, 2);
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.role,
    required this.email,
    required this.displayName,
    required this.department,
    this.notifyAssigned = true,
    this.weeklyDigest = false,
  });

  final String id;

  /// Decided by the backend; users cannot change their own role.
  final Role role;
  final String email;
  final String displayName;
  final String department;
  final bool notifyAssigned;
  final bool weeklyDigest;

  Member get asMember => Member(id, displayName, department);

  UserProfile copyWith({
    String? displayName,
    String? department,
    bool? notifyAssigned,
    bool? weeklyDigest,
  }) => UserProfile(
    id: id,
    role: role,
    email: email,
    displayName: displayName ?? this.displayName,
    department: department ?? this.department,
    notifyAssigned: notifyAssigned ?? this.notifyAssigned,
    weeklyDigest: weeklyDigest ?? this.weeklyDigest,
  );
}

class Question {
  Question({
    this.title = '',
    this.type = QuestionType.single,
    this.required = true,
    List<String>? options,
    this.allowOther = false,
  }) : options = options ?? ['選項一', '選項二'];

  String title;
  QuestionType type;
  bool required;
  List<String> options;

  /// Adds an「其他」option with a free-text field (選擇題 only).
  bool allowOther;

  Question copy() => Question(
    title: title,
    type: type,
    required: required,
    options: [...options],
    allowOther: allowOther,
  );
}

/// The「其他」choice of a 選擇題, with what the respondent typed.
class OtherAnswer {
  const OtherAnswer(this.text);

  final String text;
}

/// Answer value per question type:
/// - 簡答 / 段落 / 下拉式選單 / 日期 (yyyy-MM-dd): `String`
/// - 選擇題: `String`, or [OtherAnswer] when「其他」is chosen
/// - 核取方塊: `Set<String>`
typedef Answers = Map<int, Object>;

class FormResponse {
  const FormResponse({
    required this.member,
    required this.submittedAt,
    required this.answers,
  });

  final Member member;
  final DateTime submittedAt;
  final Answers answers;
}

class FormItem {
  FormItem({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.status,
    required this.questions,
    required this.recipients,
    List<FormResponse>? responses,
  }) : responses = responses ?? [];

  final String id;
  String title;
  String description;
  DateTime deadline;
  FormStatus status;
  List<Question> questions;
  List<Member> recipients;
  final List<FormResponse> responses;

  int get respondedCount => responses.length;
  int get totalCount => recipients.length;
  double get progress => totalCount == 0 ? 0 : respondedCount / totalCount;
  int get percent => (progress * 100).round();
  int get estimatedMinutes => (questions.length * 1.2).ceil().clamp(1, 60);

  bool hasResponded(Member m) => responses.any((r) => r.member == m);
  FormResponse? responseOf(Member m) {
    for (final r in responses) {
      if (r.member == m) return r;
    }
    return null;
  }
}

String formatDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String formatDateTime(DateTime d) =>
    '${formatDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

String _two(int n) => n.toString().padLeft(2, '0');

String formatAnswer(Object? value) {
  if (value == null) return '—';
  if (value is Set<String>) return value.isEmpty ? '—' : value.join('、');
  if (value is OtherAnswer) {
    return value.text.trim().isEmpty ? '其他' : '其他：${value.text.trim()}';
  }
  final s = value.toString();
  return s.isEmpty ? '—' : s;
}
