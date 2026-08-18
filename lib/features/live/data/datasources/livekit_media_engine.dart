import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_media_engine.dart';

/// Mobile media adapter for the self-hosted LiveKit SFU.
///
/// The REST backend decides who may publish and signs the room token. This
/// class only connects with that token and translates LiveKit events into the
/// vendor-neutral events consumed by the room controller.
class LiveKitMediaEngine implements LiveMediaEngine {
  final StreamController<LiveMediaEvent> _events =
      StreamController<LiveMediaEvent>.broadcast();
  final List<int> _remoteUids = <int>[];

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String? _serverUrl;
  LocalVideoTrack? _previewTrack;
  RemoteVideoTrack? _remoteVideoTrack;
  CameraPosition _cameraPosition = CameraPosition.front;
  bool _joined = false;

  @override
  bool get isReady => _serverUrl != null || _previewTrack != null;

  @override
  List<int> get remoteUids => List<int>.unmodifiable(_remoteUids);

  @override
  Stream<LiveMediaEvent> get events => _events.stream;

  LocalVideoTrack? get localVideoTrack =>
      _previewTrack ??
      _room?.localParticipant
              ?.getTrackPublicationBySource(TrackSource.camera)
              ?.track
          as LocalVideoTrack?;

  RemoteVideoTrack? get remoteVideoTrack => _remoteVideoTrack;

  @override
  Future<void> initialize(String serverUrl) async {
    if (serverUrl.isEmpty) {
      throw const BroadcastFailure('The live video server is not configured');
    }
    if (_serverUrl != serverUrl && _room != null) {
      await leave();
    }
    _serverUrl = serverUrl;
  }

