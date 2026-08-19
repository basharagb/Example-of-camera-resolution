import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_room_controller.dart';
import '../controllers/session_controller.dart';
import '../widgets/coin_top_up_sheet.dart';
import '../widgets/floating_hearts_overlay.dart';
import '../widgets/gift_animation_overlay.dart';
import '../widgets/gift_sheet.dart';
import '../widgets/live_chat_overlay.dart';
import '../widgets/live_room_chrome.dart';
import '../widgets/live_video_surface.dart';

/// A live room, from either side.
///
/// The layers stack from the video up: video, readability scrims, chat, gift
/// animations, hearts, then the chrome. Only the toolbar differs between host
/// and viewer, so the same page serves both.
class LiveRoomPage extends GetView<LiveRoomController> {
  const LiveRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find<SessionController>();

    return PopScope(
      // Leaving must run the teardown - release the camera, leave the channel,
      // tell the server - so the back gesture is intercepted rather than
      // silently dropping the route.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          await _confirmExit(context);
        }
      },
      child: Scaffold(
        backgroundColor: LiveColors.background,
        resizeToAvoidBottomInset: false,
        body: Obx(() {
          if (controller.permissionMessage.value != null) {
            return _PermissionGate(controller: controller);
          }
          if (controller.errorMessage.value != null &&
              controller.stream.value == null) {
            return _ErrorGate(controller: controller);
          }
          if (controller.isConnecting.value) {
            return const _ConnectingGate();
          }
          if (controller.hasEnded.value) {
            return _EndedGate(controller: controller);
          }
          return _RoomBody(controller: controller, session: session);
        }),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    // A host closing the room ends it for everyone watching, so that one asks
    // first. A viewer simply leaves.
    if (!controller.isHost || controller.hasEnded.value) {
      await controller.leaveRoom();
      Get.back<void>();
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: LiveColors.surface,
        title: Text('End your live?', style: LiveTextStyles.title),
        content: Text(
          'Everyone watching will be returned to the feed.',
          style: LiveTextStyles.caption,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: LiveColors.live),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('End live'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await controller.endBroadcast();
    }
  }
}

class _RoomBody extends StatelessWidget {
  const _RoomBody({required this.controller, required this.session});

  final LiveRoomController controller;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        LiveVideoSurface(controller: controller),
        const _Scrims(),

        // Chat sits in the lower-left third; the right side stays clear for
        // the action rail and the hearts.
        Positioned(
          left: 0,
          right: MediaQuery.of(context).size.width * 0.28,
          bottom: 76,
          height: MediaQuery.of(context).size.height * 0.34,
          child: LiveChatOverlay(controller: controller),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).size.height * 0.34 + 84,
          child: TopGiftersBar(controller: controller),
        ),

        Positioned.fill(
          child: Obx(
            () =>
                FloatingHeartsOverlay(burstCount: controller.heartBursts.value),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(context).size.height * 0.28,
          child: GiftAnimationOverlay(controller: controller),
        ),

        LiveRoomHeader(
          controller: controller,
          onClose: () => Navigator.of(context).maybePop(),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: controller.isHost
              ? _HostToolbar(controller: controller, session: session)
              : _ViewerToolbar(controller: controller, session: session),
        ),

        _ErrorToast(controller: controller),
      ],
    );
  }
}

class _Scrims extends StatelessWidget {
  const _Scrims();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      children: <Widget>[
        Container(
          height: 190,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: LiveColors.topScrim,
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 320,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: LiveColors.bottomScrim,
              stops: <double>[0, 0.5, 1],
            ),
          ),
        ),
      ],
    ),
  );
}

/// The viewer's bar: say something, send a gift, tap a heart.
class _ViewerToolbar extends StatefulWidget {
  const _ViewerToolbar({required this.controller, required this.session});

  final LiveRoomController controller;
  final SessionController session;

  @override
  State<_ViewerToolbar> createState() => _ViewerToolbarState();
}

