import 'package:flutter/material.dart';

import '../../domain/entities/camera_enums.dart';

class CaptureButton extends StatelessWidget {
  const CaptureButton({
    required this.mode,
    required this.isRecording,
    required this.isBusy,
    required this.onTap,
    super.key,
  });

  final CameraMode mode;
  final bool isRecording;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool video = mode == CameraMode.video;
    final Color color = video ? const Color(0xFFFF365E) : Colors.white;
    return Semantics(
      button: true,
      label: isRecording
          ? 'Stop recording'
          : video
          ? 'Start recording'
          : 'Take photo',
      child: GestureDetector(
        onTap: isBusy ? null : onTap,
        child: AnimatedOpacity(
          opacity: isBusy ? 0.5 : 1,
          duration: const Duration(milliseconds: 180),
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              color: Colors.black26,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: isRecording ? 29 : 62,
                height: isRecording ? 29 : 62,
                decoration: BoxDecoration(
                  color: color,
                  shape: isRecording ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isRecording ? BorderRadius.circular(7) : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
