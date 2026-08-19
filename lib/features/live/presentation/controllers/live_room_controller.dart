import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/live_events_client.dart';
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

class LiveRoomController extends GetxController with WidgetsBindingObserver {
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
    required this.eventsClient,
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
  final LiveEventsClient eventsClient;
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

  /// True only when the platform will no longer show a prompt, so the UI knows
  /// whether asking again is worth offering or Settings is the only route.
  final RxBool permissionNeedsSettings = false.obs;

  // ---- media state ----
  final RxBool isVideoReady = false.obs;
  final RxBool isMicMuted = false.obs;
  final RxBool isCameraOn = true.obs;
  final RxInt hostRemoteUid = 0.obs;
  final Rx<LiveNetworkQuality> networkQuality = LiveNetworkQuality.unknown.obs;

  // ---- room content ----
  final RxList<ChatMessageEntity> messages = <ChatMessageEntity>[].obs;
  final RxList<LeaderboardEntryEntity> topGifters =
      <LeaderboardEntryEntity>[].obs;
  final RxList<GiftEntity> gifts = <GiftEntity>[].obs;
  final RxInt viewerCount = 0.obs;

  /// The few most recent arrivals, newest first, shown as avatars beside the
  /// viewer count. Capped because only a handful fit on screen.
  final RxList<UserProfileEntity> recentViewers = <UserProfileEntity>[].obs;
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
  StreamSubscription<LiveRealtimeEvent>? _eventsSubscription;
  StreamSubscription<LiveMediaEvent>? _mediaSubscription;

  /// Taps buffered since the last flush. A viewer can produce dozens a second
  /// and each one must not become a request.
  int _pendingReactions = 0;
  bool _enteringRoom = false;
  bool _returningFromSettings = false;

  bool get isHost => mode == LiveRoomMode.host;

