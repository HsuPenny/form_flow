import '../models.dart';
import '../paged_feed.dart';

/// 表單總覽的分類。每個分類各自向後端分批要資料，不一次抓全部表單。
enum FormCategory {
  /// 還能填、自己還沒回覆的表單，截止日最近的排前面。
  pending,

  /// 自己已經回覆過的表單。
  completed,

  /// 自己沒回覆、也不能再填的表單：已過截止日，或已被管理員結案。
  expired,
}

/// Source of truth for forms, their responses and the member directory.
abstract interface class FormRepository {
  Future<List<Member>> fetchMembers();

  /// Department names a profile can be assigned to, in display order.
  Future<List<String>> fetchDepartments();

  /// All forms visible to the signed-in user, newest first.
  Future<List<FormItem>> fetchForms();

  /// Up to [limit] forms assigned to [memberId] in [kind], skipping the
  /// first [offset]. [FormCategory.pending] comes soonest deadline first,
  /// the others latest deadline first. [query] filters by title.
  Future<PageResult<FormItem>> fetchMyForms({
    required String memberId,
    required FormCategory kind,
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  });

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
