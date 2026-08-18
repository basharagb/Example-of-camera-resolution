import '../entities/live_entities.dart';

/// What the app needs from a live video vendor, expressed without naming one.
///
/// The Agora implementation lives in the data layer. Swapping to another SFU
/// means writing a second implementation of this interface; nothing in the
/// controllers or widgets changes.
abstract interface class LiveMediaEngine {
  /// True once [initialize] has produced a usable engine.
  bool get isReady;

  /// Remote publishers currently visible in the joined channel. For a normal
  /// one-to-many room this holds the host alone.
  List<int> get remoteUids;

  Stream<LiveMediaEvent> get events;

  /// Prepares the vendor SDK. Safe to call more than once.
  Future<void> initialize(String appId);

  /// Starts an on-device camera preview without joining a media channel.
  ///
  /// Development backends can deliberately run without RTC credentials. The
  /// host should still be able to frame the shot and use the camera controls,
  /// even though that preview cannot be delivered to an audience.
  Future<void> startLocalPreview();

  /// Publishes the local camera and microphone into [credentials]'s channel.
  Future<void> joinAsHost(RtcCredentialsEntity credentials);

  /// Subscribes to the channel without publishing anything.
  Future<void> joinAsAudience(RtcCredentialsEntity credentials);

  Future<void> switchCamera();

  Future<void> setMicrophoneMuted(bool muted);

  Future<void> setCameraEnabled(bool enabled);

  /// Applies a new token before the current one expires.
  Future<void> renewToken(String token);

  Future<void> leave();

  Future<void> dispose();
}

/// Events the engine reports back to the controller.
sealed class LiveMediaEvent {
  const LiveMediaEvent();
}

class MediaJoinedEvent extends LiveMediaEvent {
  const MediaJoinedEvent(this.channelName, this.uid);
  final String channelName;
  final int uid;
}

class MediaRemoteJoinedEvent extends LiveMediaEvent {
  const MediaRemoteJoinedEvent(this.uid);
  final int uid;
}

class MediaRemoteLeftEvent extends LiveMediaEvent {
  const MediaRemoteLeftEvent(this.uid);
  final int uid;
}

/// First frame decoded. The UI waits for this before hiding the loading state,
/// so a viewer never sees a black rectangle that looks like a broken stream.
class MediaFirstRemoteFrameEvent extends LiveMediaEvent {
  const MediaFirstRemoteFrameEvent(this.uid);
  final int uid;
}

class MediaConnectionChangedEvent extends LiveMediaEvent {
  const MediaConnectionChangedEvent(this.isConnected, this.reason);
  final bool isConnected;
  final String reason;
}

/// The channel token is close to expiring; the app must fetch a fresh one.
class MediaTokenExpiringEvent extends LiveMediaEvent {
  const MediaTokenExpiringEvent();
}

class MediaErrorEvent extends LiveMediaEvent {
  const MediaErrorEvent(this.message);
  final String message;
}

/// Uplink quality as reported by the vendor, surfaced as a signal bar for the
/// host so a bad connection is visible rather than mysterious.
enum LiveNetworkQuality { unknown, excellent, good, poor, bad, down }

class MediaNetworkQualityEvent extends LiveMediaEvent {
  const MediaNetworkQualityEvent(this.quality);
  final LiveNetworkQuality quality;
}
