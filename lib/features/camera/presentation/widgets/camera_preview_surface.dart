import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../controllers/camera_controller_getx.dart';

/// Rendering adapter only. All camera commands remain behind domain use cases.
class CameraPreviewSurface extends StatelessWidget {
  const CameraPreviewSurface({required this.controller, super.key});

  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) {
    final session = controller.session.value;
    if (session?.usesNativePreview == true) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (Platform.isIOS)
              const UiKitView(viewType: 'apex_camera_preview')
            else
              const AndroidView(viewType: 'apex_camera_preview'),
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: (_) => controller.onScaleStart(),
              onScaleUpdate: (details) =>
                  controller.onScaleUpdate(details.scale),
              onTapUp: (details) => controller.focusAt(
                Offset(
                  details.localPosition.dx / constraints.maxWidth,
                  details.localPosition.dy / constraints.maxHeight,
                ),
                details.localPosition,
              ),
            ),
          ],
        ),
      );
    }
    final Object? handle = controller.previewHandle;
    if (handle is! CameraController || !handle.value.isInitialized) {
      return const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double screenRatio = constraints.maxWidth / constraints.maxHeight;
        final double previewRatio = handle.value.aspectRatio;
        final double scale = previewRatio < screenRatio
            ? screenRatio / previewRatio
            : previewRatio / screenRatio;
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => controller.onScaleStart(),
            onScaleUpdate: (details) => controller.onScaleUpdate(details.scale),
            onTapUp: (details) {
              final Offset normalized = Offset(
                details.localPosition.dx / constraints.maxWidth,
                details.localPosition.dy / constraints.maxHeight,
              );
              controller.focusAt(normalized, details.localPosition);
            },
            child: Transform.scale(
              scale: scale,
              child: Center(child: CameraPreview(handle)),
            ),
          ),
        );
      },
    );
  }
}
