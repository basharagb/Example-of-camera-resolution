import 'dart:async';

import '../../../../core/services/network/live_events_client.dart';
import 'demo_live_backend.dart';

/// The realtime feed, served from memory.
///
/// It stands in for the SSE connection: same event names, same payload shapes,
/// same room scoping - one subscribed room at a time, plus the discovery and
/// wallet channels that are not tied to a room. Because the scoping is applied
/// here rather than in the backend, the controllers cannot tell the two
/// implementations apart.
class DemoLiveEventsClient implements LiveEventsClient {
  DemoLiveEventsClient(this._backend);

  final DemoLiveBackend _backend;

  final StreamController<bool> _connection = StreamController<bool>.broadcast();
  StreamSubscription<LiveRealtimeEvent>? _subscription;
  final StreamController<LiveRealtimeEvent> _scoped =
      StreamController<LiveRealtimeEvent>.broadcast();

  String? _streamId;
  bool _connected = false;

  /// Events that belong to the whole app rather than to one room, and so are
  /// delivered whatever the client is currently subscribed to.
  static const Set<String> _global = <String>{
    LiveEvents.streamStarted,
    LiveEvents.streamEnded,
    LiveEvents.walletUpdated,
  };

  @override
  Stream<LiveRealtimeEvent> get events => _scoped.stream;

  @override
  Stream<bool> get connectionState => _connection.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _subscription ??= _backend.events.listen(_forward);
    _setConnected(true);
  }

  @override
  void joinRoom(String streamId) {
    _streamId = streamId;
    unawaited(connect());
  }

  @override
  void leaveRoom(String streamId) {
    if (_streamId != streamId) {
      return;
    }
    _streamId = null;
    // Leaving is what drops the viewer count and lets a seeded room go quiet
    // again, so nothing keeps ticking behind a closed screen.
    _backend.leave(streamId);
  }

  void _forward(LiveRealtimeEvent event) {
    if (_scoped.isClosed) {
      return;
    }
    if (_global.contains(event.name)) {
      _scoped.add(event);
      return;
    }
    final Object? streamId = event.payload['streamId'];
    if (streamId == null || streamId == _streamId) {
      _scoped.add(event);
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

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _streamId = null;
    _setConnected(false);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _scoped.close();
    await _connection.close();
  }
}
