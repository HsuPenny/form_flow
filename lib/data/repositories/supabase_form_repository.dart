import 'package:dio/dio.dart';

import '../models.dart';
import '../paged_feed.dart';
import 'form_repository.dart';

/// [FormRepository] backed by the Supabase tables in `supabase/migrations`,
/// called through PostgREST (`/rest/v1`). RLS decides what each user gets
/// back: admins see every form, members only published forms assigned to
/// them.
class SupabaseFormRepository implements FormRepository {
  SupabaseFormRepository(this._dio);

  /// Must carry the project key and user token; see `SupabaseApi`.
  final Dio _dio;

  /// Asks PostgREST for a single object instead of a one-row array.
  static final _single = Options(
    headers: {'Accept': 'application/vnd.pgrst.object+json'},
  );

  // No spaces: PostgREST's select syntax doesn't allow them.
  // Embeds name their foreign key (Postgres' default constraint names):
  // `responses` references both `forms` and `form_recipients`, which would
  // otherwise make PostgREST's embed paths ambiguous.
  static const _profileColumns = 'id,display_name,department';
  static const _formColumns =
      '*,'
      'form_recipients!form_recipients_form_id_fkey('
      'profiles!form_recipients_member_id_fkey($_profileColumns)),'
      'responses!responses_form_id_fkey(answers,submitted_at,'
      'profiles!responses_member_id_fkey($_profileColumns))';

  @override
  Future<List<Member>> fetchMembers() async {
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/profiles',
      queryParameters: {
        'select': _profileColumns,
        'order': 'department,display_name',
      },
    );
    return [for (final r in res.data!) _memberFrom(r as Map<String, dynamic>)];
  }

  @override
  Future<List<String>> fetchDepartments() async {
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/departments',
      queryParameters: {'select': 'name', 'order': 'sort_order,name'},
    );
    return [for (final r in res.data!) (r as Map)['name'] as String];
  }

  /// Asks PostgREST to count every match, not just the batch; the total
  /// comes back in Content-Range (see [_total]).
  static final _counted = Options(headers: {'Prefer': 'count=exact'});

  /// The total from a [_counted] response: "0-19/57", or "*/0" when nothing
  /// matches. Falls back to what has been loaded so far.
  static int _total(Response<dynamic> res, int loaded) {
    final range = res.headers.value('content-range');
    return int.tryParse(range?.split('/').last ?? '') ?? loaded;
  }

  @override
  Future<List<FormItem>> fetchDrafts() async {
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/forms',
      queryParameters: {
        'select': _formColumns,
        'status': 'eq.draft',
        'order': 'created_at.desc,id.desc',
      },
    );
    return [for (final r in res.data!) _formFrom(r as Map<String, dynamic>)];
  }

  @override
  Future<PageResult<FormItem>> fetchPublishedForms({
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) async {
    final q = query.trim();
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/forms',
      queryParameters: {
        'select': _formColumns,
        'status': 'neq.draft',
        if (q.isNotEmpty) 'title': 'ilike.*$q*',
        // id breaks ties so a batch boundary never repeats or skips a form.
        'order': 'created_at.desc,id.desc',
        'offset': offset,
        'limit': limit,
      },
      options: _counted,
    );
    final items = [
      for (final r in res.data!) _formFrom(r as Map<String, dynamic>),
    ];
    return PageResult(items, _total(res, offset + items.length));
  }

  @override
  Future<PageResult<ResponseEntry>> fetchResponses({
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) async {
    final q = query.trim();
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/responses',
      queryParameters: {
        // Just the form's own columns: its other replies aren't needed here.
        // Inner join, so the title filter drops replies to other forms.
        'select':
            'answers,submitted_at,'
            'profiles!responses_member_id_fkey($_profileColumns),'
            'forms!responses_form_id_fkey!inner('
            'id,title,description,deadline,status,questions)',
        if (q.isNotEmpty) 'forms.title': 'ilike.*$q*',
        'order': 'submitted_at.desc,id.desc',
        'offset': offset,
        'limit': limit,
      },
      options: _counted,
    );
    final rows = res.data!.cast<Map<String, dynamic>>();
    final items = [
      for (final r in rows)
        // A profile hidden by RLS (null) can't be shown.
        if (r['profiles'] case final Map<String, dynamic> p)
          ResponseEntry(
            form: _formFrom(r['forms'] as Map<String, dynamic>),
            response: _responseFrom(r, _memberFrom(p)),
          ),
    ];
    return PageResult(items, _total(res, offset + rows.length));
  }

  @override
  Future<ProgressSummary> fetchProgressSummary() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/rest/v1/rpc/progress_summary',
      options: _single,
    );
    final row = res.data!;
    return ProgressSummary(
      recipients: (row['recipients'] as num).toInt(),
      responded: (row['responded'] as num).toInt(),
    );
  }

  @override
  Future<PageResult<FormItem>> fetchMyForms({
    required String memberId,
    required FormCategory kind,
    String query = '',
    int offset = 0,
    int limit = PageResult.size,
  }) async {
    // Extra aliased embeds only filter: `mine` keeps forms assigned to the
    // member (admins can see every form), `answered` is their own response.
    final answered = kind == FormCategory.completed
        ? 'answered:responses!responses_form_id_fkey!inner(member_id)'
        : 'answered:responses!responses_form_id_fkey(member_id)';
    final q = query.trim();
    // Same rule as form_is_open: replies are taken through the end of the
    // deadline day.
    final today = formatDate(DateTime.now());
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/forms',
      queryParameters: {
        'select':
            '$_formColumns,'
            'mine:form_recipients!form_recipients_form_id_fkey!inner(member_id),'
            '$answered',
        'mine.member_id': 'eq.$memberId',
        'answered.member_id': 'eq.$memberId',
        if (kind == FormCategory.pending) ...{
          'answered': 'is.null',
          'status': 'in.(pending,completed)',
          'deadline': 'gte.$today',
        },
        if (kind == FormCategory.expired) ...{
          'answered': 'is.null',
          'status': 'neq.draft',
          'or': '(status.eq.closed,deadline.lt.$today)',
        },
        if (q.isNotEmpty) 'title': 'ilike.*$q*',
        'order': kind == FormCategory.pending
            ? 'deadline.asc,id.asc'
            : 'deadline.desc,id.desc',
        'offset': offset,
        'limit': limit,
      },
      options: _counted,
    );
    final items = [
      for (final r in res.data!) _formFrom(r as Map<String, dynamic>),
    ];
    return PageResult(items, _total(res, offset + items.length));
  }

  @override
  Future<FormItem> saveForm(FormItem form) async {
    await _dio.post<void>(
      '/rest/v1/rpc/save_form',
      data: {
        'form': {
          'id': form.id,
          'title': form.title,
          'description': form.description,
          'deadline': formatDate(form.deadline),
          'status': form.status.name,
          'questions': [for (final q in form.questions) _questionToJson(q)],
        },
        'recipient_ids': [for (final m in form.recipients) m.id],
      },
    );
    return _fetchForm(form.id);
  }

  @override
  Future<void> deleteForm(String formId) => _dio.delete<void>(
    '/rest/v1/forms',
    queryParameters: {'id': 'eq.$formId'},
  );

  @override
  Future<FormItem> addRecipients(String formId, List<Member> members) async {
    await _dio.post<void>(
      '/rest/v1/rpc/add_recipients',
      data: {
        'form_id': formId,
        'member_ids': [for (final m in members) m.id],
      },
    );
    return _fetchForm(formId);
  }

  @override
  Future<FormItem> extendDeadline(String formId, DateTime deadline) async {
    await _dio.post<void>(
      '/rest/v1/rpc/extend_deadline',
      data: {'form_id': formId, 'new_deadline': formatDate(deadline)},
    );
    return _fetchForm(formId);
  }

  @override
  Future<FormItem> closeForm(String formId) async {
    await _dio.post<void>('/rest/v1/rpc/close_form', data: {'form_id': formId});
    return _fetchForm(formId);
  }

  @override
  Future<FormItem> submitResponse(String formId, FormResponse response) async {
    await _dio.post<void>(
      '/rest/v1/responses',
      queryParameters: {'on_conflict': 'form_id,member_id'},
      data: {
        'form_id': formId,
        'member_id': response.member.id,
        'answers': _answersToJson(response.answers),
      },
      // Upsert: replace this member's earlier response.
      options: Options(headers: {'Prefer': 'resolution=merge-duplicates'}),
    );
    return _fetchForm(formId);
  }

  Future<FormItem> _fetchForm(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/rest/v1/forms',
      queryParameters: {'select': _formColumns, 'id': 'eq.$id'},
      options: _single,
    );
    return _formFrom(res.data!);
  }
}

