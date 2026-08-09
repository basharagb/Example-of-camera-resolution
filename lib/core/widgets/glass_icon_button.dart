import 'dart:ui';

import 'package:flutter/material.dart';

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.active = false,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget child = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: active
              ? const Color(0xFFD9EC35).withValues(alpha: 0.92)
              : Colors.black.withValues(alpha: 0.35),
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                icon,
                size: size * 0.5,
                color: active ? Colors.black : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}
