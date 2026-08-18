import 'package:flutter/material.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';

/// The backdrop of a room in the feed.
///
/// Real thumbnails need a frame grab from the media service, which the current
/// backend does not produce. Until it does, each host gets a stable tinted
/// ground derived from their id, so the feed looks composed rather than empty
/// and a host keeps the same colour every time you see them.
class LiveCover extends StatelessWidget {
  const LiveCover({required this.stream, this.initialSize = 96, super.key});

  final LiveStreamEntity stream;
  final double initialSize;

  static const List<List<Color>> _grounds = <List<Color>>[
    <Color>[Color(0xFF3A1B5C), Color(0xFF0C0716)],
    <Color>[Color(0xFF13455C), Color(0xFF06131A)],
    <Color>[Color(0xFF5C3016), Color(0xFF190C05)],
    <Color>[Color(0xFF15542F), Color(0xFF05170C)],
    <Color>[Color(0xFF5C1638), Color(0xFF19060F)],
    <Color>[Color(0xFF2B2F5C), Color(0xFF080A19)],
  ];

  @override
  Widget build(BuildContext context) {
    if (stream.coverUrl != null && stream.coverUrl!.startsWith('http')) {
      return Image.network(
        stream.coverUrl!,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final List<Color> ground =
        _grounds[stream.host.id.hashCode.abs() % _grounds.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ground,
        ),
      ),
      child: Center(
        child: Text(
          stream.host.initial,
          style: TextStyle(
            fontSize: initialSize,
            fontWeight: FontWeight.w900,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        ),
      ),
    );
  }
}

/// The pulsing red LIVE pill used in the feed and inside a room.
class LivePill extends StatefulWidget {
  const LivePill({this.label = 'LIVE', this.compact = false, super.key});

  final String label;
  final bool compact;

  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill> with SingleTickerProviderStateMixin {
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
    padding: EdgeInsets.symmetric(
      horizontal: widget.compact ? 7 : 9,
      vertical: widget.compact ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: LiveColors.live,
      borderRadius: BorderRadius.circular(6),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: LiveColors.live.withValues(alpha: 0.45),
          blurRadius: 12,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FadeTransition(
          opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
          child: Container(
            width: widget.compact ? 5 : 6,
            height: widget.compact ? 5 : 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          widget.label,
          style: LiveTextStyles.badge.copyWith(fontSize: widget.compact ? 9.5 : 11),
        ),
      ],
    ),
  );
}

/// Circular avatar with a coloured ring, falling back to the display initial
/// when the account has no picture.
class LiveAvatar extends StatelessWidget {
  const LiveAvatar({
    required this.profile,
    this.size = 34,
    this.ring,
    this.ringWidth = 1.6,
    super.key,
  });

  final UserProfileEntity profile;
  final double size;
  final Color? ring;
  final double ringWidth;

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
        border: ring == null ? null : Border.all(color: ring!, width: ringWidth),
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(profile.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasImage
          ? null
          : Text(
              profile.initial,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
                color: LiveColors.textPrimary,
              ),
            ),
    );
  }
}
