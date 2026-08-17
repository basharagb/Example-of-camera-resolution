/// Environment configuration.
///
/// Values come from `--dart-define` so the same build artefact can point at a
/// local server or production without a code change:
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
/// ```
abstract final class AppConfig {
  /// Base origin of the backend, without the API path.
  ///
  /// The default is the deployed server so a release build works with no
  /// flags. For the Android emulator use `http://10.0.2.2:4000`; `localhost`
  /// there resolves to the emulator itself, not to the development machine.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://live.elite-center-ld.com',
  );

  static const String apiPath = '/api/v1';

  static String get apiRoot => '$apiBaseUrl$apiPath';

  /// The host pings the server on this cadence. The server closes a room after
  /// roughly three missed pings, so this must stay well under that window.
  static const Duration heartbeatInterval = Duration(seconds: 30);

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);

  /// Taps on the heart button are buffered and flushed as one request, because
  /// a viewer can easily produce dozens per second.
  static const Duration reactionFlushInterval = Duration(milliseconds: 900);

  /// Chat lines kept in memory per room. Old lines are dropped so a long
  /// session cannot grow the list without bound.
  static const int chatHistoryLimit = 200;
}
