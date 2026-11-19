import '../mock_data.dart';
import '../models.dart';
import '../paged_feed.dart';
import 'form_repository.dart';

/// In-memory [FormRepository] seeded from [MockData]. Nothing is persisted.
class MockFormRepository implements FormRepository {
  final List<FormItem> _forms = MockData.forms();

  @override
  Future<List<Member>> fetchMembers() async => [...MockData.members];

  @override
  Future<List<String>> fetchDepartments() async => [...MockData.departments];

  @override
  Future<List<FormItem>> fetchForms() async => [..._forms];

  @override
  Future<PageResult<FormItem>> fetchMyForms({
    required String memberId,
    required FormCategory kind,
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) async {
    final matches =
        _forms.where((f) {
          final me = f.recipients.where((m) => m.id == memberId).firstOrNull;
          if (me == null || !f.title.contains(query.trim())) return false;
          return switch (kind) {
            FormCategory.pending => f.isOpen && !f.hasResponded(me),
            FormCategory.completed => f.hasResponded(me),
            FormCategory.expired => f.isExpiredFor(me),
          };
        }).toList()..sort(
          (a, b) => kind == FormCategory.pending
              ? a.deadline.compareTo(b.deadline)
              : b.deadline.compareTo(a.deadline),
        );
    return PageResult(
      matches.skip(offset).take(limit).toList(),
      matches.length,
    );
  }

  @override
  Future<FormItem> saveForm(FormItem form) async {
    final i = _forms.indexWhere((f) => f.id == form.id);
    i < 0 ? _forms.insert(0, form) : _forms[i] = form;
    return form;
  }

  @override
  Future<void> deleteForm(String formId) async {
    _forms.removeWhere((f) => f.id == formId);
  }

  @override
  Future<FormItem> addRecipients(String formId, List<Member> members) async {
    final form = _forms.firstWhere((f) => f.id == formId);
    if (!form.isOpen) throw StateError('Form $formId is not open');
    form.recipients.addAll(members.where((m) => !form.recipients.contains(m)));
    if (form.respondedCount < form.totalCount) {
      form.status = FormStatus.pending;
    }
    return form;
  }

  @override
  Future<FormItem> extendDeadline(String formId, DateTime deadline) async {
    final form = _forms.firstWhere((f) => f.id == formId);
    final now = DateTime.now();
    if (!form.canExtendDeadline ||
        deadline.isBefore(DateTime(now.year, now.month, now.day))) {
      throw StateError('Cannot move form $formId to $deadline');
    }
    form.deadline = deadline;
    return form;
  }

  @override
  Future<FormItem> closeForm(String formId) async {
    final form = _forms.firstWhere((f) => f.id == formId);
    if (!form.isPublished) throw StateError('Form $formId is not published');
    form.status = FormStatus.closed;
    return form;
  }

  @override
  Future<FormItem> submitResponse(String formId, FormResponse response) async {
    final form = _forms.firstWhere((f) => f.id == formId);
    final me = response.member;
    form.responses
      ..removeWhere((r) => r.member == me)
      ..add(response);
    if (!form.recipients.contains(me)) {
      form.recipients.add(me);
    }
    if (form.status == FormStatus.pending &&
        form.respondedCount >= form.totalCount) {
      form.status = FormStatus.completed;
    }
    return form;
  }
}
