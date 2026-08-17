import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/live_socket_client.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../camera/domain/entities/permission_status_entity.dart';
import '../../../camera/domain/usecases/permission_usecases.dart';
import '../../data/models/live_models.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_media_engine.dart';
import '../../domain/usecases/live_usecases.dart';
import 'session_controller.dart';

/// How a room was entered. The host publishes and owns the room's lifecycle;
/// the audience only subscribes. Everything else - chat, gifts, reactions - is
/// identical, which is why both live in one controller rather than two that
/// would duplicate it.
enum LiveRoomMode { host, audience }

/// A gift waiting to be animated. Bursts are queued rather than played at once
/// so a rich viewer cannot blank the screen with overlapping takeovers.
@immutable
class QueuedGift {
  const QueuedGift(this.event);
  final GiftEventEntity event;
}

class LiveRoomController extends GetxController {
  LiveRoomController({
    required this.mode,
    required this.startBroadcast,
    required this.joinStream,
    required this.endStream,
    required this.heartbeat,
    required this.sendReactionUseCase,
    required this.sendChatMessage,
    required this.loadGiftCatalogue,
    required this.sendGiftUseCase,
    required this.streamLeaderboard,
    required this.mediaEngine,
    required this.socketClient,
    required this.session,
    required this.requestCameraPermission,
    required this.requestMicrophonePermission,
    required this.openSettings,
    this.streamId,
    this.initialTitle,
  });

  final LiveRoomMode mode;
  final StartBroadcastUseCase startBroadcast;
  final JoinStreamUseCase joinStream;
  final EndStreamUseCase endStream;
  final HeartbeatUseCase heartbeat;
  final SendReactionUseCase sendReactionUseCase;
  final SendChatMessageUseCase sendChatMessage;
  final LoadGiftCatalogueUseCase loadGiftCatalogue;
  final SendGiftUseCase sendGiftUseCase;
  final StreamLeaderboardUseCase streamLeaderboard;
  final LiveMediaEngine mediaEngine;
  final LiveSocketClient socketClient;
  final SessionController session;
  final RequestCameraPermissionUseCase requestCameraPermission;
  final RequestMicrophonePermissionUseCase requestMicrophonePermission;
  final OpenApplicationSettingsUseCase openSettings;

  /// Set when joining an existing room; null when starting a new broadcast.
  final String? streamId;
  final String? initialTitle;

  // ---- room state ----
  final Rxn<LiveStreamEntity> stream = Rxn<LiveStreamEntity>();
  final Rxn<RtcCredentialsEntity> rtc = Rxn<RtcCredentialsEntity>();
  final RxBool isConnecting = true.obs;
  final RxBool isLive = false.obs;
  final RxBool hasEnded = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString permissionMessage = RxnString();

  // ---- media state ----
  final RxBool isVideoReady = false.obs;
  final RxBool isMicMuted = false.obs;
  final RxBool isCameraOn = true.obs;
  final RxInt hostRemoteUid = 0.obs;
  final Rx<LiveNetworkQuality> networkQuality = LiveNetworkQuality.unknown.obs;

  // ---- room content ----
  final RxList<ChatMessageEntity> messages = <ChatMessageEntity>[].obs;
  final RxList<LeaderboardEntryEntity> topGifters = <LeaderboardEntryEntity>[].obs;
  final RxList<GiftEntity> gifts = <GiftEntity>[].obs;
  final RxInt viewerCount = 0.obs;
  final RxInt totalLikes = 0.obs;
  final RxInt totalCoins = 0.obs;
  final Rx<Duration> elapsed = Duration.zero.obs;

  /// Consumed by the animation overlay, which pops one gift at a time.
  final RxList<QueuedGift> giftQueue = <QueuedGift>[].obs;

  /// Incremented to tell the hearts overlay to spawn. Using a counter rather
  /// than a list keeps the widget from rebuilding on unrelated state.
  final RxInt heartBursts = 0.obs;

  Timer? _heartbeatTimer;
  Timer? _elapsedTimer;
  Timer? _reactionFlushTimer;
  StreamSubscription<LiveSocketEvent>? _socketSubscription;
  StreamSubscription<LiveMediaEvent>? _mediaSubscription;

