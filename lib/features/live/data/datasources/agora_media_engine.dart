import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:camera/camera.dart' as camera;

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_media_engine.dart';

/// Agora implementation of [LiveMediaEngine].
///
/// This is the only file in the app that imports the vendor SDK. Everything
/// else talks to the interface, so the media provider stays a swappable
/// detail rather than something baked into the UI.
class AgoraMediaEngine implements LiveMediaEngine {
  RtcEngine? _engine;
  String? _initializedAppId;
  bool _joined = false;
  camera.CameraController? _localPreviewController;
  List<camera.CameraDescription> _localCameras = <camera.CameraDescription>[];
  int _localCameraIndex = 0;

  final StreamController<LiveMediaEvent> _events =
      StreamController<LiveMediaEvent>.broadcast();
  final List<int> _remoteUids = <int>[];

  @override
  bool get isReady =>
      _engine != null ||
      (_localPreviewController?.value.isInitialized ?? false);

  @override
  List<int> get remoteUids => List<int>.unmodifiable(_remoteUids);

  @override
  Stream<LiveMediaEvent> get events => _events.stream;

  /// The live engine instance, for the video view widgets. Null until
  /// [initialize] has run.
  RtcEngine? get rawEngine => _engine;

  /// Camera-plugin preview used only when the backend explicitly returns mock
  /// RTC credentials. Real rooms always render through [rawEngine].
  camera.CameraController? get localPreviewController =>
      _localPreviewController;

  @override
  Future<void> initialize(String appId) async {
    // Re-initialising with the same credentials would tear down a working
    // session for no reason.
    if (_engine != null && _initializedAppId == appId) {
      return;
    }
    if (_engine != null) {
      await dispose();
    }
    if (appId.isEmpty) {
      throw const BroadcastFailure('The live video service is not configured');
    }

    try {
      final RtcEngine engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
      engine.registerEventHandler(_buildEventHandler());
      await engine.enableVideo();
      await engine.enableAudio();

      _engine = engine;
      _initializedAppId = appId;
      debugLog('Agora engine initialised');
    } catch (error, stackTrace) {
      debugLog('Agora initialisation failed', error, stackTrace);
      throw BroadcastFailure('Could not start the live video engine', error);
    }
  }

  @override
  Future<void> startLocalPreview() async {
    if (_localPreviewController?.value.isInitialized ?? false) {
      return;
    }

    try {
      _localCameras = await camera.availableCameras();
      if (_localCameras.isEmpty) {
        throw const BroadcastFailure('No camera is available on this device');
      }

      final int frontCameraIndex = _localCameras.indexWhere(
        (camera.CameraDescription device) =>
            device.lensDirection == camera.CameraLensDirection.front,
      );
      _localCameraIndex = frontCameraIndex < 0 ? 0 : frontCameraIndex;
      await _openLocalCamera(_localCameraIndex);
      debugLog('Local host preview started (RTC provider: mock)');
    } on BroadcastFailure {
      rethrow;
    } catch (error, stackTrace) {
      debugLog('Local host preview failed', error, stackTrace);
      throw BroadcastFailure('Could not start the camera preview', error);
    }
  }

  Future<void> _openLocalCamera(int index) async {
    final camera.CameraController? previous = _localPreviewController;
    _localPreviewController = null;
    await previous?.dispose();

    final camera.CameraController next = camera.CameraController(
      _localCameras[index],
      camera.ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await next.initialize();
      _localCameraIndex = index;
      _localPreviewController = next;
    } catch (_) {
      await next.dispose();
      rethrow;
    }
  }

