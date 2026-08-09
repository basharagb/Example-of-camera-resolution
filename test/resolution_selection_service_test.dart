import 'package:apex_camera/core/services/resolution_selection_service.dart';
import 'package:apex_camera/features/camera/domain/entities/camera_resolution_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ResolutionSelectionService service = ResolutionSelectionService();

  test('keeps real stable profiles in descending order', () {
    final List<CameraResolutionEntity> result = service
        .selectStableProfiles(const <CameraResolutionEntity>[
          CameraResolutionEntity(
            width: 1920,
            height: 1080,
            maxFps: 60,
            hdrSupported: true,
          ),
          CameraResolutionEntity(
            width: 1280,
            height: 720,
            maxFps: 120,
            hdrSupported: false,
          ),
          CameraResolutionEntity(
            width: 3840,
            height: 2160,
            maxFps: 30,
            hdrSupported: true,
          ),
        ]);

    expect(result.map((item) => item.label), <String>['4K', '1080p', '720p']);
    expect(result.first.recommended, isTrue);
    expect(result.first.hdrSupported, isTrue);
  });

  test('never invents 8K when the native table does not expose it', () {
    final List<CameraResolutionEntity> result = service
        .selectStableProfiles(const <CameraResolutionEntity>[
          CameraResolutionEntity(
            width: 4096,
            height: 2160,
            maxFps: 30,
            hdrSupported: false,
          ),
          CameraResolutionEntity(
            width: 1920,
            height: 1080,
            maxFps: 60,
            hdrSupported: false,
          ),
        ]);

    expect(result.any((item) => item.label == '8K'), isFalse);
    expect(result.first.width, 4096);
  });

  test('uses max profile for a 2K-only device without fabricating UHD', () {
    final List<CameraResolutionEntity> result = service
        .selectStableProfiles(const <CameraResolutionEntity>[
          CameraResolutionEntity(
            width: 2560,
            height: 1440,
            maxFps: 30,
            hdrSupported: false,
          ),
          CameraResolutionEntity(
            width: 1920,
            height: 1080,
            maxFps: 60,
            hdrSupported: false,
          ),
        ]);

    expect(result.first.label, '2K');
    expect(result.any((item) => item.label == '4K'), isFalse);
  });

  test('prefers processed 16:9 4K video over a larger 4:3 sensor format', () {
    final List<CameraResolutionEntity> result = service
        .selectStableProfiles(const <CameraResolutionEntity>[
          CameraResolutionEntity(
            width: 4032,
            height: 3024,
            maxFps: 30,
            hdrSupported: true,
          ),
          CameraResolutionEntity(
            width: 3840,
            height: 2160,
            maxFps: 60,
            hdrSupported: true,
          ),
        ]);

    expect(result.first.dimensions, '3840 × 2160');
    expect(result.first.recommended, isTrue);
    expect(result[1].displayLabel, '4K MAX');
  });
}
