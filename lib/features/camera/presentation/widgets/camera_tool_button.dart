import 'package:flutter/material.dart';

class CameraToolButton extends StatelessWidget {
  const CameraToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 60,
          height: 47,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                color: active ? const Color(0xFFD9EC35) : Colors.white,
                size: 21,
                shadows: const <Shadow>[
                  Shadow(color: Colors.black87, blurRadius: 7),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                value ?? label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: active ? const Color(0xFFD9EC35) : Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.black, blurRadius: 5),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
