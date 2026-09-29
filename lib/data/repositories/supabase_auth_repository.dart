import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/auth_session.dart';
import '../models.dart';
import 'auth_repository.dart';

/// Email + password auth against Supabase Auth's REST API, with the profile
/// from the `profiles` table.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._api);

  final SupabaseApi _api;

  Dio get _dio => _api.dio;
  SessionManager get _sessions => _api.sessions;

  /// Asks PostgREST for a single object instead of a one-row array.
  static final _single = Options(
    headers: {'Accept': 'application/vnd.pgrst.object+json'},
  );

  @override
  Future<UserProfile?> currentUser() async {
    await _sessions.restore();
    // Refreshes an expired token; null if the server has ended the session.
    if (await _sessions.accessToken() == null) return null;
    return _fetchProfile();
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _authCall(
      () => _dio.post(
        '/auth/v1/token',
        queryParameters: {'grant_type': 'password'},
        data: {'email': email, 'password': password},
      ),
    );
    return _start(json);
  }

  @override
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final json = await _authCall(
      () => _dio.post(
        '/auth/v1/signup',
        data: {
          'email': email,
          'password': password,
          // Read by the handle_new_user trigger to fill profiles.display_name.
          'data': {'display_name': displayName},
        },
      ),
    );
    // Only the user comes back when "Confirm email" is on in the project.
    if (json['access_token'] == null) {
      throw const AuthFailure('註冊成功！請先到信箱點擊確認連結，再回來登入');
    }
    return _start(json);
  }

  /// Always signs out locally, even if the server can't be reached.
  @override
  Future<void> signOut() async {
    try {
      await _dio.post('/auth/v1/logout');
    } on DioException catch (e) {
      debugPrint('Server sign-out failed: $e');
    } finally {
      await _sessions.clear();
    }
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/rest/v1/profiles',
      queryParameters: {'id': 'eq.${profile.id}'},
      data: {
        'display_name': profile.displayName,
        'department': profile.department,
        'notify_assigned': profile.notifyAssigned,
        'weekly_digest': profile.weeklyDigest,
      },
      options: _single.copyWith(
        headers: {..._single.headers!, 'Prefer': 'return=representation'},
      ),
    );
    return _profileFrom(res.data!, profile.email);
  }

  Future<UserProfile> _start(Map<String, dynamic> authResponse) async {
    await _sessions.save(AuthSession.fromAuthResponse(authResponse));
    return _fetchProfile();
  }

  Future<UserProfile> _fetchProfile() async {
    final session = _sessions.current!;
    final res = await _dio.get<Map<String, dynamic>>(
      '/rest/v1/profiles',
      queryParameters: {'select': '*', 'id': 'eq.${session.userId}'},
      options: _single,
    );
    return _profileFrom(res.data!, session.email);
  }

  static UserProfile _profileFrom(Map<String, dynamic> row, String email) =>
      UserProfile(
        id: row['id'] as String,
        role: Role.values.byName(row['role'] as String),
        email: email,
        displayName: row['display_name'] as String,
        department: row['department'] as String,
        notifyAssigned: row['notify_assigned'] as bool,
        weeklyDigest: row['weekly_digest'] as bool,
      );

  /// Runs an Auth API call, turning its errors into [AuthFailure]s.
  static Future<Map<String, dynamic>> _authCall(
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      return (await call()).data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// Supabase Auth errors look like `{"error_code": "...", "msg": "..."}`;
  /// older servers send `{"error": "...", "error_description": "..."}`.
  static AuthFailure _failure(DioException e) {
    final body = e.response?.data;
    if (body is! Map) return const AuthFailure('無法連線，請檢查網路後再試');
    final code = body['error_code'] ?? body['error'];
    final message = body['msg'] ?? body['error_description'] ?? body['message'];
    return AuthFailure(switch (code) {
      'invalid_credentials' || 'invalid_grant' => '信箱或密碼錯誤',
      'email_not_confirmed' => '這個信箱還沒完成驗證，請先到信箱點擊確認連結',
      'user_already_exists' || 'email_exists' => '這個信箱已經註冊過，請直接登入',
      'weak_password' => '密碼強度不足，至少需要 6 個字元',
      'email_address_invalid' || 'validation_failed' => '信箱格式不正確',
      'over_request_rate_limit' ||
      'over_email_send_rate_limit' => '嘗試次數太多，請稍後再試',
      _ => message is String ? message : '登入失敗，請稍後再試',
    });
  }
}