class _ViewerToolbarState extends State<_ViewerToolbar> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _input.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.controller.sendMessage(text);
    _input.clear();
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          LiveMetrics.screenPadding,
          8,
          LiveMetrics.screenPadding,
          MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: TextField(
                  controller: _input,
                  focusNode: _focusNode,
                  style: LiveTextStyles.body.copyWith(fontSize: 13.5),
                  textInputAction: TextInputAction.send,
                  maxLength: 200,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Say something…',
                    hintStyle: LiveTextStyles.caption.copyWith(fontSize: 13),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RoundAction(
              icon: Icons.card_giftcard_rounded,
              tint: LiveColors.coin,
              onTap: () => GiftSheet.show(
                context: context,
                controller: widget.controller,
                session: widget.session,
              ),
            ),
            const SizedBox(width: 8),
            _HeartButton(controller: widget.controller),
          ],
        ),
      ),
    );
  }
}

/// The host's bar: camera and microphone controls, the gift catalogue, and
/// ending the broadcast.
///
/// A host can send into their own room. On a real platform that is unusual; on
/// a single demo device it is the only way to see a gift travel the whole path
/// - wallet debited, animation played, podium updated, diamonds credited back
/// to the host - without a second phone in the room.
class _HostToolbar extends StatelessWidget {
  const _HostToolbar({required this.controller, required this.session});

  final LiveRoomController controller;
  final SessionController session;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        LiveMetrics.screenPadding,
        8,
        LiveMetrics.screenPadding,
        14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          Obx(
            () => _RoundAction(
              icon: controller.isMicMuted.value
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              tint: controller.isMicMuted.value
                  ? LiveColors.live
                  : Colors.white,
              onTap: controller.toggleMicrophone,
            ),
          ),
          Obx(
            () => _RoundAction(
              icon: controller.isCameraOn.value
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              tint: controller.isCameraOn.value
                  ? Colors.white
                  : LiveColors.live,
              onTap: controller.toggleCamera,
            ),
          ),
          _RoundAction(
            icon: Icons.cameraswitch_rounded,
            onTap: controller.switchCamera,
          ),
          _RoundAction(
            icon: Icons.card_giftcard_rounded,
            tint: LiveColors.coin,
            onTap: () => GiftSheet.show(
              context: context,
              controller: controller,
              session: session,
            ),
          ),
          _RoundAction(
            icon: Icons.stop_rounded,
            tint: Colors.white,
            background: LiveColors.live,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    ),
  );
}

class _HeartButton extends StatefulWidget {
  const _HeartButton({required this.controller});

  final LiveRoomController controller;

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    lowerBound: 0.85,
    upperBound: 1.0,
    value: 1,
  );

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _tap() {
    widget.controller.tapHeart();
    HapticFeedback.lightImpact();
    _bounce.reverse().then((_) => _bounce.forward());
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _tap,
    // Holding the button keeps the hearts coming, the way a long press works
    // in the apps this mirrors.
    onLongPressStart: (_) => _tap(),
    child: ScaleTransition(
      scale: _bounce,
      child: _RoundAction(emoji: '❤️', tint: LiveColors.live, onTap: _tap),
    ),
  );
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    this.icon,
    this.emoji,
    this.tint = Colors.white,
    this.background,
    required this.onTap,
  });

  final IconData? icon;
  final String? emoji;
  final Color tint;
  final Color? background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: background ?? Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 21))
          : Icon(icon, size: 22, color: tint),
    ),
  );
}

// ---------------------------------------------------------------------------
// Full screen states
// ---------------------------------------------------------------------------

class _ConnectingGate extends StatelessWidget {
  const _ConnectingGate();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: 38,
          height: 38,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: LiveColors.accent,
          ),
        ),
        SizedBox(height: 18),
        Text('Setting up the room', style: LiveTextStyles.caption),
      ],
    ),
  );
}

