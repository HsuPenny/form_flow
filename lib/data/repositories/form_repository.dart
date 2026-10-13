import '../models.dart';

/// Source of truth for forms, their responses and the member directory.
abstract interface class FormRepository {
  Future<List<Member>> fetchMembers();

  /// Department names a profile can be assigned to, in display order.
  Future<List<String>> fetchDepartments();

  /// All forms visible to the signed-in user, newest first.
  Future<List<FormItem>> fetchForms();

  /// Inserts [form], or replaces the stored form with the same id.
  Future<FormItem> saveForm(FormItem form);

  Future<void> deleteForm(String formId);

  /// Adds [members] to a published form that is still open, and returns
  /// the updated form. A completed form goes back to pending, since the new
  /// recipients haven't responded yet.
  Future<FormItem> addRecipients(String formId, List<Member> members);

  /// Moves the deadline of a pending form to [deadline] (today or later),
  /// reopening it if the old deadline had passed.
  Future<FormItem> extendDeadline(String formId, DateTime deadline);

  /// Closes a published form for good (結案).
  Future<FormItem> closeForm(String formId);

  /// Records [response], replacing any earlier one from the same member,
  /// and returns the form with its updated responses and status.
  Future<FormItem> submitResponse(String formId, FormResponse response);
}
