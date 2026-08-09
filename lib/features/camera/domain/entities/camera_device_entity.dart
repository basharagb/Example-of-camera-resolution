import 'camera_enums.dart';
import 'camera_resolution_entity.dart';

class CameraDeviceEntity {
  const CameraDeviceEntity({
    required this.id,
    required this.name,
    required this.lensDirection,
    required this.lensType,
    required this.sensorOrientation,
    required this.focalLengths,
    required this.flashSupported,
    required this.videoStabilizationSupported,
    required this.opticalStabilizationSupported,
    required this.resolutions,
    required this.photoWidth,
    required this.photoHeight,
  });

  final String id;
  final String name;
  final CameraLensDirection lensDirection;
  final String lensType;
  final int sensorOrientation;
  final List<double> focalLengths;
  final bool flashSupported;
  final bool videoStabilizationSupported;
  final bool opticalStabilizationSupported;
  final List<CameraResolutionEntity> resolutions;
  final int photoWidth;
  final int photoHeight;

  bool get isFront => lensDirection == CameraLensDirection.front;
  String get displayName => isFront ? 'Front' : lensType;
}
