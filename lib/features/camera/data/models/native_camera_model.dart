import '../../domain/entities/camera_device_entity.dart';
import '../../domain/entities/camera_enums.dart';
import '../../domain/entities/camera_resolution_entity.dart';

class NativeCameraModel {
  const NativeCameraModel({required this.entity});
  final CameraDeviceEntity entity;

  factory NativeCameraModel.fromMap(Map<Object?, Object?> map) {
    final List<CameraResolutionEntity> resolutions =
        (map['resolutions'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map(
              (resolution) => CameraResolutionEntity(
                width: _int(resolution['width']),
                height: _int(resolution['height']),
                maxFps: _int(resolution['maxFps']).clamp(1, 240),
                supportedFps:
                    (resolution['supportedFps'] as List<Object?>? ??
                            const <Object?>[])
                        .whereType<num>()
                        .map((value) => value.round())
                        .where((value) => value > 0)
                        .toSet()
                        .toList()
                      ..sort(),
                hdrSupported: resolution['hdrSupported'] == true,
              ),
            )
            .where(
              (resolution) => resolution.width > 0 && resolution.height > 0,
            )
            .toList();
    final String direction = map['lensDirection']?.toString() ?? 'external';
    return NativeCameraModel(
      entity: CameraDeviceEntity(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Camera',
        lensDirection: switch (direction) {
          'front' => CameraLensDirection.front,
          'back' => CameraLensDirection.back,
          _ => CameraLensDirection.external,
        },
        lensType: map['lensType']?.toString() ?? 'Wide',
        sensorOrientation: _int(map['sensorOrientation']),
        focalLengths:
            (map['focalLengths'] as List<Object?>? ?? const <Object?>[])
                .whereType<num>()
                .map((value) => value.toDouble())
                .toList(),
        flashSupported: map['flashSupported'] == true,
        videoStabilizationSupported: map['videoStabilizationSupported'] == true,
        opticalStabilizationSupported:
            map['opticalStabilizationSupported'] == true,
        resolutions: resolutions,
        photoWidth: _int(map['photoWidth']),
        photoHeight: _int(map['photoHeight']),
      ),
    );
  }

  static int _int(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;
}
