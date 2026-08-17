import 'package:flutter/material.dart';

import '../../features/live/domain/entities/live_entities.dart';

/// The live surface's colour and type system.
///
/// It extends the camera app's existing palette rather than introducing a
/// second one: the same lime accent and the same near-black surfaces, plus the
/// few roles a gifting UI needs (live red, coin gold, diamond cyan).
abstract final class LiveColors {
  /// Video is the background, so the chrome sits on true black and the
  /// gradients do the separating.
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF151719);
  static const Color surfaceRaised = Color(0xFF1E2124);
  static const Color divider = Color(0xFF2A2E33);

  /// Carried over from the camera app so both halves feel like one product.
  static const Color accent = Color(0xFFD9EC35);
  static const Color accentInk = Color(0xFF101200);

  /// The recording red already used by the capture button.
  static const Color live = Color(0xFFFF365E);
  static const Color coin = Color(0xFFFFC93C);
  static const Color diamond = Color(0xFF5AD5FF);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x80FFFFFF);

  /// Tier colours drive the gift card border, the chat banner and the burst
  /// animation, so a legendary gift reads as expensive at a glance.
  static Color forTier(GiftTier tier) => switch (tier) {
    GiftTier.basic => const Color(0xFF8E97A3),
    GiftTier.rare => const Color(0xFF5AD5FF),
    GiftTier.epic => const Color(0xFFB06BFF),
    GiftTier.legendary => const Color(0xFFFFC93C),
  };

  static List<Color> tierGradient(GiftTier tier) => switch (tier) {
    GiftTier.basic => const <Color>[Color(0xFF3A4048), Color(0xFF22262B)],
    GiftTier.rare => const <Color>[Color(0xFF1B6E8C), Color(0xFF12303C)],
    GiftTier.epic => const <Color>[Color(0xFF5B2E8C), Color(0xFF2A1442)],
    GiftTier.legendary => const <Color>[Color(0xFFB8860B), Color(0xFF4A3505)],
  };

  /// Readability scrim behind the top and bottom chrome. Without it, white
  /// text disappears whenever the camera points at something bright.
  static const List<Color> topScrim = <Color>[Color(0xB3000000), Colors.transparent];
  static const List<Color> bottomScrim = <Color>[
    Color(0xF0000000),
    Color(0x99000000),
    Colors.transparent,
  ];
}

abstract final class LiveTextStyles {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: LiveColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: LiveColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: LiveColors.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: LiveColors.textSecondary,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: LiveColors.textPrimary,
    letterSpacing: 0.4,
  );
}

abstract final class LiveMetrics {
  static const double screenPadding = 14;
  static const double cardRadius = 18;
  static const double pillRadius = 99;
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
}

/// Compact number formatting used everywhere a counter is shown. A live room
/// has no room for "1284700 likes".
String formatCompact(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) {
    final double thousands = value / 1000;
    return '${thousands.toStringAsFixed(thousands < 10 ? 1 : 0)}K';
  }
  final double millions = value / 1000000;
  return '${millions.toStringAsFixed(millions < 10 ? 1 : 0)}M';
}

/// Elapsed broadcast time as mm:ss, or h:mm:ss once it passes an hour.
String formatDuration(Duration duration) {
  final int hours = duration.inHours;
  final String minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
