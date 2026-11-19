import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_form_flow/data/api/api_client.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/paged_feed.dart';
import 'package:flutter_form_flow/data/repositories/auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/form_repository.dart';
import 'package:flutter_form_flow/data/repositories/supabase_auth_repository.dart';
import 'package:flutter_form_flow/data/repositories/supabase_form_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Just enough of Supabase's Auth + PostgREST endpoints to exercise the
/// client: one user, token refresh, and one form.
class FakeSupabase implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final revokedTokens = <String>{};
  var refreshCalls = 0;
  var logoutFails = false;
  var _tokenCount = 1;

  static const userId = 'u1';

  Map<String, dynamic> _session() {
    final n = _tokenCount++;
    return {
      'access_token': 'access$n',
      'refresh_token': 'refresh$n',
      'expires_in': 3600,
      'user': {'id': userId, 'email': 'lisa@example.com'},
    };
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final q = options.queryParameters;
    final body = options.data as Map<String, dynamic>?;
    final auth = options.headers['Authorization'] as String?;

    if (options.headers['apikey'] != 'test-key') {
      return _json({'message': 'No API key'}, 401);
    }
    switch ((options.method, options.path)) {
      case ('POST', '/auth/v1/token') when q['grant_type'] == 'password':
        return body!['password'] == 'secret'
            ? _json(_session())
            : _json({
                'error_code': 'invalid_credentials',
                'msg': 'Invalid login credentials',
              }, 400);
      case ('POST', '/auth/v1/token') when q['grant_type'] == 'refresh_token':
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _json(_session());
      case ('POST', '/auth/v1/recover'):
        return body!['email'] == 'bad'
            ? _json({
                'error_code': 'validation_failed',
                'msg': 'Unable to validate email address',
              }, 400)
            : _json({});
      case ('POST', '/auth/v1/signup'):
        // As with "Confirm email" on: just the user, no session.
        return _json({'id': userId, 'email': body!['email']});
      case ('POST', '/auth/v1/resend'):
        return _json({});
      case ('POST', '/auth/v1/verify')
          when body!['type'] == 'recovery' || body['type'] == 'signup':
        return body['token'] == '123456'
            ? _json(_session())
            : _json({
                'error_code': 'otp_expired',
                'msg': 'Token has expired or is invalid',
              }, 403);
      case ('PUT', '/auth/v1/user'):
        if (auth == null) return _json({'msg': 'no session'}, 401);
        return body!['password'] == 'old-password'
            ? _json({
                'error_code': 'same_password',
                'msg': 'New password should be different',
              }, 422)
            : _json({'id': userId, 'email': 'lisa@example.com'});
      case ('POST', '/auth/v1/logout'):
        return logoutFails
            ? _json({'msg': 'down'}, 500)
            : ResponseBody.fromString('', 204);
    }

    if (auth == null || revokedTokens.contains(auth.substring(7))) {
      return _json({'code': 'PGRST301', 'message': 'JWT expired'}, 401);
    }
    final single =
        options.headers['Accept'] == 'application/vnd.pgrst.object+json';
    return switch ((options.method, options.path)) {
      ('GET', '/rest/v1/profiles') when single => _json(_profile),
      ('GET', '/rest/v1/profiles') => _json([_profile]),
      ('PATCH', '/rest/v1/profiles') => _json({..._profile, ...?body}),
      ('GET', '/rest/v1/departments') => _json([
        {'name': '營運管理'},
        {'name': '工程部'},
      ]),
      ('GET', '/rest/v1/forms') when single => _json(_form),
      // A batch of a longer list: total in Content-Range.
      ('GET', '/rest/v1/forms')
          when options.headers['Prefer'] == 'count=exact' =>
        _json(
          [_form],
          200,
          {
            'content-range': ['20-20/31'],
          },
        ),
      ('GET', '/rest/v1/forms') => _json([_form]),
      ('GET', '/rest/v1/responses') => _json(
        [_responseRow],
        200,
        {
          'content-range': ['0-0/45'],
        },
      ),
      ('POST', '/rest/v1/rpc/progress_summary') when single => _json({
        'recipients': 12,
        'responded': 5,
      }),
      ('POST', '/rest/v1/rpc/save_form') => ResponseBody.fromString('', 204),
      _ => _json({
        'message': 'unexpected ${options.method} ${options.path}',
      }, 404),
    };
  }

  static const _profile = {
    'id': userId,
    'display_name': '王莉莎',
    'department': '營運管理',
    'role': 'admin',
    'notify_assigned': true,
    'weekly_digest': false,
  };

  static const _form = {
    'id': 'f1',
    'title': '工作坊回饋',
    'description': '',
    'deadline': '2026-10-20',
    'status': 'pending',
    'questions': [
      {
        'title': '節奏如何？',
        'type': 'single',
        'required': true,
        'options': ['好', '普通'],
        'allowOther': true,
      },
      {
        'title': '想加什麼？',
        'type': 'multiple',
        'required': false,
        'options': ['實作', '案例'],
        'allowOther': false,
      },
    ],
    'form_recipients': [
      {
        'profiles': {'id': 'u2', 'display_name': '林郁婷', 'department': '產品設計'},
      },
      {'profiles': null},
    ],
    'responses': [
      {
        'answers': {
          '0': {'other': '再慢一點'},
          '1': ['實作', '案例'],
        },
        'submitted_at': '2026-09-28T02:00:00+00:00',
        'profiles': {'id': 'u2', 'display_name': '林郁婷', 'department': '產品設計'},
      },
    ],
  };

  /// A row of `/rest/v1/responses` as 最新回覆 selects it: the form comes
  /// with its own columns only.
  static const _responseRow = {
    'answers': {'0': '好'},
    'submitted_at': '2026-09-28T02:00:00+00:00',
    'profiles': {'id': 'u2', 'display_name': '林郁婷', 'department': '產品設計'},
    'forms': {
      'id': 'f1',
      'title': '工作坊回饋',
      'description': '',
      'deadline': '2026-10-20',
      'status': 'pending',
      'questions': [],
    },
  };

  static ResponseBody _json(
    Object data, [
    int status = 200,
    Map<String, List<String>> headers = const {},
  ]) => ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      ...headers,
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeSupabase server;
  late SupabaseApi api;
  late SupabaseAuthRepository auth;
  late SupabaseFormRepository forms;

  SupabaseApi newApi() => SupabaseApi(
    url: 'https://test.supabase.co',
    key: 'test-key',
    adapter: server,
  );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    server = FakeSupabase();
    api = newApi();
    auth = SupabaseAuthRepository(api);
    forms = SupabaseFormRepository(api.dio);
  });

  test('wrong password becomes a readable AuthFailure', () async {
    await expectLater(
      auth.signIn(email: 'lisa@example.com', password: 'nope'),
      throwsA(
        isA<AuthFailure>().having((e) => e.message, 'message', '信箱或密碼錯誤'),
      ),
    );
    expect(api.sessions.current, isNull);
  });

  test('sign in stores the session and signs later requests', () async {
    final profile = await auth.signIn(
      email: 'lisa@example.com',
      password: 'secret',
    );
    expect(profile.role, Role.admin);
    expect(profile.email, 'lisa@example.com');
    expect(server.requests.last.headers['Authorization'], 'Bearer access1');
    expect(server.requests.last.queryParameters['id'], 'eq.u1');
  });

  test('a restarted app restores the saved session', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final restarted = SupabaseAuthRepository(newApi());
    final profile = await restarted.currentUser();
    expect(profile?.displayName, '王莉莎');
  });

  test('a 401 refreshes once and retries concurrent requests', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    server.revokedTokens.add('access1');

    final results = await Future.wait([
      forms.fetchDrafts(),
      forms.fetchMembers(),
    ]);
    expect(results, everyElement(hasLength(1)));
    expect(server.refreshCalls, 1);
    expect(server.requests.last.headers['Authorization'], 'Bearer access2');
  });

  test('password reset posts the email to /recover', () async {
    await auth.sendPasswordReset(email: 'lisa@example.com');
    final req = server.requests.last;
    expect(req.path, '/auth/v1/recover');
    expect(req.data, {'email': 'lisa@example.com'});

    await expectLater(
      auth.sendPasswordReset(email: 'bad'),
      throwsA(
        isA<AuthFailure>().having((e) => e.message, 'message', '信箱格式不正確'),
      ),
    );
  });

  test('reset password verifies the code, then sets the password', () async {
    await auth.verifyRecoveryCode(email: 'lisa@example.com', code: '123456');
    final verify = server.requests.last;
    expect(verify.path, '/auth/v1/verify');
    expect(verify.data, {
      'type': 'recovery',
      'email': 'lisa@example.com',
      'token': '123456',
    });

    final profile = await auth.resetPassword(newPassword: 'new-secret');
    expect(profile.displayName, '王莉莎');
    final put = server.requests.firstWhere((r) => r.path == '/auth/v1/user');
    expect(put.method, 'PUT');
    expect(put.data, {'password': 'new-secret'});
    expect(put.headers['Authorization'], 'Bearer access1');
  });

  test('a wrong reset code becomes a readable AuthFailure', () async {
    await expectLater(
      auth.verifyRecoveryCode(email: 'lisa@example.com', code: '000000'),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          '驗證碼錯誤或已過期，請重新寄送',
        ),
      ),
    );
    expect(api.sessions.current, isNull);
  });

  test('a rejected new password can be retried or cancelled', () async {
    await auth.verifyRecoveryCode(email: 'lisa@example.com', code: '123456');
    await expectLater(
      auth.resetPassword(newPassword: 'old-password'),
      throwsA(isA<AuthFailure>()),
    );
    // Still allowed to try another password.
    expect(api.sessions.current, isNotNull);

    await auth.cancelPasswordReset();
    expect(api.sessions.current, isNull);
  });

  test('sign-up waits for the emailed code', () async {
    final profile = await auth.signUp(
      email: 'new@example.com',
      password: 'secret',
      displayName: '新同事',
    );
    expect(profile, isNull);
    expect(api.sessions.current, isNull);

    await auth.resendSignUpCode(email: 'new@example.com');
    expect(server.requests.last.path, '/auth/v1/resend');
    expect(server.requests.last.data, {
      'type': 'signup',
      'email': 'new@example.com',
    });

    await expectLater(
      auth.verifySignUp(email: 'new@example.com', code: '000000'),
      throwsA(isA<AuthFailure>()),
    );
    final signedIn = await auth.verifySignUp(
      email: 'new@example.com',
      code: '123456',
    );
    expect(signedIn.displayName, '王莉莎');
    expect(server.requests.last.path, '/rest/v1/profiles');
  });

  test('change password checks the current one first', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    await expectLater(
      auth.changePassword(currentPassword: 'nope', newPassword: 'new-secret'),
      throwsA(
        isA<AuthFailure>().having((e) => e.message, 'message', '目前的密碼不正確'),
      ),
    );
    expect(server.requests.where((r) => r.path == '/auth/v1/user'), isEmpty);
    // Still signed in with the original session.
    expect(api.sessions.current?.accessToken, 'access1');

    await auth.changePassword(
      currentPassword: 'secret',
      newPassword: 'new-secret',
    );
    final put = server.requests.last;
    expect((put.method, put.path), ('PUT', '/auth/v1/user'));
    expect(put.data, {'password': 'new-secret'});
    expect(put.headers['Authorization'], 'Bearer access2');
  });

  test('departments come back in order', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    expect(await forms.fetchDepartments(), ['營運管理', '工程部']);
    expect(server.requests.last.queryParameters['order'], 'sort_order,name');
  });

  test('an empty department is saved as null', () async {
    final profile = await auth.signIn(
      email: 'lisa@example.com',
      password: 'secret',
    );
    await expectLater(
      auth.updateProfile(profile.copyWith(department: '')),
      completes,
    );
    final patch = server.requests.last;
    expect((patch.data as Map)['department'], isNull);
  });

  test('sign out clears the session even if the server call fails', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    server.logoutFails = true;
    await auth.signOut();
    expect(api.sessions.current, isNull);
    expect(await SupabaseAuthRepository(newApi()).currentUser(), isNull);
  });

  test('form rows map to models', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final form = (await forms.fetchDrafts()).single;

    expect(form.deadline, DateTime(2026, 10, 20));
    expect(form.status, FormStatus.pending);
    expect(form.questions.first.allowOther, isTrue);
    expect(form.questions.last.type, QuestionType.multiple);
    // The profile hidden by RLS (null) is skipped.
    expect(form.recipients.map((m) => m.name), ['林郁婷']);
    final answers = form.responses.single.answers;
    expect(formatAnswer(answers[0]), '其他：再慢一點');
    expect(answers[1], {'實作', '案例'});

    final select = server.requests.last.queryParameters['select'] as String;
    expect(select, isNot(contains(' ')));
  });

  test('expired history asks for unanswered, ended forms in batches', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final page = await forms.fetchMyForms(
      memberId: 'u1',
      kind: FormCategory.expired,
      query: ' 回饋 ',
      offset: 20,
    );

    expect(page.items.single.title, '工作坊回饋');
    expect(page.total, 31);
    final q = server.requests.last.queryParameters;
    expect(q['mine.member_id'], 'eq.u1');
    expect(q['answered.member_id'], 'eq.u1');
    expect(q['answered'], 'is.null');
    expect(q['status'], 'neq.draft');
    expect(q['or'], startsWith('(status.eq.closed,deadline.lt.'));
    expect(q['title'], 'ilike.*回饋*');
    expect(q['offset'], 20);
    expect(q['limit'], PageResult.size);
    expect(q['select'], isNot(contains(' ')));
    // Left join, so forms without the member's response stay in.
    expect(
      q['select'],
      endsWith('answered:responses!responses_form_id_fkey(member_id)'),
    );
  });

  test('pending asks for open, unanswered forms, soonest first', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    await forms.fetchMyForms(
      memberId: 'u1',
      kind: FormCategory.pending,
      limit: 1,
    );

    final q = server.requests.last.queryParameters;
    expect(q['answered'], 'is.null');
    expect(q['status'], 'in.(pending,completed)');
    expect(q['deadline'], startsWith('gte.'));
    expect(q['order'], 'deadline.asc,id.asc');
    expect(q['limit'], 1);
    expect(q.containsKey('or'), isFalse);
  });

  test('completed history requires the member\'s own response', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    await forms.fetchMyForms(memberId: 'u1', kind: FormCategory.completed);

    final q = server.requests.last.queryParameters;
    expect(
      q['select'],
      endsWith('responses!responses_form_id_fkey!inner(member_id)'),
    );
    expect(q.containsKey('answered'), isFalse);
    expect(q.containsKey('or'), isFalse);
    expect(q.containsKey('title'), isFalse);
  });

  test('drafts come in one go, newest first', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    await forms.fetchDrafts();

    final q = server.requests.last.queryParameters;
    expect(q['status'], 'eq.draft');
    expect(q['order'], 'created_at.desc,id.desc');
    expect(q.containsKey('limit'), isFalse);
  });

  test('完成進度 asks for published forms in batches, newest first', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final page = await forms.fetchPublishedForms(query: ' 回饋 ', offset: 20);

    expect(page.items.single.title, '工作坊回饋');
    expect(page.total, 31);
    final req = server.requests.last;
    expect(req.headers['Prefer'], 'count=exact');
    final q = req.queryParameters;
    expect(q['status'], 'neq.draft');
    expect(q['title'], 'ilike.*回饋*');
    expect(q['order'], 'created_at.desc,id.desc');
    expect(q['offset'], 20);
    expect(q['limit'], PageResult.size);
  });

  test('完成進度 without a search sends no title filter', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    await forms.fetchPublishedForms(query: '  ', limit: 5);

    final q = server.requests.last.queryParameters;
    expect(q.containsKey('title'), isFalse);
    expect(q['offset'], 0);
    expect(q['limit'], 5);
  });

  test('最新回覆 pages through every reply, newest first', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final page = await forms.fetchResponses(query: ' 回饋 ', offset: 40);

    expect(page.total, 45);
    final entry = page.items.single;
    expect(entry.form.title, '工作坊回饋');
    expect(entry.form.responses, isEmpty);
    expect(entry.response.member.name, '林郁婷');
    expect(entry.response.answers[0], '好');

    final req = server.requests.last;
    expect(req.path, '/rest/v1/responses');
    expect(req.headers['Prefer'], 'count=exact');
    final q = req.queryParameters;
    expect(q['order'], 'submitted_at.desc,id.desc');
    expect(q['offset'], 40);
    expect(q['limit'], PageResult.size);
    // Searched by form title on the server, through an inner join.
    expect(q['forms.title'], 'ilike.*回饋*');
    expect(q['select'], contains('forms!responses_form_id_fkey!inner('));
    expect(q['select'], isNot(contains(' ')));
  });

  test('最新回覆 without a search sends no title filter', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    await forms.fetchResponses();

    final q = server.requests.last.queryParameters;
    expect(q.containsKey('forms.title'), isFalse);
    expect(q['offset'], 0);
  });

  test('the totals come from the progress_summary RPC', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final summary = await forms.fetchProgressSummary();

    expect(summary.recipients, 12);
    expect(summary.responded, 5);
    expect(summary.waiting, 7);
    expect(summary.percent, 42);
    expect(server.requests.last.method, 'POST');
  });

  test('saving a form calls the save_form RPC', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final form = (await forms.fetchDrafts()).single;
    await forms.saveForm(form);

    final rpc = server.requests.firstWhere(
      (r) => r.path == '/rest/v1/rpc/save_form',
    );
    final body = rpc.data as Map<String, dynamic>;
    expect(body['recipient_ids'], ['u2']);
    expect((body['form'] as Map)['deadline'], '2026-10-20');
  });
}
