import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:camera/camera.dart' as camera;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../data/datasources/agora_media_engine.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_room_controller.dart';

/// The video layer of a room.
///
/// It renders the host's local camera when broadcasting and the remote track
/// when watching. A mock backend cannot deliver a remote track, but the host
/// still gets a real local camera preview for framing and camera controls.
class LiveVideoSurface extends StatelessWidget {
  const LiveVideoSurface({required this.controller, super.key});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final RtcCredentialsEntity? credentials = controller.rtc.value;

      if (credentials == null) {
        return const ColoredBox(color: LiveColors.background);
      }
      if (credentials.isMock) {
        if (controller.isHost) {
          if (!controller.isCameraOn.value) {
            return const _CameraOffSurface();
          }
          if (!controller.isVideoReady.value) {
            return const _LoadingSurface(label: 'Starting camera');
          }

          final camera.CameraController? preview =
              (controller.mediaEngine is AgoraMediaEngine)
              ? (controller.mediaEngine as AgoraMediaEngine)
                    .localPreviewController
              : null;
          if (preview != null && preview.value.isInitialized) {
            return _MockHostSurface(preview: preview);
          }
        }
        return _MockSurface(controller: controller);
      }

      final RtcEngine? engine =
          (controller.mediaEngine is AgoraMediaEngine)
          ? (controller.mediaEngine as AgoraMediaEngine).rawEngine
          : null;

      if (engine == null) {
        return const _LoadingSurface(label: 'Starting camera');
      }

      if (controller.isHost) {
        if (!controller.isCameraOn.value) {
          return const _CameraOffSurface();
        }
        return AgoraVideoView(
          controller: VideoViewController(
            rtcEngine: engine,
            canvas: const VideoCanvas(uid: 0),
          ),
        );
      }

      final int remoteUid = controller.hostRemoteUid.value;
      if (remoteUid == 0) {
        return const _LoadingSurface(label: 'Connecting to the host');
      }

      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(uid: remoteUid),
          connection: RtcConnection(channelId: credentials.channelName),
        ),
      );
    });
  }
}

/// Full-screen local preview for a host using a mock RTC backend. The badge is
/// intentional: the camera is real, but without an RTC provider these frames
/// are not being sent to another device.
class _MockHostSurface extends StatelessWidget {
  const _MockHostSurface({required this.preview});

  final camera.CameraController preview;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: <Widget>[
      LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double previewRatio = 1 / preview.value.aspectRatio;
          final double screenRatio =
              constraints.maxWidth / constraints.maxHeight;
          final double coverScale = previewRatio > screenRatio
              ? previewRatio / screenRatio
              : screenRatio / previewRatio;

          return ClipRect(
            child: Transform.scale(
              scale: coverScale,
              child: Center(child: camera.CameraPreview(preview)),
            ),
          );
        },
      ),
      Positioned(
        left: 24,
        right: 24,
        bottom: 132,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                'Local preview only • Connect Agora to broadcast',
                textAlign: TextAlign.center,
                style: LiveTextStyles.caption.copyWith(fontSize: 10.5),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _LoadingSurface extends StatelessWidget {
  const _LoadingSurface({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: LiveColors.background,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: LiveColors.accent),
          ),
          const SizedBox(height: 16),
          Text(label, style: LiveTextStyles.caption),
        ],
      ),
    ),
  );
}

class _CameraOffSurface extends StatelessWidget {
  const _CameraOffSurface();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: LiveColors.surface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.videocam_off_rounded, size: 44, color: LiveColors.textMuted),
          const SizedBox(height: 12),
          Text('Your camera is off', style: LiveTextStyles.caption),
        ],
      ),
    ),
  );
}

/// Stand-in shown to mock-room viewers, or when a host's local preview fails.
class _MockSurface extends StatelessWidget {
  const _MockSurface({required this.controller});

  final LiveRoomController controller;

  @override
  Widget build(BuildContext context) {
    final String hostName = controller.stream.value?.host.displayName ?? 'Host';
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF1B1F24), Color(0xFF0A0C0E)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LiveColors.accent.withValues(alpha: 0.12),
                border: Border.all(color: LiveColors.accent.withValues(alpha: 0.5), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                hostName.isEmpty ? '?' : hostName.substring(0, 1).toUpperCase(),
                style: LiveTextStyles.displayLarge.copyWith(
                  fontSize: 40,
                  color: LiveColors.accent,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(hostName, style: LiveTextStyles.title),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                border: Border.all(color: LiveColors.divider),
              ),
              child: Text(
                controller.isHost
                    ? 'Camera preview could not start'
                    : 'Live video needs Agora to be connected',
                style: LiveTextStyles.caption.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
