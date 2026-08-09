import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/glass_icon_button.dart';
import '../../domain/entities/camera_device_entity.dart';
import '../../domain/entities/camera_enums.dart';
import '../../domain/entities/media_result_entity.dart';
import '../controllers/camera_controller_getx.dart';
import '../widgets/camera_preview_surface.dart';
import '../widgets/camera_sheets.dart';
import '../widgets/camera_tool_button.dart';
import '../widgets/capture_button.dart';
import '../widgets/resolution_bottom_sheet.dart';

class CameraPage extends GetView<CameraControllerGetX> {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Obx(() {
            if (!controller.isInitialized.value) {
              return const ColoredBox(color: Colors.black);
            }
            return CameraPreviewSurface(controller: controller);
          }),
          const _CameraGradients(),
          _TopControls(controller: controller),
          _RightToolbar(controller: controller),
          _FocusIndicator(controller: controller),
          _CenterStatus(controller: controller),
          _BottomControls(controller: controller),
          _InitializationOverlay(controller: controller),
        ],
      ),
    );
  }
}

class _CameraGradients extends StatelessWidget {
  const _CameraGradients();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Column(
      children: <Widget>[
        Container(
          height: 175,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xA8000000), Colors.transparent],
            ),
          ),
        ),
        const Spacer(),
        Container(
          height: 330,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: <Color>[
                Color(0xF0000000),
                Color(0xAA000000),
                Colors.transparent,
              ],
              stops: <double>[0, 0.55, 1],
            ),
          ),
        ),
      ],
    ),
  );
}

class _TopControls extends StatelessWidget {
  const _TopControls({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close camera',
                  onTap: controller.closeApp,
                ),
                const Spacer(),
                Material(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(99),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(99),
                    onTap: () => Get.snackbar(
                      'Add sound',
                      'Sound selection is a clean integration point for your media service.',
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.music_note_rounded, size: 17),
                          SizedBox(width: 5),
                          Text(
                            'Add sound',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Obx(
                  () => GlassIconButton(
                    icon: Icons.cameraswitch_rounded,
                    tooltip: 'Switch camera',
                    onTap: controller.controlsLocked
                        ? null
                        : controller.switchCamera,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Obx(() {
              final resolution = controller.selectedResolution.value;
              if (resolution == null) return const SizedBox.shrink();
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _StatusBadge(
                    text: resolution.displayLabel,
                    strong: true,
                    onTap: () => ResolutionBottomSheet.show(controller),
                  ),
                  const SizedBox(width: 6),
                  _StatusBadge(
                    text: '${controller.selectedFps.value} FPS',
                    onTap: () => CameraSheets.showFps(controller),
                  ),
                  if (controller.hdrAvailable) ...<Widget>[
                    const SizedBox(width: 6),
                    _StatusBadge(
                      text: controller.hdrEnabled.value
                          ? 'HDR ON'
                          : 'HDR AVAIL',
                      strong: controller.hdrEnabled.value,
                      onTap: controller.toggleHdr,
                    ),
                  ],
                ],
              );
            }),
            const SizedBox(height: 5),
            Obx(
              () => Text(
                controller.previewDimensions,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, this.strong = false, this.onTap});
  final String text;
  final bool strong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: strong ? const Color(0xFFD9EC35) : Colors.black45,
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          text,
          style: TextStyle(
            color: strong ? Colors.black : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ),
  );
}

class _RightToolbar extends StatelessWidget {
  const _RightToolbar({required this.controller});
  final CameraControllerGetX controller;

  void _placeholder(String feature) {
    Get.snackbar(
      feature,
      '$feature is intentionally isolated as a future real-time processing module.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 3,
      top: 142,
      bottom: 288,
      child: Obx(() {
        final String flash = controller.flashMode.value.name;
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: <Widget>[
              CameraToolButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip',
                onTap: controller.switchCamera,
              ),
              // TODO(camera-effects): connect a timestamp-preserving speed pipeline.
              CameraToolButton(
                icon: Icons.speed_rounded,
                label: 'Speed',
                value: '1×',
                onTap: () => _placeholder('Recording speed'),
              ),
              // TODO(camera-effects): add device-accelerated beauty processing without touching original captures.
              CameraToolButton(
                icon: Icons.auto_awesome_rounded,
                label: 'Beauty',
                onTap: () => _placeholder('Beauty'),
              ),
              // TODO(camera-effects): add GPU filters as a non-destructive preview/render stage.
              CameraToolButton(
                icon: Icons.filter_vintage_rounded,
                label: 'Filters',
                onTap: () => _placeholder('Filters'),
              ),
              CameraToolButton(
                icon: Icons.timer_outlined,
                label: 'Timer',
                value: controller.timerSeconds.value == 0
                    ? 'Timer'
                    : '${controller.timerSeconds.value}s',
                active: controller.timerSeconds.value > 0,
                onTap: controller.cycleTimer,
              ),
              CameraToolButton(
                icon: _flashIcon(controller.flashMode.value),
                label: 'Flash',
                value: flash == 'always' ? 'On' : flash.capitalizeFirst,
                active: controller.flashMode.value != CameraFlashMode.off,
                onTap: controller.cycleFlash,
              ),
              CameraToolButton(
                icon: Icons.high_quality_rounded,
                label: 'Quality',
                value: controller.selectedResolution.value?.displayLabel,
                active: true,
                onTap: () => ResolutionBottomSheet.show(controller),
              ),
              CameraToolButton(
                icon: Icons.slow_motion_video_rounded,
                label: 'FPS',
                value: '${controller.selectedFps.value}',
                onTap: () => CameraSheets.showFps(controller),
              ),
              CameraToolButton(
                icon: Icons.hdr_on_rounded,
                label: 'HDR',
                value: controller.hdrEnabled.value
                    ? 'On'
                    : controller.hdrAvailable
                    ? 'Available'
                    : 'Off',
                active: controller.hdrEnabled.value,
                onTap: controller.toggleHdr,
              ),
              CameraToolButton(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: () => CameraSheets.showSettings(controller),
              ),
            ],
          ),
        );
      }),
    );
  }

  IconData _flashIcon(CameraFlashMode mode) => switch (mode) {
    CameraFlashMode.off => Icons.flash_off_rounded,
    CameraFlashMode.auto => Icons.flash_auto_rounded,
    CameraFlashMode.always => Icons.flash_on_rounded,
    CameraFlashMode.torch => Icons.highlight_rounded,
  };
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final Offset? point = controller.focusPoint.value;
    if (!controller.focusVisible.value || point == null) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: point.dx - 28,
      top: point.dy - 28,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.35, end: 1),
          duration: const Duration(milliseconds: 230),
          builder: (_, double scale, Widget? child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD9EC35), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 2.5,
                backgroundColor: Color(0xFFD9EC35),
              ),
            ),
          ),
        ),
      ),
    );
  });
}