  /// Taps buffered since the last flush. A viewer can produce dozens a second
  /// and each one must not become a request.
  int _pendingReactions = 0;

  bool get isHost => mode == LiveRoomMode.host;

  /// True when the backend runs without vendor credentials. The UI then shows
  /// a labelled placeholder rather than a black rectangle.
  bool get isMockMedia => rtc.value?.isMock ?? false;

  @override
  void onInit() {
    super.onInit();
    _socketSubscription = socketClient.events.listen(_onSocketEvent);
    _mediaSubscription = mediaEngine.events.listen(_onMediaEvent);
    unawaited(_enterRoom());
    unawaited(_loadGifts());
  }

  // -------------------------------------------------------------------------
  // Entering and leaving
  // -------------------------------------------------------------------------

  Future<void> _enterRoom() async {
    isConnecting.value = true;
    errorMessage.value = null;
    try {
      if (isHost && !await _ensureBroadcastPermissions()) {
        isConnecting.value = false;
        return;
      }

      final LiveRoomSessionEntity room = isHost
          ? await startBroadcast(title: initialTitle ?? 'Live now')
          : await joinStream(streamId!);

      _applyRoom(room);
      // The screen must not sleep mid-broadcast, and a viewer watching without
      // touching the screen should not have it dim either.
      unawaited(WakelockPlus.enable());
      await _connectMedia(room.rtc);

      socketClient.joinRoom(room.stream.id);
      isLive.value = true;
      _startTimers();
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
    } catch (error, stackTrace) {
      debugLog('Failed to enter live room', error, stackTrace);
      errorMessage.value = 'Could not open the live room';
    } finally {
      isConnecting.value = false;
    }
  }

  void _applyRoom(LiveRoomSessionEntity room) {
    stream.value = room.stream;
    rtc.value = room.rtc;
    messages.assignAll(room.recentMessages);
    topGifters.assignAll(room.topGifters);
    viewerCount.value = room.stream.viewerCount;
    totalLikes.value = room.stream.totalLikes;
    totalCoins.value = room.stream.totalCoins;
  }

  /// A broadcast without camera and microphone access is not a broadcast, so
  /// this refuses to open the room rather than going live with a black frame.
  Future<bool> _ensureBroadcastPermissions() async {
    final PermissionStatusEntity camera = await requestCameraPermission();
    final PermissionStatusEntity microphone = await requestMicrophonePermission();

    if (camera.isUsable && microphone.isUsable) {
      return true;
    }

    permissionMessage.value =
        camera.shouldOpenSettings || microphone.shouldOpenSettings
        ? 'Camera and microphone access are turned off. Enable them in Settings to go live.'
        : 'Going live needs camera and microphone access.';
    return false;
  }

  Future<void> _connectMedia(RtcCredentialsEntity credentials) async {
    if (credentials.isMock) {
      // Nothing to connect to; the placeholder surface stands in for video so
      // the rest of the room stays fully testable.
      isVideoReady.value = true;
      return;
    }
    await mediaEngine.initialize(credentials.appId);
    if (isHost) {
      await mediaEngine.joinAsHost(credentials);
      isVideoReady.value = true;
    } else {
      await mediaEngine.joinAsAudience(credentials);
      // A viewer's video only counts as ready once a frame actually decodes,
      // which _onMediaEvent sets.
    }
  }

  Future<void> _loadGifts() async {
    try {
      gifts.assignAll(await loadGiftCatalogue());
    } on AppFailure catch (failure) {
      debugLog('Gift catalogue failed: ${failure.message}');
    }
  }