  /// True when the backend runs without vendor credentials. The UI then shows
  /// a labelled placeholder rather than a black rectangle.
  bool get isMockMedia => rtc.value?.isMock ?? false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _eventsSubscription = eventsClient.events.listen(_onRealtimeEvent);
    _mediaSubscription = mediaEngine.events.listen(_onMediaEvent);
    unawaited(_enterRoom());
    unawaited(_loadGifts());
  }

  // -------------------------------------------------------------------------
  // Entering and leaving
  // -------------------------------------------------------------------------

  Future<void> _enterRoom() async {
    if (_enteringRoom) return;
    _enteringRoom = true;
    isConnecting.value = true;
    errorMessage.value = null;
    permissionMessage.value = null;
    try {
      if (isHost && !await _ensureBroadcastPermissions()) {
        isConnecting.value = false;
        return;
      }

      // Open the Android camera before any REST or signalling request. The
      // host sees a real preview immediately and a slow RTC connection can no
      // longer look like a camera permission failure.
      if (isHost) {
        await mediaEngine.startLocalPreview();
        isVideoReady.value = true;
      }

      final LiveRoomSessionEntity room = isHost
          ? await startBroadcast(title: initialTitle ?? 'Live now')
          : await joinStream(streamId!);

      _applyRoom(room);
      // The screen must not sleep mid-broadcast, and a viewer watching without
      // touching the screen should not have it dim either.
      unawaited(WakelockPlus.enable());
      await _connectMedia(room.rtc);

      eventsClient.joinRoom(room.stream.id);
      isLive.value = true;
      _startTimers();
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
      await _cleanupFailedHostRoom();
    } catch (error, stackTrace) {
      debugLog('Failed to enter live room', error, stackTrace);
      errorMessage.value = 'Could not open the live room';
      await _cleanupFailedHostRoom();
    } finally {
      isConnecting.value = false;
      _enteringRoom = false;
    }
  }

  Future<void> _cleanupFailedHostRoom() async {
    if (!isHost) return;
    final String? startedId = stream.value?.id;
    if (startedId != null) {
      try {
        await endStream(startedId);
      } catch (error) {
        debugLog('Failed room cleanup could not end the server stream', error);
      }
    }
    await mediaEngine.leave();
    stream.value = null;
    rtc.value = null;
    isVideoReady.value = false;
    isLive.value = false;
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
    if (!camera.isUsable) {
      permissionNeedsSettings.value = camera.shouldOpenSettings;
      permissionMessage.value = camera.shouldOpenSettings
          ? 'Camera access is disabled. Enable Camera in app Settings, then return.'
          : 'Tap Allow when Android asks for camera access.';
      return false;
    }

    final PermissionStatusEntity microphone =
        await requestMicrophonePermission();
    if (!microphone.isUsable) {
      permissionNeedsSettings.value = microphone.shouldOpenSettings;
      permissionMessage.value = microphone.shouldOpenSettings
          ? 'Microphone access is disabled. Enable Microphone in app Settings, then return.'
          : 'Tap Allow when Android asks for microphone access.';
      return false;
    }

    permissionNeedsSettings.value = false;
    return true;
  }

  Future<void> _connectMedia(RtcCredentialsEntity credentials) async {
    if (!isHost && (stream.value?.isDemo ?? false)) {
      // A persistent demo host has backend chat/gifts/realtime state, while its
      // media is a bundled loop so reviewers can test the whole viewer flow
      // without requiring a second broadcasting phone.
      isVideoReady.value = true;
      return;
    }
    if (credentials.isMock) {
      // A mock backend cannot deliver video to viewers, but the host can still
      // frame the shot and exercise camera controls with an on-device preview.
      if (isHost && !mediaEngine.isReady) {
        try {
          await mediaEngine.startLocalPreview();
        } catch (error, stackTrace) {
          // The mock room remains useful for chat, gifts and reactions even on
          // a simulator or a device whose camera could not be initialised.
          debugLog('Local preview is unavailable', error, stackTrace);
        }
      }
      isVideoReady.value = true;
      return;
    }
    final String serverUrl = AppConfig.isUsingLocalEndpoint
        ? credentials.localServerUrl
        : credentials.serverUrl;
    await mediaEngine.initialize(serverUrl);
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

  void _onRealtimeEvent(LiveRealtimeEvent event) {
    final String? currentId = stream.value?.id;
    switch (event.name) {
      case LiveEvents.chatMessage:
        _appendMessage(ChatMessageModel.fromJson(event.payload));

      case LiveEvents.giftReceived:
        final GiftEventEntity gift = GiftEventModel.fromJson(event.payload);
        giftQueue.add(QueuedGift(gift));
        final Map<String, dynamic> totals = LiveModelParsers.asMap(
          event.payload['streamTotals'],
        );
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
          heartBursts.value += LiveModelParsers.asInt(
            event.payload['count'],
            1,
          );
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
        final Map<String, dynamic> viewer = LiveModelParsers.asMap(
          event.payload['viewer'],
        );
        if (viewer.isNotEmpty) {
          final UserProfileEntity profile = UserProfileModel.fromJson(viewer);
          // Re-inserted rather than skipped when already present, so someone
          // rejoining moves back to the front instead of being invisible.
          recentViewers
            ..removeWhere((UserProfileEntity item) => item.id == profile.id)
            ..insert(0, profile);
          if (recentViewers.length > 3) {
            recentViewers.removeRange(3, recentViewers.length);
          }
        }
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
        final String leftId = LiveModelParsers.asString(
          event.payload['viewerId'],
        );
        recentViewers.removeWhere(
          (UserProfileEntity item) => item.id == leftId,
        );

      case LiveEvents.streamEnded:
        final String endedId = LiveModelParsers.asString(
          event.payload['streamId'],
        );
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
      // Posted over REST; the server echoes it back down the realtime stream,
      // so the sender sees their own line through the same path as everyone
      // else and ordering stays consistent for the whole room.
      await sendChatMessage(id, trimmed);
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
        // The server caps a batch at 50. Fire and forget: the hearts already
        // animated locally, so a failed flush must not interrupt watching.
        sendReactionUseCase(id, batch.clamp(1, 50)).catchError((Object error) {
          debugLog('Reaction flush failed', error);
          return 0;
        });
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
          await sendGiftUseCase(
            streamId: id,
            giftCode: gift.code,
            quantity: quantity,
          );
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

  Future<void> switchCamera() async {
    if (rtc.value?.isMock ?? false) {
      isVideoReady.value = false;
      try {
        await mediaEngine.switchCamera();
      } catch (error, stackTrace) {
        debugLog(
          'Could not switch the local preview camera',
          error,
          stackTrace,
        );
      } finally {
        // Rebuild with either the new controller or the explicit preview-failed
        // placeholder. Leaving this false would show a spinner forever.
        isVideoReady.value = true;
      }
      return;
    }
    await mediaEngine.switchCamera();
  }

  Future<void> openAppSettings() async {
    _returningFromSettings = true;
    await openSettings();
  }

  Future<void> retry() {
    permissionMessage.value = null;
    permissionNeedsSettings.value = false;
    return _enterRoom();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isHost) return;
    if (state == AppLifecycleState.resumed) {
      if (_returningFromSettings && permissionMessage.value != null) {
        _returningFromSettings = false;
        unawaited(retry());
      } else if (isLive.value && isCameraOn.value) {
        unawaited(mediaEngine.setCameraEnabled(true));
      }
      return;
    }
    if ((state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused) &&
        isLive.value) {
      unawaited(mediaEngine.setCameraEnabled(false));
    }
  }

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
      eventsClient.leaveRoom(id);
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
    WidgetsBinding.instance.removeObserver(this);
    _eventsSubscription?.cancel();
    _mediaSubscription?.cancel();
    _stopTimers();
    final String? id = stream.value?.id;
    if (id != null) {
      eventsClient.leaveRoom(id);
    }
    unawaited(mediaEngine.leave());
    unawaited(WakelockPlus.disable());
    super.onClose();
  }
}