// ─── Row ⇄ model mapping ─────────────────────────────────────────────────────

Member _memberFrom(Map<String, dynamic> row) => Member(
  row['id'] as String,
  row['display_name'] as String,
  // Null means no department.
  row['department'] as String? ?? '',
);

FormItem _formFrom(Map<String, dynamic> row) => FormItem(
  id: row['id'] as String,
  title: row['title'] as String,
  description: row['description'] as String,
  deadline: DateTime.parse(row['deadline'] as String),
  status: FormStatus.values.byName(row['status'] as String),
  questions: [
    for (final q in row['questions'] as List) _questionFrom(q as Map),
  ],
  // An embedded profile is null when RLS hides it from the current user.
  // Both lists are missing when only the form's own columns were selected.
  recipients: [
    for (final r in row['form_recipients'] as List? ?? const [])
      if (r['profiles'] case final Map<String, dynamic> p) _memberFrom(p),
  ],
  responses: [
    for (final r in row['responses'] as List? ?? const [])
      if (r['profiles'] case final Map<String, dynamic> p)
        _responseFrom(r as Map, _memberFrom(p)),
  ],
);

FormResponse _responseFrom(Map row, Member member) => FormResponse(
  member: member,
  submittedAt: DateTime.parse(row['submitted_at'] as String).toLocal(),
  answers: _answersFrom(row['answers'] as Map),
);

Map<String, Object> _questionToJson(Question q) => {
  'title': q.title,
  'type': q.type.name,
  'required': q.required,
  'options': q.options,
  'allowOther': q.allowOther,
};

Question _questionFrom(Map q) => Question(
  title: q['title'] as String? ?? '',
  type: QuestionType.values.byName(q['type'] as String),
  required: q['required'] as bool? ?? true,
  options: [...?(q['options'] as List?)?.cast<String>()],
  allowOther: q['allowOther'] as bool? ?? false,
);

/// See the `responses.answers` shape documented in the migration.
Map<String, Object> _answersToJson(Answers answers) => {
  for (final MapEntry(:key, :value) in answers.entries)
    '$key': switch (value) {
      Set<String> s => s.toList(),
      OtherAnswer o => {'other': o.text},
      _ => value.toString(),
    },
};

Answers _answersFrom(Map json) => {
  for (final MapEntry(:key, :value) in json.entries)
    int.parse(key as String): switch (value) {
      List l => l.cast<String>().toSet(),
      Map m => OtherAnswer(m['other'] as String? ?? ''),
      _ => value.toString(),
    },
};
