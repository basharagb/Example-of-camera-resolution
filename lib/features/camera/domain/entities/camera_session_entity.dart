class CameraSessionEntity {
  const CameraSessionEntity({
    required this.previewHandle,
    required this.previewWidth,
    required this.previewHeight,
    required this.minZoom,
    required this.maxZoom,
    required this.minExposure,
    required this.maxExposure,
    required this.usesNativePreview,
    required this.hdrActive,
  });

  final Object previewHandle;
  final double previewWidth;
  final double previewHeight;
  final double minZoom;
  final double maxZoom;
  final double minExposure;
  final double maxExposure;
  final bool usesNativePreview;
  final bool hdrActive;

  double get aspectRatio => previewWidth / previewHeight;
}
