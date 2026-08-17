import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session tokens at rest.
///
/// Backed by the Keychain on iOS and EncryptedSharedPreferences on Android, so
/// a refresh token that lives for thirty days is not sitting in plain text on
/// the device.
abstract interface class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android defaults to AES-GCM with RSA key wrapping in v11, so the
            // options only need to name the storage namespace.
            aOptions: AndroidOptions(storageNamespace: 'elite_live'),
            // `first_unlock` keeps the token readable to a background
            // heartbeat after a reboot, while still requiring one unlock.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const String _accessKey = 'live_access_token';
  static const String _refreshKey = 'live_refresh_token';

  /// Reads are on the hot path of every request, so the access token is kept in
  /// memory after the first read rather than hitting the Keychain each time.
  String? _cachedAccessToken;

  @override
  Future<String?> readAccessToken() async {
    return _cachedAccessToken ??= await _storage.read(key: _accessKey);
  }

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    _cachedAccessToken = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