  void _startTimers() {
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final LiveStreamEntity? current = stream.value;
      if (current != null) {
        elapsed.value = DateTime.now().difference(current.startedAt);
      }
    });

    // Only the host owns the room's liveness. A missed run of pings tells the
    // server the broadcast died so the room can be closed for everyone.
    if (isHost) {
      _heartbeatTimer = Timer.periodic(AppConfig.heartbeatInterval, (_) async {
        final String? id = stream.value?.id;
        if (id == null || hasEnded.value) {
          return;
        }
        try {
          await heartbeat(id);
        } on AppFailure catch (failure) {
          debugLog('Heartbeat failed: ${failure.message}');
        }
      });
    }
  }

  // -------------------------------------------------------------------------
  // Realtime
  // -------------------------------------------------------------------------

  void _onSocketEvent(LiveSocketEvent event) {
    final String? currentId = stream.value?.id;
    switch (event.name) {
      case LiveEvents.chatMessage:
        _appendMessage(ChatMessageModel.fromJson(event.payload));

      case LiveEvents.giftReceived:
        final GiftEventEntity gift = GiftEventModel.fromJson(event.payload);
        giftQueue.add(QueuedGift(gift));
        final Map<String, dynamic> totals =
            LiveModelParsers.asMap(event.payload['streamTotals']);
        if (totals.isNotEmpty) {
          totalCoins.value = LiveModelParsers.asInt(totals['totalCoins']);
        }
        final List<LeaderboardEntryEntity> podium =
            LeaderboardEntryModel.listFrom(event.payload['topGifters']);
        if (podium.isNotEmpty) {
          topGifters.assignAll(podium);
        }

      case LiveEvents.reactionBurst:
        totalLikes.value = LiveModelParsers.asInt(
          event.payload['totalLikes'],
          totalLikes.value,
        );
        // The sender already saw their own hearts locally; replaying them would
        // double every tap.
        if (LiveModelParsers.asString(event.payload['senderId']) !=
            session.user.value?.id) {
          heartBursts.value += LiveModelParsers.asInt(event.payload['count'], 1);
        }

      case LiveEvents.streamStats:
        viewerCount.value = LiveModelParsers.asInt(
          event.payload['viewerCount'],
          viewerCount.value,
        );
        totalLikes.value = LiveModelParsers.asInt(
          event.payload['totalLikes'],
          totalLikes.value,
        );

      case LiveEvents.viewerJoined:
        viewerCount.value = LiveModelParsers.asInt(
          event.payload['viewerCount'],
          viewerCount.value,
        );
        final Map<String, dynamic> viewer =
            LiveModelParsers.asMap(event.payload['viewer']);
        if (viewer.isNotEmpty && currentId != null) {
          // Rendered as a subtle system line rather than a normal message.
          _appendMessage(
            ChatMessageEntity(
              id: 'join-${viewer['id']}-${DateTime.now().microsecondsSinceEpoch}',
              streamId: currentId,
              body: null,
              kind: ChatMessageKind.join,
              createdAt: DateTime.now(),
              sender: UserProfileModel.fromJson(viewer),
            ),
          );
        }

      case LiveEvents.viewerLeft:
        viewerCount.value = LiveModelParsers.asInt(
          event.payload['viewerCount'],
          viewerCount.value,
        );

      case LiveEvents.streamEnded:
        final String endedId = LiveModelParsers.asString(event.payload['streamId']);
        if (currentId == null || endedId.isEmpty || endedId == currentId) {
          hasEnded.value = true;
          isLive.value = false;
          _stopTimers();
        }

      case LiveEvents.walletUpdated:
        session.applyWalletUpdate(WalletModel.fromJson(event.payload));
    }
  }

  void _appendMessage(ChatMessageEntity message) {
    messages.add(message);
    // A long session would otherwise grow this list without bound.
    if (messages.length > AppConfig.chatHistoryLimit) {
      messages.removeRange(0, messages.length - AppConfig.chatHistoryLimit);
    }
  }

  void _onMediaEvent(LiveMediaEvent event) {
    switch (event) {
      case MediaRemoteJoinedEvent(:final int uid):
        // In a one-to-many room the only publisher is the host.
        if (!isHost) {
          hostRemoteUid.value = uid;
        }

      case MediaFirstRemoteFrameEvent():
        isVideoReady.value = true;

      case MediaRemoteLeftEvent(:final int uid):
        if (hostRemoteUid.value == uid) {
          hostRemoteUid.value = 0;
          isVideoReady.value = false;
        }

      case MediaNetworkQualityEvent(:final LiveNetworkQuality quality):
        networkQuality.value = quality;

      case MediaTokenExpiringEvent():
        unawaited(_renewRtcToken());

      case MediaErrorEvent(:final String message):
        errorMessage.value = message;

      case MediaConnectionChangedEvent():
      case MediaJoinedEvent():
        break;
    }
  }

  /// Re-asks the backend for credentials and hands the fresh token to the SDK,
  /// so a long broadcast does not drop when the original token ages out.
  Future<void> _renewRtcToken() async {
    final String? id = stream.value?.id;
    if (id == null) {
      return;
    }
    try {
      final LiveRoomSessionEntity refreshed = await joinStream(id);
      rtc.value = refreshed.rtc;
      await mediaEngine.renewToken(refreshed.rtc.token);
      debugLog('RTC token renewed');
    } on AppFailure catch (failure) {
      debugLog('RTC token renewal failed: ${failure.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> sendMessage(String body) async {
    final String trimmed = body.trim();
    final String? id = stream.value?.id;
    if (trimmed.isEmpty || id == null) {
      return;
    }
    try {
      // Sent over the socket: the server echoes it back to the room, so the
      // sender sees their own line through the same path as everyone else and
      // ordering stays consistent.
      socketClient.sendChat(id, trimmed);
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
    }
  }

  /// Buffers a tap. Hearts appear instantly on this device; the count is
  /// flushed to the server on a timer.
  void tapHeart() {
    final String? id = stream.value?.id;
    if (id == null || hasEnded.value) {
      return;
    }
    heartBursts.value += 1;
    _pendingReactions += 1;

    _reactionFlushTimer ??= Timer(AppConfig.reactionFlushInterval, () {
      _reactionFlushTimer = null;
      final int batch = _pendingReactions;
      _pendingReactions = 0;
      if (batch > 0) {
        // The server caps a batch at 50.
        socketClient.sendReaction(id, batch.clamp(1, 50));
      }
    });
  }

  Future<bool> sendGift(GiftEntity gift, {int quantity = 1}) async {
    final String? id = stream.value?.id;
    if (id == null) {
      return false;
    }
    try {
      final ({GiftEventEntity event, WalletEntity wallet}) result =
          await sendGiftUseCase(streamId: id, giftCode: gift.code, quantity: quantity);
      // The balance is applied straight away; the animation arrives for
      // everyone, sender included, over the socket.
      session.applyWalletUpdate(result.wallet);
      return true;
    } on InsufficientBalanceFailure catch (failure) {
      errorMessage.value =
          'You need ${failure.missingCoins} more coins for this gift';
      return false;
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
      return false;
    }
  }

  Future<void> toggleMicrophone() async {
    isMicMuted.value = !isMicMuted.value;
    await mediaEngine.setMicrophoneMuted(isMicMuted.value);
  }

  Future<void> toggleCamera() async {
    isCameraOn.value = !isCameraOn.value;
    await mediaEngine.setCameraEnabled(isCameraOn.value);
  }

  Future<void> switchCamera() => mediaEngine.switchCamera();

  Future<void> openAppSettings() => openSettings();

  Future<void> retry() => _enterRoom();

  /// Ends the broadcast for everyone. Only meaningful for the host.
  Future<void> endBroadcast() async {
    final String? id = stream.value?.id;
    if (id == null || hasEnded.value) {
      hasEnded.value = true;
      return;
    }
    try {
      await endStream(id);
    } on AppFailure catch (failure) {
      debugLog('Ending the stream failed: ${failure.message}');
    } finally {
      hasEnded.value = true;
      isLive.value = false;
      _stopTimers();
    }
  }

  /// Leaves without closing the room. Used by viewers and by a host backing out
  /// of a room they did not start.
  Future<void> leaveRoom() async {
    final String? id = stream.value?.id;
    if (id != null) {
      socketClient.leaveRoom(id);
    }
    _stopTimers();
    await mediaEngine.leave();
    await WakelockPlus.disable();
  }

  void consumeGift(QueuedGift gift) => giftQueue.remove(gift);

  void _stopTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _reactionFlushTimer?.cancel();
    _reactionFlushTimer = null;
  }

  @override
  void onClose() {
    _socketSubscription?.cancel();
    _mediaSubscription?.cancel();
    _stopTimers();
    final String? id = stream.value?.id;
    if (id != null) {
      socketClient.leaveRoom(id);
    }
    unawaited(mediaEngine.leave());
    unawaited(WakelockPlus.disable());
    super.onClose();
  }
}
