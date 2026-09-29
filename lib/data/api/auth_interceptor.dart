import 'package:dio/dio.dart';

import 'auth_session.dart';

/// Signs requests with the user's access token, and on a 401 refreshes the
/// session and retries the request once.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessions, this._dio);

  final SessionManager _sessions;

  /// The client this interceptor is attached to, used for the retry.
  final Dio _dio;

  static const _retriedKey = 'authRetried';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Signed out: the `apikey` header alone makes the request anonymous.
      final token = await _sessions.accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } on Object catch (e) {
      handler.reject(
        e is DioException ? e : DioException(requestOptions: options, error: e),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 ||
        options.extra[_retriedKey] == true ||
        _sessions.current == null) {
      return handler.next(err);
    }
    try {
      if (await _sessions.refresh() == null) return handler.next(err);
      options.extra[_retriedKey] = true;
      handler.resolve(await _dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
