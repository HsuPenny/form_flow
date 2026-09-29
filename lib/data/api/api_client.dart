import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_interceptor.dart';
import 'auth_session.dart';

/// Dio set up for a Supabase project's REST endpoints (`/auth/v1`,
/// `/rest/v1`): the project key on every request, plus the user's token
/// once signed in.
class SupabaseApi {
  SupabaseApi({
    required String url,
    required String key,
    FlutterSecureStorage storage = const FlutterSecureStorage(
      // The legacy keychain avoids needing Keychain Sharing entitlements and
      // a provisioning profile on macOS. Ignored on other platforms.
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),

    /// Replaces the HTTP transport, e.g. with a fake one in tests.
    HttpClientAdapter? adapter,
  }) {
    final options = BaseOptions(
      baseUrl: url,
      headers: {'apikey': key},
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    );
    final authClient = Dio(options);
    sessions = SessionManager(authClient: authClient, storage: storage);
    dio = Dio(options);
    dio.interceptors.add(AuthInterceptor(sessions, dio));
    if (adapter != null) {
      authClient.httpClientAdapter = adapter;
      dio.httpClientAdapter = adapter;
    }
  }

  late final Dio dio;
  late final SessionManager sessions;
}
