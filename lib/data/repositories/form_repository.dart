import '../models.dart';

/// Source of truth for forms, their responses and the member directory.
abstract interface class FormRepository {
  Future<List<Member>> fetchMembers();

  /// All forms visible to the signed-in user, newest first.
  Future<List<FormItem>> fetchForms();

  /// Inserts [form], or replaces the stored form with the same id.
  Future<FormItem> saveForm(FormItem form);

  Future<void> deleteForm(String formId);

  /// Records [response], replacing any earlier one from the same member,
  /// and returns the form with its updated responses and status.
  Future<FormItem> submitResponse(String formId, FormResponse response);
}
