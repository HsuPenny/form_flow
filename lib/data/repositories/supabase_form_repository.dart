import 'package:dio/dio.dart';

import '../models.dart';
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
  Future<List<FormItem>> fetchForms() async {
    final res = await _dio.get<List<dynamic>>(
      '/rest/v1/forms',
      queryParameters: {'select': _formColumns, 'order': 'created_at.desc'},
    );
    return [for (final r in res.data!) _formFrom(r as Map<String, dynamic>)];
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
  row['department'] as String,
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
  recipients: [
    for (final r in row['form_recipients'] as List)
      if (r['profiles'] case final Map<String, dynamic> p) _memberFrom(p),
  ],
  responses: [
    for (final r in row['responses'] as List)
      if (r['profiles'] case final Map<String, dynamic> p)
        FormResponse(
          member: _memberFrom(p),
          submittedAt: DateTime.parse(r['submitted_at'] as String).toLocal(),
          answers: _answersFrom(r['answers'] as Map),
        ),
  ],
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
