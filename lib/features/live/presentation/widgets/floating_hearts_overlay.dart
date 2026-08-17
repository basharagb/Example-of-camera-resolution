import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The floating hearts that rise from the like button.
///
/// Each heart is a short-lived particle driven by one shared ticker rather than
/// its own controller: a burst of taps can put dozens on screen at once, and
/// one animation per heart would thrash.
class FloatingHeartsOverlay extends StatefulWidget {
  const FloatingHeartsOverlay({
    required this.burstCount,
    this.maxHearts = 40,
    super.key,
  });

  /// Monotonic counter. Each increment spawns one heart.
  final int burstCount;

  /// Ceiling on simultaneous particles, so a spam of taps cannot degrade the
  /// frame rate or cover the video.
  final int maxHearts;

  @override
  State<FloatingHeartsOverlay> createState() => _FloatingHeartsOverlayState();
}

class _FloatingHeartsOverlayState extends State<FloatingHeartsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(days: 1),
  )..repeat();

  final List<_Heart> _hearts = <_Heart>[];
  final math.Random _random = math.Random();
  int _lastBurstCount = 0;

  static const List<Color> _palette = <Color>[
    Color(0xFFFF365E),
    Color(0xFFFF6B9D),
    Color(0xFFFFC93C),
    Color(0xFF5AD5FF),
    Color(0xFFD9EC35),
  ];

  @override
  void didUpdateWidget(FloatingHeartsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int delta = widget.burstCount - _lastBurstCount;
    _lastBurstCount = widget.burstCount;
    if (delta <= 0) {
      return;
    }
    // A burst arriving as one number still looks like individual taps.
    for (int index = 0; index < math.min(delta, 12); index++) {
      _spawn();
    }
  }

  void _spawn() {
    if (_hearts.length >= widget.maxHearts) {
      _hearts.removeAt(0);
    }
    _hearts.add(
      _Heart(
        bornAt: DateTime.now(),
        lifetime: Duration(milliseconds: 2200 + _random.nextInt(1400)),
        horizontalSeed: _random.nextDouble(),
        drift: (_random.nextDouble() - 0.5) * 90,
        scale: 0.75 + _random.nextDouble() * 0.6,
        color: _palette[_random.nextInt(_palette.length)],
        wobblePhase: _random.nextDouble() * math.pi * 2,
      ),
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ticker,
        builder: (BuildContext context, _) {
          final DateTime now = DateTime.now();
          _hearts.removeWhere(
            (_Heart heart) => now.difference(heart.bornAt) > heart.lifetime,
          );
          return CustomPaint(
            painter: _HeartsPainter(hearts: List<_Heart>.of(_hearts), now: now),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Heart {
  _Heart({
    required this.bornAt,
    required this.lifetime,
    required this.horizontalSeed,
    required this.drift,
    required this.scale,
    required this.color,
    required this.wobblePhase,
  });

  final DateTime bornAt;
  final Duration lifetime;
  final double horizontalSeed;
  final double drift;
  final double scale;
  final Color color;
  final double wobblePhase;
}

class _HeartsPainter extends CustomPainter {
  _HeartsPainter({required this.hearts, required this.now});

  final List<_Heart> hearts;
  final DateTime now;

  @override
  void paint(Canvas canvas, Size size) {
    for (final _Heart heart in hearts) {
      final double progress =
          now.difference(heart.bornAt).inMilliseconds / heart.lifetime.inMilliseconds;
      if (progress < 0 || progress > 1) {
        continue;
      }

      // Rise with an ease-out so hearts decelerate near the top.
      final double eased = Curves.easeOutCubic.transform(progress);
      final double startX = size.width * (0.55 + heart.horizontalSeed * 0.35);
      final double wobble =
          math.sin(progress * math.pi * 3 + heart.wobblePhase) * 18;
      final double x = startX + wobble + heart.drift * eased;
      final double y = size.height - eased * (size.height * 0.62);

      // Pop in over the first tenth, hold, then fade over the last third.
      final double opacity = progress < 0.1
          ? progress / 0.1
          : progress > 0.65
          ? (1 - progress) / 0.35
          : 1;
      final double scale =
          heart.scale * (progress < 0.12 ? Curves.easeOutBack.transform(progress / 0.12) : 1);

      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      _paintHeart(canvas, heart.color.withValues(alpha: opacity.clamp(0, 1)));
      canvas.restore();
    }
  }

  void _paintHeart(Canvas canvas, Color color) {
    final Paint paint = Paint()..color = color;
    final Path path = Path()
      ..moveTo(0, 6)
      ..cubicTo(-14, -6, -10, -18, 0, -10)
      ..cubicTo(10, -18, 14, -6, 0, 6)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartsPainter oldDelegate) => true;
}