class _CenterStatus extends StatelessWidget {
  const _CenterStatus({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => Center(
    child: Obx(() {
      if (controller.countdown.value > 0) {
        return Text(
          '${controller.countdown.value}',
          style: const TextStyle(
            fontSize: 86,
            fontWeight: FontWeight.w900,
            shadows: <Shadow>[Shadow(blurRadius: 20)],
          ),
        );
      }
      if (!controller.isRecording.value) return const SizedBox.shrink();
      return Transform.translate(
        offset: const Offset(0, -165),
        child: Material(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFFFF365E),
                ),
                const SizedBox(width: 7),
                Text(
                  controller.recordingTimeText,
                  style: const TextStyle(
                    color: Color(0xFFFF6A84),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  controller.estimatedRecordingSize,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 5),
        child: Obx(
          () => Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _LensSelector(controller: controller),
              const SizedBox(height: 7),
              _ZoomSelector(controller: controller),
              AnimatedSize(
                duration: AppConstants.controlsAnimationDuration,
                child: controller.selectedMode.value == CameraMode.video
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _DurationSelector(controller: controller),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              _ModeSelector(controller: controller),
              const SizedBox(height: 7),
              _CaptureRow(controller: controller),
              const SizedBox(height: 7),
              const _BottomTabs(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LensSelector extends StatelessWidget {
  const _LensSelector({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 27,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 70),
      itemCount: controller.availableCameras.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (BuildContext context, int index) {
        final CameraDeviceEntity camera = controller.availableCameras[index];
        final bool selected = controller.selectedCamera.value?.id == camera.id;
        return GestureDetector(
          onTap: () => controller.selectCamera(camera),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.black38,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              camera.displayName,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ZoomSelector extends StatelessWidget {
  const _ZoomSelector({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) {
    final List<double> choices =
        <double>{
              controller.minZoom.value,
              1,
              if (controller.maxZoom.value >= 2) 2,
              if (controller.maxZoom.value >= 5) 5,
            }
            .where(
              (value) =>
                  value >= controller.minZoom.value &&
                  value <= controller.maxZoom.value,
            )
            .toList()
          ..sort();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: choices.map((double value) {
        final bool selected = (controller.zoomLevel.value - value).abs() < 0.18;
        return GestureDetector(
          onTap: () => controller.selectZoom(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 34 : 29,
            height: selected ? 34 : 29,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? const Color(0xFFD9EC35) : Colors.black45,
            ),
            child: Text(
              '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}×',
              style: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DurationSelector extends StatelessWidget {
  const _DurationSelector({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: CaptureDurationOption.values.map((option) {
      final bool selected = controller.durationMode.value == option;
      return GestureDetector(
        onTap: () => controller.selectDuration(option),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Text(
            option.label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white54,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: CameraMode.values.map((mode) {
      final bool selected = controller.selectedMode.value == mode;
      return GestureDetector(
        onTap: () => controller.selectMode(mode),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: selected ? const Color(0xFFD9EC35) : Colors.white60,
            fontSize: selected ? 14 : 12,
            fontWeight: FontWeight.w800,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
            child: Text(mode == CameraMode.photo ? 'PHOTO' : 'VIDEO'),
          ),
        ),
      );
    }).toList(),
  );
}

class _CaptureRow extends StatelessWidget {
  const _CaptureRow({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 35),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _GalleryThumbnail(media: controller.lastMedia.value),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CaptureButton(
              mode: controller.selectedMode.value,
              isRecording: controller.isRecording.value,
              isBusy: controller.controlsLocked,
              onTap: controller.onCapturePressed,
            ),
            if (controller.isRecording.value) ...<Widget>[
              const SizedBox(width: 10),
              GlassIconButton(
                icon: controller.isPaused.value
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                size: 38,
                active: controller.isPaused.value,
                onTap: controller.togglePause,
              ),
            ],
          ],
        ),
        GestureDetector(
          onTap: controller.requestGalleryForUpload,
          child: const SizedBox(
            width: 48,
            child: Column(
              children: <Widget>[
                Icon(Icons.upload_rounded, size: 25),
                SizedBox(height: 2),
                Text(
                  'Upload',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _GalleryThumbnail extends StatelessWidget {
  const _GalleryThumbnail({required this.media});
  final MediaResultEntity? media;

  @override
  Widget build(BuildContext context) {
    Widget child = const Icon(
      Icons.photo_library_outlined,
      size: 22,
      color: Colors.white70,
    );
    if (media != null) {
      child = media!.type == CapturedMediaType.photo
          ? Image.file(
              File(media!.path),
              cacheWidth: 128,
              cacheHeight: 128,
              fit: BoxFit.cover,
            )
          : const ColoredBox(
              color: Color(0xFF272A2D),
              child: Center(
                child: Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
            );
    }
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white30),
      ),
      child: child,
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs();

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: <Widget>[
      _BottomTab(label: 'Camera', selected: true),
      _BottomTab(label: 'Templates'),
      _BottomTab(label: 'LIVE'),
    ],
  );
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    child: Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white38,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? const Color(0xFFD9EC35) : Colors.transparent,
          ),
        ),
      ],
    ),
  );
}

class _InitializationOverlay extends StatelessWidget {
  const _InitializationOverlay({required this.controller});
  final CameraControllerGetX controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    if (controller.isInitializing.value) {
      return ColoredBox(
        color: Colors.black45,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text(
                controller.selectedResolution.value == null
                    ? 'Inspecting real camera modes…'
                    : 'Opening ${controller.selectedResolution.value!.displayLabel}…',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    final String? error = controller.errorMessage.value;
    if (error == null || controller.isInitialized.value) {
      return const SizedBox.shrink();
    }
    return ColoredBox(
      color: const Color(0xFF090A0B),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.no_photography_rounded,
                  size: 58,
                  color: Colors.white54,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Camera unavailable',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: controller.openApplicationSettings,
                      child: const Text('Settings'),
                    ),
                    FilledButton.icon(
                      onPressed: controller.retry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  });
}
