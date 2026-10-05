import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_form_flow/data/api/api_client.dart';
import 'package:flutter_form_flow/data/models.dart';
import 'package:flutter_form_flow/data/repositories/auth_repository.dart';
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
      case ('POST', '/auth/v1/verify') when body!['type'] == 'recovery':
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
      ('GET', '/rest/v1/forms') => _json([_form]),
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

  static ResponseBody _json(Object data, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json; charset=utf-8'],
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
      forms.fetchForms(),
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
    final profile = await auth.resetPassword(
      email: 'lisa@example.com',
      code: '123456',
      newPassword: 'new-secret',
    );
    expect(profile.displayName, '王莉莎');
    final put = server.requests.firstWhere((r) => r.path == '/auth/v1/user');
    expect(put.method, 'PUT');
    expect(put.data, {'password': 'new-secret'});
    expect(put.headers['Authorization'], 'Bearer access1');
  });

  test('a wrong reset code becomes a readable AuthFailure', () async {
    await expectLater(
      auth.resetPassword(
        email: 'lisa@example.com',
        code: '000000',
        newPassword: 'new-secret',
      ),
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

  test('a rejected new password leaves the user signed out', () async {
    await expectLater(
      auth.resetPassword(
        email: 'lisa@example.com',
        code: '123456',
        newPassword: 'old-password',
      ),
      throwsA(isA<AuthFailure>()),
    );
    expect(api.sessions.current, isNull);
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
    final form = (await forms.fetchForms()).single;

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

  test('saving a form calls the save_form RPC', () async {
    await auth.signIn(email: 'lisa@example.com', password: 'secret');
    final form = (await forms.fetchForms()).single;
    await forms.saveForm(form);

    final rpc = server.requests.firstWhere(
      (r) => r.path == '/rest/v1/rpc/save_form',
    );
    final body = rpc.data as Map<String, dynamic>;
    expect(body['recipient_ids'], ['u2']);
    expect((body['form'] as Map)['deadline'], '2026-10-20');
  });
}
