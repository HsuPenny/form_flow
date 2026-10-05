import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens from Supabase Auth (`/auth/v1/token`, `/auth/v1/signup`).
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
  });

  factory AuthSession.fromAuthResponse(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final expiresAt = json['expires_at'] as int?;
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
          : DateTime.now().add(Duration(seconds: json['expires_in'] as int)),
      userId: user['id'] as String,
      email: user['email'] as String? ?? '',
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    userId: json['userId'] as String,
    email: json['email'] as String,
  );

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String email;

  /// Refresh a little early so a token doesn't expire mid-request.
  bool get expiresSoon =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toIso8601String(),
    'userId': userId,
    'email': email,
  };
}

/// Holds the current [AuthSession], keeps it in secure storage across
/// launches, and refreshes it before it expires.
class SessionManager {
  SessionManager({
    required Dio authClient,
    required FlutterSecureStorage storage,
  }) : _authClient = authClient,
       _storage = storage;

  static const _storageKey = 'supabase_session';

  /// Plain client without the auth interceptor, so refreshing can't recurse.
  final Dio _authClient;
  final FlutterSecureStorage _storage;

  AuthSession? _session;
  Future<AuthSession?>? _refreshing;

  AuthSession? get current => _session;

  /// Loads the session saved by a previous launch, if any.
  Future<void> restore() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return;
    try {
      _session = AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
    }
  }

  Future<void> save(AuthSession session) async {
    _session = session;
    await _storage.write(key: _storageKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    _session = null;
    await _storage.delete(key: _storageKey);
  }

  /// A usable access token, refreshing first if it's about to expire.
  /// Null when signed out.
  Future<String?> accessToken() async {
    final session = _session;
    if (session == null) return null;
    if (!session.expiresSoon) return session.accessToken;
    return (await refresh())?.accessToken;
  }

  /// Exchanges the refresh token for a new session. Concurrent callers share
  /// one request: Supabase rotates refresh tokens, so a second request with
  /// the old one could be rejected.
  ///
  /// Returns null (and signs out) when the server rejects the refresh token;
  /// network errors are rethrown and keep the session for a later retry.
  Future<AuthSession?> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<AuthSession?> _refresh() async {
    final session = _session;
    if (session == null) return null;
    try {
      final res = await _authClient.post<Map<String, dynamic>>(
        '/auth/v1/token',
        queryParameters: {'grant_type': 'refresh_token'},
        data: {'refresh_token': session.refreshToken},
      );
      final next = AuthSession.fromAuthResponse(res.data!);
      await save(next);
      return next;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 401) {
        await clear();
        return null;
      }
      rethrow;
    }
  }
}