/// Shown when the broadcast could not start for lack of camera or microphone
/// access.
///
/// The primary action depends on whether the platform will still show a
/// prompt: if it will, the button asks again, and only a permanent refusal
/// sends the user to Settings. Sending a first-time user to Settings for a
/// permission they were never asked for is the frustrating version of this
/// screen.
class _PermissionGate extends StatelessWidget {
  const _PermissionGate({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) {
    final bool needsSettings = controller.permissionNeedsSettings.value;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiveColors.accent.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.videocam_rounded,
                size: 38,
                color: LiveColors.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              needsSettings
                  ? 'Access is turned off'
                  : 'Allow camera and microphone',
              style: LiveTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              controller.permissionMessage.value ?? '',
              textAlign: TextAlign.center,
              style: LiveTextStyles.caption.copyWith(height: 1.45),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 220,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: LiveColors.accent,
                  foregroundColor: LiveColors.accentInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                  ),
                ),
                onPressed: needsSettings
                    ? controller.openAppSettings
                    : controller.retry,
                child: Text(
                  needsSettings ? 'Open settings' : 'Allow access',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (needsSettings) ...<Widget>[
              const SizedBox(height: 6),
              TextButton(
                onPressed: controller.retry,
                style: TextButton.styleFrom(
                  foregroundColor: LiveColors.textSecondary,
                ),
                // After granting access in Settings, iOS restarts the app, but
                // Android returns to it, so a way back without leaving is worth
                // having.
                child: const Text('I have enabled it'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              style: TextButton.styleFrom(
                foregroundColor: LiveColors.textMuted,
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorGate extends StatelessWidget {
  const _ErrorGate({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            size: 52,
            color: LiveColors.textMuted,
          ),
          const SizedBox(height: 18),
          Text(
            controller.errorMessage.value ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: LiveTextStyles.body,
          ),
          const SizedBox(height: 22),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: LiveColors.accent,
              foregroundColor: LiveColors.accentInk,
            ),
            onPressed: controller.retry,
            child: const Text('Try again'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    ),
  );
}

/// The end-of-broadcast summary. For a host it is their session recap; for a
/// viewer it explains why the video stopped.
class _EndedGate extends StatelessWidget {
  const _EndedGate({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) {
    final LiveStreamEntity? stream = controller.stream.value;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              controller.isHost ? 'Your live has ended' : 'This live has ended',
              style: LiveTextStyles.displayLarge.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            if (stream != null)
              Text(stream.host.displayName, style: LiveTextStyles.caption),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _SummaryTile(
                  label: 'Duration',
                  value: formatDuration(controller.elapsed.value),
                ),
                _SummaryTile(
                  label: 'Viewers',
                  value: formatCompact(stream?.peakViewerCount ?? 0),
                ),
                _SummaryTile(
                  label: 'Likes',
                  value: formatCompact(controller.totalLikes.value),
                ),
                _SummaryTile(
                  label: 'Coins',
                  value: formatCompact(controller.totalCoins.value),
                  tint: LiveColors.coin,
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LiveColors.accent,
                foregroundColor: LiveColors.accentInk,
                minimumSize: const Size(190, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                ),
              ),
              onPressed: () async {
                await controller.leaveRoom();
                Get.back<void>();
              },
              child: const Text('Back to live'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.tint = LiveColors.textPrimary,
  });

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: <Widget>[
        Text(
          value,
          style: LiveTextStyles.title.copyWith(color: tint, fontSize: 19),
        ),
        const SizedBox(height: 4),
        Text(label, style: LiveTextStyles.caption.copyWith(fontSize: 11)),
      ],
    ),
  );
}

/// Transient errors that should not replace the room: a failed gift, a rate
/// limit, a dropped message.
class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final String? message = controller.errorMessage.value;
    if (message == null || controller.stream.value == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: LiveMetrics.screenPadding,
      right: LiveMetrics.screenPadding,
      bottom: 80,
      child: GestureDetector(
        onTap: () => controller.errorMessage.value = null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: LiveColors.live.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 17,
                color: Colors.white,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: LiveTextStyles.caption.copyWith(color: Colors.white),
                ),
              ),
              if (message.contains('coins'))
                TextButton(
                  onPressed: () {
                    controller.errorMessage.value = null;
                    CoinTopUpSheet.show(
                      context: context,
                      session: Get.find<SessionController>(),
                    );
                  },
                  child: const Text(
                    'Top up',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  });
}
