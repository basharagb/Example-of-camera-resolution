import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_room_controller.dart';
import 'gift_artwork.dart';

/// Plays incoming gifts one at a time.
///
/// Gifts arrive in bursts and a legendary takeover covers most of the screen,
/// so they are queued rather than stacked: each plays for its own duration,
/// then the next begins. A cheap gift is a small banner; an expensive one gets
/// a full-width presentation.
class GiftAnimationOverlay extends StatefulWidget {
  const GiftAnimationOverlay({required this.controller, super.key});

  final LiveRoomController controller;

  @override
  State<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends State<GiftAnimationOverlay> {
  QueuedGift? _playing;
  Timer? _timer;
  Worker? _queueWorker;

  @override
  void initState() {
    super.initState();
    _queueWorker = ever<List<QueuedGift>>(
      widget.controller.giftQueue,
      (_) => _playNextIfIdle(),
    );
    _playNextIfIdle();
  }

  void _playNextIfIdle() {
    if (_playing != null || widget.controller.giftQueue.isEmpty || !mounted) {
      return;
    }
    final QueuedGift next = widget.controller.giftQueue.first;
    setState(() => _playing = next);

    _timer?.cancel();
    _timer = Timer(next.event.animationDuration, () {
      if (!mounted) {
        return;
      }
      widget.controller.consumeGift(next);
      setState(() => _playing = null);
      _playNextIfIdle();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _queueWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QueuedGift? playing = _playing;
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: LiveMetrics.medium,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> animation) =>
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-0.35, 0),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
        child: playing == null
            ? const SizedBox.shrink(key: ValueKey<String>('idle'))
            : _GiftBanner(
                key: ValueKey<String>(playing.event.id),
                event: playing.event,
              ),
      ),
    );
  }
}

class _GiftBanner extends StatelessWidget {
  const _GiftBanner({required this.event, super.key});

  final GiftEventEntity event;

  @override
  Widget build(BuildContext context) {
    final GiftEntity gift = event.gift;
    final bool isTakeover =
        gift.tier == GiftTier.epic || gift.tier == GiftTier.legendary;

    return Align(
      alignment: isTakeover ? Alignment.center : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LiveMetrics.screenPadding,
        ),
        child: isTakeover ? _Takeover(event: event) : _Banner(event: event),
      ),
    );
  }
}

/// Basic and rare gifts: a compact strip that slides in beside the chat.
class _Banner extends StatelessWidget {
  const _Banner({required this.event});

  final GiftEventEntity event;

  @override
  Widget build(BuildContext context) {
    final GiftEntity gift = event.gift;
    final Color tint = LiveColors.forTier(gift.tier);

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
        gradient: LinearGradient(colors: LiveColors.tierGradient(gift.tier)),
        border: Border.all(color: tint.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tint.withValues(alpha: 0.3),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _SenderAvatar(sender: event.sender, tint: tint),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                event.sender.displayName,
                style: LiveTextStyles.caption.copyWith(
                  color: LiveColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('sent ${gift.name}', style: LiveTextStyles.caption),
            ],
          ),
          const SizedBox(width: 14),
          _AnimatedGiftArtwork(gift: gift, size: 54),
          const SizedBox(width: 8),
          _ComboCounter(quantity: event.quantity, tint: tint),
        ],
      ),
    );
  }
}

/// Epic and legendary gifts: a centred card the whole room notices.
class _Takeover extends StatelessWidget {
  const _Takeover({required this.event});

  final GiftEventEntity event;

  @override
  Widget build(BuildContext context) {
    final GiftEntity gift = event.gift;
    final Color tint = LiveColors.forTier(gift.tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: LiveColors.tierGradient(gift.tier),
        ),
        border: Border.all(color: tint, width: 1.6),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tint.withValues(alpha: 0.45),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      tint.withValues(alpha: .42),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              for (int index = 0; index < 8; index++)
                Transform.rotate(
                  angle: index * .785,
                  child: Transform.translate(
                    offset: const Offset(0, -82),
                    child: Icon(
                      Icons.auto_awesome,
                      color: tint,
                      size: index.isEven ? 14 : 9,
                    ),
                  ),
                ),
              _AnimatedGiftArtwork(gift: gift, size: 138),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            gift.name.toUpperCase(),
            style: LiveTextStyles.displayLarge.copyWith(
              color: tint,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SenderAvatar(sender: event.sender, tint: tint, size: 26),
              const SizedBox(width: 8),
              Text(
                event.sender.displayName,
                style: LiveTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ComboCounter(quantity: event.quantity, tint: tint, large: true),
        ],
      ),
    );
  }
}

/// A slow breathing scale, enough to read as "alive" without distracting from
/// the video behind it.
class _AnimatedGiftArtwork extends StatefulWidget {
  const _AnimatedGiftArtwork({required this.gift, required this.size});

  final GiftEntity gift;
  final double size;

  @override
  State<_AnimatedGiftArtwork> createState() => _AnimatedGiftArtworkState();
}

class _AnimatedGiftArtworkState extends State<_AnimatedGiftArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: GiftArtwork(gift: widget.gift, size: widget.size),
    builder: (BuildContext context, Widget? child) {
      final double wave = Curves.easeInOut.transform(_controller.value);
      final bool travels = <String>{
        'drive',
        'fly',
        'sail',
        'swim',
      }.contains(widget.gift.animationType);
      return Transform.translate(
        offset: travels
            ? Offset((wave - .5) * 30, (1 - wave) * 8)
            : Offset(0, (wave - .5) * 9),
        child: Transform.rotate(
          angle: widget.gift.animationType == 'galaxy'
              ? _controller.value * .16
              : 0,
          child: Transform.scale(scale: .9 + wave * .16, child: child),
        ),
      );
    },
  );
}

class _ComboCounter extends StatelessWidget {
  const _ComboCounter({
    required this.quantity,
    required this.tint,
    this.large = false,
  });

  final int quantity;
  final Color tint;
  final bool large;

  @override
  Widget build(BuildContext context) {
    if (quantity <= 1) {
      return const SizedBox.shrink();
    }
    return Text(
      'x$quantity',
      style: TextStyle(
        fontSize: large ? 34 : 22,
        fontWeight: FontWeight.w900,
        color: tint,
        shadows: <Shadow>[
          Shadow(color: tint.withValues(alpha: 0.8), blurRadius: 14),
        ],
      ),
    );
  }
}

class _SenderAvatar extends StatelessWidget {
  const _SenderAvatar({
    required this.sender,
    required this.tint,
    this.size = 34,
  });

  final UserProfileEntity sender;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: tint.withValues(alpha: 0.25),
      border: Border.all(color: tint, width: 1.4),
      image: sender.avatarUrl != null && sender.avatarUrl!.startsWith('http')
          ? DecorationImage(
              image: NetworkImage(sender.avatarUrl!),
              fit: BoxFit.cover,
            )
          : null,
    ),
    alignment: Alignment.center,
    child: sender.avatarUrl != null && sender.avatarUrl!.startsWith('http')
        ? null
        : Text(
            sender.initial,
            style: TextStyle(
              fontSize: size * 0.44,
              fontWeight: FontWeight.w800,
              color: LiveColors.textPrimary,
            ),
          ),
  );
}
