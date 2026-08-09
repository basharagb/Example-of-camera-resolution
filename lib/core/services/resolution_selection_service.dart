import '../../features/camera/domain/entities/camera_resolution_entity.dart';

/// Converts the raw native mode table into modes the Flutter camera backends
/// can target exactly (highest, UHD, FHD, HD, SD). Unsupported labels are never
/// invented or shown.
class ResolutionSelectionService {
  const ResolutionSelectionService();

  List<CameraResolutionEntity> selectStableProfiles(
    List<CameraResolutionEntity> raw,
  ) {
    if (raw.isEmpty) return const <CameraResolutionEntity>[];
    final List<CameraResolutionEntity> modes = List<CameraResolutionEntity>.of(
      raw,
    )..sort((a, b) => b.pixels.compareTo(a.pixels));
    final CameraResolutionEntity highest = modes.first;
    final List<CameraResolutionEntity> videoModes = modes
        .where((mode) => mode.isVideoAspect && mode.maxFps >= 24)
        .toList();
    final CameraResolutionEntity recommended = videoModes.isEmpty
        ? highest
        : videoModes.first;
    final List<CameraResolutionEntity> selected = <CameraResolutionEntity>[
      recommended,
    ];
    if (highest != recommended) selected.add(highest);

    void addClosest(int width, int height, int tolerance) {
      final List<CameraResolutionEntity> candidates = modes.where((mode) {
        return (mode.longEdge - width).abs() <= tolerance &&
            (mode.shortEdge - height).abs() <= tolerance;
      }).toList();
      if (candidates.isEmpty) return;
      candidates.sort((a, b) {
        final int aDistance =
            (a.longEdge - width).abs() + (a.shortEdge - height).abs();
        final int bDistance =
            (b.longEdge - width).abs() + (b.shortEdge - height).abs();
        return aDistance.compareTo(bDistance);
      });
      if (!selected.contains(candidates.first)) selected.add(candidates.first);
    }

    addClosest(7680, 4320, 500);
    addClosest(3840, 2160, 260);
    // 2K can be selected safely only when it is the camera's highest profile;
    // camera backends do not expose a portable QHD preset.
    if (highest.label == '2K' && !selected.contains(highest)) {
      selected.add(highest);
    }
    addClosest(1920, 1080, 180);
    addClosest(1280, 720, 130);
    addClosest(720, 480, 110);

    return <CameraResolutionEntity>[
      for (int index = 0; index < selected.length; index++)
        CameraResolutionEntity(
          width: selected[index].width,
          height: selected[index].height,
          maxFps: selected[index].maxFps,
          supportedFps: selected[index].supportedFps,
          hdrSupported: selected[index].hdrSupported,
          recommended: index == 0,
        ),
    ];
  }
}
