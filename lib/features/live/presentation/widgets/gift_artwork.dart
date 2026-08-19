import 'package:flutter/material.dart';

import '../../domain/entities/live_entities.dart';

class GiftArtwork extends StatelessWidget {
  const GiftArtwork({required this.gift, this.size = 56, this.fit = BoxFit.contain, super.key});

  final GiftEntity gift;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final String? source = gift.artwork;
    if (source == null || source.isEmpty) return _fallback();
    final Widget image;
    if (source.startsWith('http://') || source.startsWith('https://')) {
      image = Image.network(source, fit: fit, errorBuilder: (_, __, ___) => _fallback());
    } else {
      final String asset = source.replaceFirst('asset://', '');
      image = Image.asset(asset, fit: fit, errorBuilder: (_, __, ___) => _fallback());
    }
    return SizedBox(width: size, height: size, child: image);
  }

  Widget _fallback() => SizedBox(
    width: size,
    height: size,
    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white),
  );
}