  @override
  Future<void> startLocalPreview() async {
    if (_previewTrack != null) {
      return;
    }
    try {
      _previewTrack = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          maxFrameRate: 30,
          params: VideoParametersPresets.h720_169,
        ),
      );
      _cameraPosition = CameraPosition.front;
    } catch (error, stackTrace) {
      debugLog('Local LiveKit preview failed', error, stackTrace);
      throw BroadcastFailure('Could not start the camera preview', error);
    }
  }

  @override
  Future<void> joinAsHost(RtcCredentialsEntity credentials) async {
    final Room room = await _connect(credentials);
    final LocalParticipant? participant = room.localParticipant;
    if (participant == null) {
      throw const BroadcastFailure(
        'The live video session did not create a participant',
      );
    }

    try {
      await participant.setCameraEnabled(
        true,
        cameraCaptureOptions: const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          maxFrameRate: 30,
          params: VideoParametersPresets.h720_169,
        ),
      );
      await participant.setMicrophoneEnabled(true);
      _cameraPosition = CameraPosition.front;
    } catch (error, stackTrace) {
      debugLog('LiveKit publish failed', error, stackTrace);
      await leave();
      throw BroadcastFailure(
        'Could not publish the camera and microphone',
        error,
      );
    }
  }

  @override
  Future<void> joinAsAudience(RtcCredentialsEntity credentials) async {
    final Room room = await _connect(credentials);
    _discoverExistingHostTrack(room);
  }

  Future<Room> _connect(RtcCredentialsEntity credentials) async {
    final String? serverUrl = _serverUrl;
    if (serverUrl == null) {
      throw const BroadcastFailure('The live video server is not ready');
    }

    await leave();
    final Room room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room = room;
    _listen(room);

    try {
      await room
          .connect(serverUrl, credentials.token)
          .timeout(const Duration(seconds: 15));
      _joined = true;
      final int uid = _uidFor(room.localParticipant);
      _emit(MediaJoinedEvent(credentials.channelName, uid));
      _emit(const MediaConnectionChangedEvent(true, 'joined'));
      return room;
    } catch (error, stackTrace) {
      debugLog('LiveKit room connection failed', error, stackTrace);
      await leave();
      throw BroadcastFailure(
        'Could not connect to the live video server',
        error,
      );
    }
  }

  void _listen(Room room) {
    _listener = room.createListener()
      ..on<ParticipantConnectedEvent>((ParticipantConnectedEvent event) {
        final int uid = _uidFor(event.participant);
        if (!_remoteUids.contains(uid)) {
          _remoteUids.add(uid);
        }
        _emit(MediaRemoteJoinedEvent(uid));
      })
      ..on<ParticipantDisconnectedEvent>((ParticipantDisconnectedEvent event) {
        final int uid = _uidFor(event.participant);
        _remoteUids.remove(uid);
        _emit(MediaRemoteLeftEvent(uid));
      })
      ..on<TrackSubscribedEvent>((TrackSubscribedEvent event) {
        if (event.track is RemoteVideoTrack &&
            event.publication.source == TrackSource.camera) {
          _remoteVideoTrack = event.track as RemoteVideoTrack;
          final int uid = _uidFor(event.participant);
          if (!_remoteUids.contains(uid)) {
            _remoteUids.add(uid);
            _emit(MediaRemoteJoinedEvent(uid));
          }
          // A subscribed WebRTC video track is ready for the renderer. This
          // also guarantees the UI cannot wait forever for a vendor callback.
          _emit(MediaFirstRemoteFrameEvent(uid));
        }
      })
      ..on<TrackUnsubscribedEvent>((TrackUnsubscribedEvent event) {
        if (identical(event.track, _remoteVideoTrack)) {
          _remoteVideoTrack = null;
        }
      })
      ..on<RoomReconnectingEvent>((_) {
        _emit(const MediaConnectionChangedEvent(false, 'reconnecting'));
      })
      ..on<RoomReconnectedEvent>((_) {
        _emit(const MediaConnectionChangedEvent(true, 'reconnected'));
      })
      ..on<RoomDisconnectedEvent>((RoomDisconnectedEvent event) {
        _joined = false;
        _emit(
          MediaConnectionChangedEvent(
            false,
            event.reason?.name ?? 'disconnected',
          ),
        );
      })
      ..on<ParticipantConnectionQualityUpdatedEvent>((
        ParticipantConnectionQualityUpdatedEvent event,
      ) {
        if (identical(event.participant, room.localParticipant)) {
          _emit(MediaNetworkQualityEvent(_mapQuality(event.connectionQuality)));
        }
      })
      ..on<TrackSubscriptionExceptionEvent>((
        TrackSubscriptionExceptionEvent event,
      ) {
        _emit(const MediaErrorEvent('The host video could not be received'));
      });
  }

  void _discoverExistingHostTrack(Room room) {
    for (final RemoteParticipant participant
        in room.remoteParticipants.values) {
      final RemoteTrackPublication? publication = participant
          .getTrackPublicationBySource(TrackSource.camera);
      final Track? track = publication?.track;
      if (track is RemoteVideoTrack) {
        _remoteVideoTrack = track;
        final int uid = _uidFor(participant);
        if (!_remoteUids.contains(uid)) {
          _remoteUids.add(uid);
          _emit(MediaRemoteJoinedEvent(uid));
        }
        _emit(MediaFirstRemoteFrameEvent(uid));
        return;
      }
    }
  }

  @override
  Future<void> switchCamera() async {
    final LocalVideoTrack? track = localVideoTrack;
    if (track == null) {
      return;
    }
    _cameraPosition = _cameraPosition.switched();
    await track.setCameraPosition(_cameraPosition);
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    await _room?.localParticipant?.setMicrophoneEnabled(!muted);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final LocalVideoTrack? preview = _previewTrack;
    if (preview != null) {
      if (enabled) {
        await preview.unmute();
      } else {
        await preview.mute();
      }
      return;
    }
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  @override
  Future<void> renewToken(String token) async {
    // LiveKit refreshes connected sessions over its signalling channel. The
    // join token is only revalidated if a reconnect creates a new session.
  }

  @override
  Future<void> leave() async {
    final LocalVideoTrack? preview = _previewTrack;
    _previewTrack = null;
    await preview?.dispose();

    final EventsListener<RoomEvent>? listener = _listener;
    _listener = null;
    await listener?.dispose();

    final Room? room = _room;
    _room = null;
    _remoteVideoTrack = null;
    _remoteUids.clear();
    if (room != null) {
      try {
        await room.disconnect();
      } finally {
        await room.dispose();
      }
    }
    if (_joined) {
      _joined = false;
      _emit(const MediaConnectionChangedEvent(false, 'left'));
    }
  }

  @override
  Future<void> dispose() => leave();

  int _uidFor(Participant? participant) {
    final String identity = participant?.identity ?? '';
    return int.tryParse(identity) ?? (identity.hashCode & 0x7fffffff);
  }

  void _emit(LiveMediaEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  static LiveNetworkQuality _mapQuality(ConnectionQuality quality) =>
      switch (quality) {
        ConnectionQuality.excellent => LiveNetworkQuality.excellent,
        ConnectionQuality.good => LiveNetworkQuality.good,
        ConnectionQuality.poor => LiveNetworkQuality.poor,
        ConnectionQuality.lost => LiveNetworkQuality.down,
        ConnectionQuality.unknown => LiveNetworkQuality.unknown,
      };
}
