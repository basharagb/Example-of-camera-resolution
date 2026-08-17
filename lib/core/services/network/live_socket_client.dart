import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

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

/// One Socket.IO connection shared by the whole app.
///
/// Transport order is deliberate: the production deployment sits behind
/// LiteSpeed, where a WebSocket upgrade is not guaranteed. Starting on polling
/// means the room always works, and the client silently upgrades if the
/// upgrade hop succeeds.
class LiveSocketClient {
  LiveSocketClient(this._tokenStorage);

  final TokenStorage _tokenStorage;

  io.Socket? _socket;
  final StreamController<LiveSocketEvent> _events =
      StreamController<LiveSocketEvent>.broadcast();
  final StreamController<bool> _connection = StreamController<bool>.broadcast();

  /// Rooms this client believes it is in. Kept so a reconnect can rejoin them
  /// without the UI having to notice the drop.
  final Set<String> _joinedRooms = <String>{};

  Stream<LiveSocketEvent> get events => _events.stream;
  Stream<bool> get connectionState => _connection.stream;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket != null && _socket!.connected) {
      return;
    }
    final String? token = await _tokenStorage.readAccessToken();
    if (token == null) {
      debugLog('Socket connect skipped: no access token');
      return;
    }

    await disconnect();

    final io.Socket socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(<String>['polling', 'websocket'])
          .setAuth(<String, dynamic>{'token': token})
          .enableReconnection()
          .setReconnectionAttempts(30)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      debugLog('Socket connected');
      _connection.add(true);
      // A reconnect lands in an empty server-side room, so membership has to be
      // re-established or the viewer would go silent without any visible sign.
      for (final String streamId in _joinedRooms) {
        socket.emit('room:join', <String, dynamic>{'streamId': streamId});
      }
    });

    socket.onDisconnect((_) {
      debugLog('Socket disconnected');
      _connection.add(false);
    });

    socket.onConnectError((Object? error) {
      debugLog('Socket connect error', error);
      _connection.add(false);
    });

    socket.onAny((String event, dynamic data) {
      if (!_events.isClosed) {
        _events.add(LiveSocketEvent(event, _asMap(data)));
      }
    });

    _socket = socket;
    socket.connect();
  }

  void joinRoom(String streamId) {
    _joinedRooms.add(streamId);
    _socket?.emit('room:join', <String, dynamic>{'streamId': streamId});
  }

  void leaveRoom(String streamId) {
    _joinedRooms.remove(streamId);
    _socket?.emit('room:leave', <String, dynamic>{'streamId': streamId});
  }

  void sendChat(String streamId, String body) {
    _socket?.emit('chat:send', <String, dynamic>{
      'streamId': streamId,
      'body': body,
    });
  }

  void sendReaction(String streamId, int count) {
    _socket?.emit('reaction:send', <String, dynamic>{
      'streamId': streamId,
      'count': count,
    });
  }

  Future<void> disconnect() async {
    final io.Socket? socket = _socket;
    _socket = null;
    if (socket == null) {
      return;
    }
    socket
      ..clearListeners()
      ..disconnect()
      ..dispose();
  }

  Future<void> dispose() async {
    _joinedRooms.clear();
    await disconnect();
    await _events.close();
    await _connection.close();
  }

  static Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      return (data.first as Map).cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }
}

class LiveSocketEvent {
  const LiveSocketEvent(this.name, this.payload);

  final String name;
  final Map<String, dynamic> payload;
}
