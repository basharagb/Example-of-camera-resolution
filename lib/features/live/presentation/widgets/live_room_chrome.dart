import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/repositories/live_media_engine.dart';
import '../controllers/live_room_controller.dart';

/// The persistent header: who is broadcasting, how long for, how many people
/// are watching, and how healthy the connection is.
class LiveRoomHeader extends StatelessWidget {
  const LiveRoomHeader({
    required this.controller,
    required this.onClose,
    super.key,
  });

  final LiveRoomController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          LiveMetrics.screenPadding,
          8,
          LiveMetrics.screenPadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Flexible(child: _HostCard(controller: controller)),
                const SizedBox(width: 8),
                _ViewerPill(controller: controller),
                const SizedBox(width: 6),
                _CloseButton(onTap: onClose),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const _LiveBadge(),
                const SizedBox(width: 7),
                _ElapsedPill(controller: controller),
                const SizedBox(width: 7),
                _CoinPill(controller: controller),
                const Spacer(),
                _NetworkIndicator(controller: controller),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final LiveStreamEntity? stream = controller.stream.value;
    if (stream == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Avatar(profile: stream.host, size: 34),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  stream.host.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LiveTextStyles.caption.copyWith(
                    color: LiveColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  stream.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LiveTextStyles.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge();

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: LiveColors.live,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        const Text('LIVE', style: LiveTextStyles.badge),
      ],
    ),
  );
}

class _ViewerPill extends StatelessWidget {
  const _ViewerPill({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(
    () => _GlassPill(
      icon: Icons.remove_red_eye_rounded,
      label: formatCompact(controller.viewerCount.value),
    ),
  );
}

class _ElapsedPill extends StatelessWidget {
  const _ElapsedPill({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(
    () => _GlassPill(
      icon: Icons.schedule_rounded,
      label: formatDuration(controller.elapsed.value),
    ),
  );
}

class _CoinPill extends StatelessWidget {
  const _CoinPill({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(
    () => _GlassPill(
      emoji: '🪙',
      label: formatCompact(controller.totalCoins.value),
      tint: LiveColors.coin,
    ),
  );
}

/// Uplink quality, shown to the host only. A viewer can do nothing about the
/// broadcaster's connection, so surfacing it to them would be noise.
class _NetworkIndicator extends StatelessWidget {
  const _NetworkIndicator({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    if (!controller.isHost) {
      return const SizedBox.shrink();
    }
    final LiveNetworkQuality quality = controller.networkQuality.value;
    final (Color color, IconData icon, String label) = switch (quality) {
      LiveNetworkQuality.excellent ||
      LiveNetworkQuality.good => (
        LiveColors.accent,
        Icons.signal_cellular_alt_rounded,
        'Good',
      ),
      LiveNetworkQuality.poor => (
        LiveColors.coin,
        Icons.signal_cellular_alt_2_bar_rounded,
        'Fair',
      ),
      LiveNetworkQuality.bad ||
      LiveNetworkQuality.down => (
        LiveColors.live,
        Icons.signal_cellular_alt_1_bar_rounded,
        'Weak',
      ),
      LiveNetworkQuality.unknown => (
        LiveColors.textMuted,
        Icons.signal_cellular_alt_rounded,
        '',
      ),
    };
    if (quality == LiveNetworkQuality.unknown) {
      return const SizedBox.shrink();
    }
    return _GlassPill(icon: icon, label: label, tint: color);
  });
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    this.icon,
    this.emoji,
    required this.label,
    this.tint = LiveColors.textPrimary,
  });

  final IconData? icon;
  final String? emoji;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: Colors.black.withValues(alpha: 0.36),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (emoji != null)
              Text(emoji!, style: const TextStyle(fontSize: 12))
            else if (icon != null)
              Icon(icon, size: 13, color: tint),
            if (label.isNotEmpty) ...<Widget>[
              const SizedBox(width: 5),
              Text(
                label,
                style: LiveTextStyles.caption.copyWith(
                  color: tint,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
    ),
  );
}

/// The in-room podium of top gifters, ordered highest first.
class TopGiftersBar extends StatelessWidget {
  const TopGiftersBar({required this.controller, super.key});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final List<LeaderboardEntryEntity> entries = controller.topGifters;
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: LiveMetrics.screenPadding),
        itemCount: entries.length,
        separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 7),
        itemBuilder: (BuildContext context, int index) {
          final LeaderboardEntryEntity entry = entries[index];
          // The top three get a metal; everyone else gets a neutral chip.
          final Color tint = switch (entry.rank) {
            1 => const Color(0xFFFFD700),
            2 => const Color(0xFFC0C6CE),
            3 => const Color(0xFFCD7F32),
            _ => LiveColors.textMuted,
          };
          return Container(
            padding: const EdgeInsets.fromLTRB(3, 3, 11, 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
              border: Border.all(color: tint.withValues(alpha: 0.55)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Avatar(profile: entry.user, size: 26, ring: tint),
                const SizedBox(width: 7),
                Text(
                  formatCompact(entry.totalCoins),
                  style: LiveTextStyles.caption.copyWith(
                    color: tint,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  });
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile, required this.size, this.ring});

  final UserProfileEntity profile;
  final double size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final bool hasImage =
        profile.avatarUrl != null && profile.avatarUrl!.startsWith('http');
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: LiveColors.surfaceRaised,
        border: Border.all(color: ring ?? LiveColors.accent, width: 1.4),
        image: hasImage
            ? DecorationImage(image: NetworkImage(profile.avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              profile.initial,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
                color: LiveColors.textPrimary,
              ),
            ),
    );
  }
}