  RtcEngineEventHandler _buildEventHandler() => RtcEngineEventHandler(
    onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
      _joined = true;
      _emit(
        MediaJoinedEvent(connection.channelId ?? '', connection.localUid ?? 0),
      );
      _emit(const MediaConnectionChangedEvent(true, 'joined'));
    },
    onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
      if (!_remoteUids.contains(remoteUid)) {
        _remoteUids.add(remoteUid);
      }
      _emit(MediaRemoteJoinedEvent(remoteUid));
    },
    onUserOffline: (
      RtcConnection connection,
      int remoteUid,
      UserOfflineReasonType reason,
    ) {
      _remoteUids.remove(remoteUid);
      _emit(MediaRemoteLeftEvent(remoteUid));
    },
    onFirstRemoteVideoFrame: (
      RtcConnection connection,
      int remoteUid,
      int width,
      int height,
      int elapsed,
    ) {
      _emit(MediaFirstRemoteFrameEvent(remoteUid));
    },
    onConnectionLost: (RtcConnection connection) {
      _emit(const MediaConnectionChangedEvent(false, 'connection_lost'));
    },
    onConnectionStateChanged: (
      RtcConnection connection,
      ConnectionStateType state,
      ConnectionChangedReasonType reason,
    ) {
      final bool connected =
          state == ConnectionStateType.connectionStateConnected;
      _emit(MediaConnectionChangedEvent(connected, reason.name));
    },
    // Fired well before the token actually expires, leaving time to fetch a
    // replacement without the stream dropping.
    onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
      _emit(const MediaTokenExpiringEvent());
    },
    onNetworkQuality: (
      RtcConnection connection,
      int remoteUid,
      QualityType txQuality,
      QualityType rxQuality,
    ) {
      // uid 0 is the local user; only our own uplink is worth showing.
      if (remoteUid == 0) {
        _emit(MediaNetworkQualityEvent(_mapQuality(txQuality)));
      }
    },
    onError: (ErrorCodeType err, String msg) {
      debugLog('Agora error: ${err.name} $msg');
      _emit(MediaErrorEvent(_describeError(err, msg)));
    },
  );

  @override
  Future<void> joinAsHost(RtcCredentialsEntity credentials) async {
    final RtcEngine engine = _requireEngine();
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    // 720p30 at 2 Mbps: the quality ceiling most phones sustain on mobile data
    // without the encoder thermally throttling mid-stream.
    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 30,
        bitrate: 2000,
        orientationMode: OrientationMode.orientationModeFixedPortrait,
        degradationPreference: DegradationPreference.maintainBalanced,
      ),
    );

    await engine.startPreview();
    await _join(credentials, publish: true);
  }

  @override
  Future<void> joinAsAudience(RtcCredentialsEntity credentials) async {
    final RtcEngine engine = _requireEngine();
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _join(credentials, publish: false);
  }

  Future<void> _join(
    RtcCredentialsEntity credentials, {
    required bool publish,
  }) async {
    final RtcEngine engine = _requireEngine();
    _remoteUids.clear();
    try {
      await engine.joinChannel(
        token: credentials.token,
        channelId: credentials.channelName,
        uid: credentials.uid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: publish
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          publishCameraTrack: publish,
          publishMicrophoneTrack: publish,
          autoSubscribeVideo: true,
          autoSubscribeAudio: true,
        ),
      );
    } catch (error, stackTrace) {
      debugLog('Agora join failed', error, stackTrace);
      throw BroadcastFailure('Could not connect to the live room', error);
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_localPreviewController != null) {
      if (_localCameras.length < 2) {
        return;
      }
      final int nextIndex = (_localCameraIndex + 1) % _localCameras.length;
      await _openLocalCamera(nextIndex);
      return;
    }
    await _engine?.switchCamera();
  }

  @override
  Future<void> setMicrophoneMuted(bool muted) async {
    await _engine?.muteLocalAudioStream(muted);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final camera.CameraController? localPreview = _localPreviewController;
    if (localPreview != null) {
      if (enabled) {
        await localPreview.resumePreview();
      } else {
        await localPreview.pausePreview();
      }
      return;
    }

    final RtcEngine? engine = _engine;
    if (engine == null) {
      return;
    }
    await engine.muteLocalVideoStream(!enabled);
    if (enabled) {
      await engine.startPreview();
    } else {
      await engine.stopPreview();
    }
  }

  @override
  Future<void> renewToken(String token) async {
    await _engine?.renewToken(token);
  }

  @override
  Future<void> leave() async {
    final camera.CameraController? localPreview = _localPreviewController;
    _localPreviewController = null;
    _localCameras = <camera.CameraDescription>[];
    _localCameraIndex = 0;
    await localPreview?.dispose();

    final RtcEngine? engine = _engine;
    if (engine == null || !_joined) {
      _remoteUids.clear();
      return;
    }
    try {
      await engine.stopPreview();
      await engine.leaveChannel();
    } catch (error) {
      debugLog('Agora leave failed', error);
    } finally {
      _joined = false;
      _remoteUids.clear();
      _emit(const MediaConnectionChangedEvent(false, 'left'));
    }
  }

  @override
  Future<void> dispose() async {
    await leave();
    final RtcEngine? engine = _engine;
    _engine = null;
    _initializedAppId = null;
    if (engine != null) {
      engine.unregisterEventHandler(_buildEventHandler());
      await engine.release();
    }
  }

  RtcEngine _requireEngine() {
    final RtcEngine? engine = _engine;
    if (engine == null) {
      throw const BroadcastFailure('The live video engine is not ready yet');
    }
    return engine;
  }

  void _emit(LiveMediaEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  static LiveNetworkQuality _mapQuality(QualityType quality) => switch (quality) {
    QualityType.qualityExcellent => LiveNetworkQuality.excellent,
    QualityType.qualityGood => LiveNetworkQuality.good,
    QualityType.qualityPoor => LiveNetworkQuality.poor,
    QualityType.qualityBad || QualityType.qualityVbad => LiveNetworkQuality.bad,
    QualityType.qualityDown => LiveNetworkQuality.down,
    _ => LiveNetworkQuality.unknown,
  };

  /// Vendor error codes are opaque numbers to a user. The ones a person can
  /// actually act on get a plain explanation; the rest stay generic.
  static String _describeError(ErrorCodeType code, String fallback) =>
      switch (code) {
        ErrorCodeType.errInvalidToken ||
        ErrorCodeType.errTokenExpired =>
          'Your live session expired. Please rejoin.',
        ErrorCodeType.errInvalidAppId => 'The live video service is misconfigured',
        ErrorCodeType.errNoServerResources =>
          'The live service is busy. Try again in a moment.',
        _ => fallback.isEmpty ? 'Live video error (${code.name})' : fallback,
      };
}
