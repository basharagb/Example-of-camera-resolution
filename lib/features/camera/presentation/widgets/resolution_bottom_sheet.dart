import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/camera_resolution_entity.dart';
import '../controllers/camera_controller_getx.dart';

class ResolutionBottomSheet extends StatelessWidget {
  const ResolutionBottomSheet({required this.controller, super.key});
  final CameraControllerGetX controller;

  static Future<void> show(CameraControllerGetX controller) =>
      Get.bottomSheet<void>(
        ResolutionBottomSheet(controller: controller),
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF111315),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const _SheetHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 2, 20, 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Real output resolution',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Only modes declared by this physical camera are listed.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Obx(
                () => ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  itemCount: controller.availableResolutions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final CameraResolutionEntity resolution =
                        controller.availableResolutions[index];
                    final bool selected =
                        controller.selectedResolution.value == resolution;
                    return Material(
                      color: selected
                          ? const Color(0xFFD9EC35).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Get.back<void>();
                          controller.selectResolution(resolution);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 54,
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFD9EC35)
                                      : Colors.white10,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  resolution.displayLabel,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Row(
                                      children: <Widget>[
                                        Text(
                                          resolution.dimensions,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (resolution.recommended) ...<Widget>[
                                          const SizedBox(width: 8),
                                          const _Badge(text: 'HIGHEST'),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Up to ${resolution.maxFps} FPS${resolution.hdrSupported ? '  •  HDR available' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: selected
                                    ? const Color(0xFFD9EC35)
                                    : Colors.white30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 4,
    margin: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(99),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFD9EC35),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 8,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}
