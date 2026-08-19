import 'dart:io';

/// Environment and server endpoint configuration.
///
/// A cold start probes the LAN endpoint briefly. If this phone is on the same
/// network as the server it uses the direct address; everywhere else it uses
/// the public TLS endpoint. `API_BASE_URL` remains an explicit override for
/// development and CI builds.
///
/// ```bash
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
/// ```
abstract final class AppConfig {
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );
  static const String _overrideApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String localApiBaseUrl = String.fromEnvironment(
    'LOCAL_API_BASE_URL',
    defaultValue: 'http://192.168.1.72:8080',
  );

  static const String publicApiBaseUrl = String.fromEnvironment(
    'PUBLIC_API_BASE_URL',
    defaultValue: 'https://wavelive.duckdns.org',
  );

  static const String apiPath = '/api/v1';

  static String _apiBaseUrl = publicApiBaseUrl;
  static bool _isUsingLocalEndpoint = false;

  static String get apiBaseUrl => _apiBaseUrl;
  static String get apiRoot => '$apiBaseUrl$apiPath';
  static bool get isUsingLocalEndpoint => _isUsingLocalEndpoint;
  static bool get hasExplicitApiOverride => _overrideApiBaseUrl.isNotEmpty;
  static String get alternateApiBaseUrl => hasExplicitApiOverride
      ? _overrideApiBaseUrl
      : (_isUsingLocalEndpoint ? publicApiBaseUrl : localApiBaseUrl);

  /// Resolves the endpoint before dependency injection creates any network
  /// clients. The LAN probe is intentionally sub-second so an off-network
  /// launch is not held on the splash screen.
  static Future<void> initializeEndpoint() async {
    if (demoMode) {
      // Nothing to resolve: the demo build serves itself. Probing here would
      // only delay the first frame waiting for a server it will never call.
      return;
    }
    if (_overrideApiBaseUrl.isNotEmpty) {
      _apiBaseUrl = _overrideApiBaseUrl;
      _isUsingLocalEndpoint = _overrideApiBaseUrl == localApiBaseUrl;
      return;
    }

    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 650);
    try {
      final Uri health = Uri.parse('$localApiBaseUrl$apiPath/health');
      final HttpClientRequest request = await client
          .getUrl(health)
          .timeout(const Duration(milliseconds: 800));
      final HttpClientResponse response = await request.close().timeout(
        const Duration(milliseconds: 800),
      );
      await response.drain<void>();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _apiBaseUrl = localApiBaseUrl;
        _isUsingLocalEndpoint = true;
        return;
      }
    } catch (_) {
      // Being away from the office LAN is the normal public-use case.
    } finally {
      client.close(force: true);
    }
    usePublicEndpoint();
  }

  /// Called by the HTTP client if the selected LAN endpoint disappears, such
  /// as when a phone switches from Wi-Fi to mobile data while the app is open.
  static void usePublicEndpoint() {
    useEndpoint(
      _overrideApiBaseUrl.isEmpty ? publicApiBaseUrl : _overrideApiBaseUrl,
    );
  }

  static void useLocalEndpoint() => useEndpoint(localApiBaseUrl);

  /// Records the endpoint that most recently completed a real request.
  ///
  /// The HTTP client still gives every request one attempt against the other
  /// endpoint. That bidirectional retry is important when the app was opened
  /// while the server was restarting, or when the phone moves between office
  /// Wi-Fi and another network without being killed first.
  static void useEndpoint(String endpoint) {
    _apiBaseUrl = endpoint;
    _isUsingLocalEndpoint = endpoint == localApiBaseUrl;
  }

  /// The host pings the server on this cadence. The server closes a room after
  /// roughly three missed pings, so this must stay well under that window.
  static const Duration heartbeatInterval = Duration(seconds: 30);

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Taps on the heart button are buffered and flushed as one request, because
  /// a viewer can easily produce dozens per second.
  static const Duration reactionFlushInterval = Duration(milliseconds: 900);

  /// Chat lines kept in memory per room. Old lines are dropped so a long
  /// session cannot grow the list without bound.
  static const int chatHistoryLimit = 200;
}
