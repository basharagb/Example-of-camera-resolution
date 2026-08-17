import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../data/datasources/agora_media_engine.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_room_controller.dart';

/// The video layer of a room.
///
/// It renders the host's local camera when broadcasting and the remote track
/// when watching. When the backend is running without vendor credentials it
/// shows a labelled placeholder instead: an honest "no video configured" reads
/// better than a black rectangle that looks like a bug.
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

/// Stand-in shown when `RTC_PROVIDER=mock`. Everything except the video works,
/// which is what makes the room testable without a vendor account.
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
                'Video preview unavailable in this build',
                style: LiveTextStyles.caption.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
