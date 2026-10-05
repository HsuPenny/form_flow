import '../mock_data.dart';
import '../models.dart';
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
  Future<FormItem> submitResponse(String formId, FormResponse response) async {
    final form = _forms.firstWhere((f) => f.id == formId);
    final me = response.member;
    form.responses
      ..removeWhere((r) => r.member == me)
      ..add(response);
    if (!form.recipients.contains(me)) {
      form.recipients.add(me);
    }
    if (form.respondedCount >= form.totalCount) {
      form.status = FormStatus.completed;
    }
    return form;
  }
}
