import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../config/app_config.dart';
import '../../utils/debug_log.dart';
import '../storage/token_storage.dart';

/// Every realtime event the server can push. Naming them keeps the string
/// literals in one place instead of scattered across widgets.
abstract final class LiveEvents {
  static const String chatMessage = 'chat:message';
  static const String giftReceived = 'gift:received';
  static const String reactionBurst = 'reaction:burst';
  static const String viewerJoined = 'viewer:joined';
  static const String viewerLeft = 'viewer:left';
  static const String streamStats = 'stream:stats';
  static const String streamEnded = 'stream:ended';
  static const String streamStarted = 'stream:started';
  static const String walletUpdated = 'wallet:updated';
}

class LiveRealtimeEvent {
  const LiveRealtimeEvent(this.name, this.payload);

  final String name;
  final Map<String, dynamic> payload;
}

/// The app's realtime feed, over Server-Sent Events.
///
/// SSE rather than Socket.IO for a concrete reason: the Dart Socket.IO client
/// only implements the WebSocket transport on native platforms (its
/// `io_transports.dart` returns a WebSocketTransport whatever transport you
/// ask for), and the LiteSpeed proxy in front of the API does not pass
/// WebSocket upgrades. SSE is an ordinary long-lived HTTP response, which that
/// proxy streams unbuffered, so it is the transport that actually works here.
///
/// The stream is receive-only. Everything the client sends - chat, gifts,
/// reactions - already has a REST endpoint, and the server echoes the result
/// back down this stream, so ordering stays consistent for sender and viewers
/// alike.
class LiveEventsClient {
  LiveEventsClient(this._tokenStorage);

  final TokenStorage _tokenStorage;

  final StreamController<LiveRealtimeEvent> _events =
      StreamController<LiveRealtimeEvent>.broadcast();
  final StreamController<bool> _connection = StreamController<bool>.broadcast();

  HttpClient? _client;
  StreamSubscription<String>? _subscription;

  /// The room this client is currently subscribed to, if any. Kept so a
  /// reconnect restores the same subscription without the UI noticing.
  String? _streamId;

  bool _connected = false;
  bool _disposed = false;
  bool _manuallyClosed = false;
  int _attempt = 0;
  Timer? _retryTimer;

  Stream<LiveRealtimeEvent> get events => _events.stream;
  Stream<bool> get connectionState => _connection.stream;
  bool get isConnected => _connected;

  Future<void> connect() => _open();

  /// Subscribing to a room means reconnecting with it in the query, because one
  /// connection carries exactly one room plus the private and discovery
  /// channels.
  void joinRoom(String streamId) {
    if (_streamId == streamId && _connected) {
      return;
    }
    _streamId = streamId;
    unawaited(_open());
  }

  void leaveRoom(String streamId) {
    if (_streamId != streamId) {
      return;
    }
    _streamId = null;
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_disposed) {
      return;
    }
    _retryTimer?.cancel();
    await _closeCurrent();

    final String? token = await _tokenStorage.readAccessToken();
    if (token == null) {
      debugLog('Realtime connect skipped: no access token');
      return;
    }

    _manuallyClosed = false;
    final Uri uri = Uri.parse(
      '${AppConfig.apiRoot}/events',
    ).replace(queryParameters: <String, String>{'streamId': ?_streamId});

    try {
      // A dedicated client with no idle timeout: this response is meant to stay
      // open for the whole session.
      final HttpClient client = HttpClient()
        ..connectionTimeout = AppConfig.connectTimeout
        ..idleTimeout = const Duration(hours: 1);
      _client = client;

      final HttpClientRequest request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token')
        ..set(HttpHeaders.acceptHeader, 'text/event-stream')
        ..set(HttpHeaders.cacheControlHeader, 'no-cache');
      // Without this dart:io buffers the request and the stream never starts.
      request.persistentConnection = true;

      final HttpClientResponse response = await request.close();
      if (response.statusCode != 200) {
        debugLog('Realtime stream rejected: HTTP ${response.statusCode}');
        await response.drain<void>();
        _scheduleRetry();
        return;
      }

      _setConnected(true);
      _attempt = 0;

      _subscription = response
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _onLine,
            onError: (Object error) {
              debugLog('Realtime stream error', error);
              _setConnected(false);
              _scheduleRetry();
            },
            onDone: () {
              _setConnected(false);
              if (!_manuallyClosed) {
                _scheduleRetry();
              }
            },
            cancelOnError: true,
          );
    } catch (error) {
      debugLog('Realtime connect failed', error);
      _setConnected(false);
      _scheduleRetry();
    }
  }

  // SSE frames arrive as `event:` / `data:` lines terminated by a blank line.
  String? _pendingEvent;
  final StringBuffer _pendingData = StringBuffer();

  void _onLine(String line) {
    if (line.isEmpty) {
      _dispatchPending();
      return;
    }
    // Lines beginning with a colon are comments; the server sends them as
    // keep-alive pings.
    if (line.startsWith(':')) {
      return;
    }
    if (line.startsWith('event:')) {
      _pendingEvent = line.substring(6).trim();
      return;
    }
    if (line.startsWith('data:')) {
      if (_pendingData.isNotEmpty) {
        _pendingData.write('\n');
      }
      _pendingData.write(line.substring(5).trimLeft());
    }
  }

  void _dispatchPending() {
    final String? name = _pendingEvent;
    final String raw = _pendingData.toString();
    _pendingEvent = null;
    _pendingData.clear();

    if (name == null || raw.isEmpty) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && !_events.isClosed) {
        _events.add(LiveRealtimeEvent(name, decoded));
      }
    } catch (error) {
      debugLog('Realtime frame was not valid JSON', error);
    }
  }

  void _setConnected(bool value) {
    if (_connected == value) {
      return;
    }
    _connected = value;
    if (!_connection.isClosed) {
      _connection.add(value);
    }
  }

  /// Exponential backoff, capped, so a server restart does not turn into a
  /// reconnect storm from every open app.
  void _scheduleRetry() {
    if (_disposed || _manuallyClosed) {
      return;
    }
    _attempt = (_attempt + 1).clamp(1, 6);
    final Duration delay = Duration(milliseconds: 500 * (1 << (_attempt - 1)));
    debugLog('Realtime reconnecting in ${delay.inMilliseconds}ms');
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_open()));
  }

  Future<void> _closeCurrent() async {
    await _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    _pendingEvent = null;
    _pendingData.clear();
    _setConnected(false);
  }

  Future<void> disconnect() async {
    _manuallyClosed = true;
    _retryTimer?.cancel();
    _streamId = null;
    await _closeCurrent();
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _events.close();
    await _connection.close();
  }
}
