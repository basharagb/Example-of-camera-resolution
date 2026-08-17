import 'dart:async';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../errors/failures.dart';
import '../../utils/debug_log.dart';
import '../storage/token_storage.dart';

/// Thin wrapper over Dio that owns three concerns the rest of the app should
/// never repeat: attaching the bearer token, unwrapping the server's
/// `{success, data, error}` envelope, and turning transport errors into typed
/// [AppFailure]s.
class ApiClient {
  ApiClient(this._tokenStorage, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.apiRoot,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              contentType: Headers.jsonContentType,
              // Non 2xx responses are handled by the error mapper rather than
              // thrown as transport failures, so the server's error code
              // survives instead of being flattened to "bad response".
              validateStatus: (int? status) => status != null && status < 500,
            ),
          ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          if (options.extra['skipAuth'] != true) {
            final String? token = await _tokenStorage.readAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Invoked when the session cannot be recovered, so the app can route back
  /// to the login screen from wherever it happens to be.
  void Function()? onSessionExpired;

  /// Guards against a burst of parallel 401s each firing its own refresh. The
  /// first one refreshes; the rest await the same future.
  Future<bool>? _pendingRefresh;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: Options(extra: <String, dynamic>{'skipAuth': !authenticated}),
    ),
    path: path,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: body,
      options: Options(extra: <String, dynamic>{'skipAuth': !authenticated}),
    ),
    path: path,
    authenticated: authenticated,
  );

  Future<Map<String, dynamic>> _send(
    Future<Response<dynamic>> Function() request, {
    required String path,
    required bool authenticated,
    bool isRetry = false,
  }) async {
    late final Response<dynamic> response;
    try {
      response = await request();
    } on DioException catch (error) {
      throw _mapTransportError(error, path);
    }

    final int status = response.statusCode ?? 500;
    final dynamic payload = response.data;

    if (status >= 200 && status < 300) {
      if (payload is Map && payload['success'] == true) {
        final dynamic data = payload['data'];
        return data is Map<String, dynamic>
            ? data
            : <String, dynamic>{'value': data};
      }
      throw ServerFailure('The server returned an unexpected response', payload);
    }

    // One transparent refresh attempt, then give up and surface the failure.
    if (status == 401 && authenticated && !isRetry) {
      if (await _refreshSession()) {
        return _send(request, path: path, authenticated: authenticated, isRetry: true);
      }
      onSessionExpired?.call();
    }

    throw _mapApiError(status, payload);
  }

  Future<bool> _refreshSession() {
    return _pendingRefresh ??= _performRefresh().whenComplete(() {
      _pendingRefresh = null;
    });
  }

  Future<bool> _performRefresh() async {
    final String? refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null) {
      return false;
    }
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': refreshToken},
        options: Options(extra: <String, dynamic>{'skipAuth': true}),
      );
      final dynamic payload = response.data;
      if (response.statusCode == 200 && payload is Map && payload['success'] == true) {
        final Map<String, dynamic> tokens =
            (payload['data']['tokens'] as Map).cast<String, dynamic>();
        await _tokenStorage.saveTokens(
          accessToken: tokens['accessToken'] as String,
          refreshToken: tokens['refreshToken'] as String,
        );
        debugLog('Session refreshed');
        return true;
      }
    } on DioException catch (error) {
      debugLog('Session refresh failed', error);
    }
    await _tokenStorage.clear();
    return false;
  }

  AppFailure _mapTransportError(DioException error, String path) {
    debugLog('Request failed: $path', error);
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const NetworkFailure(
        'The server took too long to respond. Check your connection.',
      ),
      DioExceptionType.connectionError ||
      DioExceptionType.unknown => const NetworkFailure(
        'Cannot reach the server. Check your internet connection.',
      ),
      DioExceptionType.cancel => const NetworkFailure('The request was cancelled'),
      _ => ServerFailure(error.message ?? 'The request failed', error),
    };
  }

  AppFailure _mapApiError(int status, dynamic payload) {
    String message = 'The request failed';
    String code = 'UNKNOWN';
    Map<String, dynamic> details = const <String, dynamic>{};

    if (payload is Map && payload['error'] is Map) {
      final Map<dynamic, dynamic> error = payload['error'] as Map<dynamic, dynamic>;
      message = (error['message'] as String?) ?? message;
      code = (error['code'] as String?) ?? code;
      if (error['details'] is Map) {
        details = (error['details'] as Map).cast<String, dynamic>();
      }
    }

    return switch (code) {
      'INSUFFICIENT_BALANCE' => InsufficientBalanceFailure(
        message,
        requiredCoins: (details['required'] as num?)?.toInt() ?? 0,
        availableCoins: (details['available'] as num?)?.toInt() ?? 0,
      ),
      'UNAUTHORIZED' => UnauthorizedFailure(message),
      'FORBIDDEN' => ForbiddenFailure(message),
      'NOT_FOUND' || 'ROUTE_NOT_FOUND' => NotFoundFailure(message),
      'CONFLICT' => ConflictFailure(message),
      'VALIDATION_ERROR' => ValidationFailure(message),
      'RATE_LIMITED' => RateLimitedFailure(message),
      _ => status >= 500 ? ServerFailure(message) : ValidationFailure(message),
    };
  }
}
