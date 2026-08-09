import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/camera_controller_getx.dart';

abstract final class CameraSheets {
  static Future<void> showFps(CameraControllerGetX controller) {
    return Get.bottomSheet<void>(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111315),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Frame rate',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Only rates within the selected native mode are shown.',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => Wrap(
                    spacing: 10,
                    children: controller.availableFps.map((int fps) {
                      final bool selected = controller.selectedFps.value == fps;
                      return ChoiceChip(
                        label: Text('$fps FPS'),
                        selected: selected,
                        onSelected: (_) {
                          Get.back<void>();
                          controller.selectFps(fps);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  static Future<void> showSettings(CameraControllerGetX controller) {
    controller.refreshDeviceSafety();
    return Get.bottomSheet<void>(
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111315),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Obx(() {
              final camera = controller.selectedCamera.value;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera settings',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.storage_rounded,
                    label: 'Storage',
                    value: controller.storageText,
                  ),
                  _InfoRow(
                    icon: Icons.thermostat_rounded,
                    label: 'Thermal state',
                    value: controller.thermalState.value,
                  ),
                  _InfoRow(
                    icon: Icons.photo_size_select_large_rounded,
                    label: 'Maximum still size',
                    value: camera == null
                        ? 'Unknown'
                        : '${camera.photoWidth} × ${camera.photoHeight}',
                  ),
                  _InfoRow(
                    icon: Icons.video_stable_rounded,
                    label: 'Stabilization',
                    value: camera?.videoStabilizationSupported == true
                        ? 'Enabled when available'
                        : 'Unavailable',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.exposure_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Exposure  ${controller.exposureOffset.value.toStringAsFixed(1)} EV',
                      ),
                    ],
                  ),
                  Slider(
                    value: controller.exposureOffset.value.clamp(
                      controller.minExposure.value,
                      controller.maxExposure.value,
                    ),
                    min: controller.minExposure.value,
                    max:
                        controller.maxExposure.value <=
                            controller.minExposure.value
                        ? controller.minExposure.value + 0.1
                        : controller.maxExposure.value,
                    onChanged: controller.setExposure,
                  ),
                ],
              );
            }),
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: <Widget>[
        Icon(icon, size: 20, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.white70)),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
