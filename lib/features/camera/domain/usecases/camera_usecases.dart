import '../../../../core/errors/failures.dart';
import '../entities/camera_device_entity.dart';
import '../entities/camera_enums.dart';
import '../entities/camera_resolution_entity.dart';
import '../entities/camera_session_entity.dart';
import '../entities/media_result_entity.dart';
import '../repositories/camera_repository.dart';

class GetCameraDevicesUseCase {
  const GetCameraDevicesUseCase(this._repository);
  final CameraRepository _repository;
  Future<List<CameraDeviceEntity>> call() => _repository.getCameras();
}

typedef InitializedCamera = ({
  CameraSessionEntity session,
  CameraResolutionEntity resolution,
  int fps,
});

class InitializeCameraUseCase {
  const InitializeCameraUseCase(this._repository);
  final CameraRepository _repository;

  Future<InitializedCamera> call({
    required CameraDeviceEntity device,
    required CameraResolutionEntity resolution,
    required int fps,
    bool enableAudio = false,
    bool enableHdr = false,
    bool photoMode = false,
  }) async {
    final CameraSessionEntity session = await _repository.initialize(
      device: device,
      resolution: resolution,
      fps: fps,
      enableAudio: enableAudio,
      enableHdr: enableHdr,
      photoMode: photoMode,
    );
    return (session: session, resolution: resolution, fps: fps);
  }

  Future<InitializedCamera> highestWithFallback(
    CameraDeviceEntity device, {
    bool enableAudio = false,
    bool enableHdr = true,
  }) async {
    Object? lastError;
    final List<CameraResolutionEntity> videoProfiles = device.resolutions
        .where((resolution) => resolution.isVideoAspect)
        .toList();
    final Iterable<CameraResolutionEntity> candidates = videoProfiles.isEmpty
        ? device.resolutions
        : videoProfiles;
    for (final CameraResolutionEntity resolution in candidates) {
      try {
        return await call(
          device: device,
          resolution: resolution,
          fps: _stableFps(resolution),
          enableAudio: enableAudio,
          enableHdr: enableHdr,
        );
      } catch (error) {
        lastError = error;
        await _repository.dispose();
      }
    }
    throw CameraInitializationFailure(
      'No supported camera resolution could be initialized.',
      lastError,
    );
  }

  int _stableFps(CameraResolutionEntity resolution) {
    final List<int> supported = resolution.supportedFps;
    if (supported.contains(30)) return 30;
    if (supported.contains(24)) return 24;
    if (supported.isNotEmpty) {
      final List<int> safe = supported.where((fps) => fps <= 30).toList();
      return safe.isEmpty ? supported.first : safe.last;
    }
    if (resolution.maxFps >= 30) return 30;
    if (resolution.maxFps >= 24) return 24;
    return resolution.maxFps.clamp(1, 30);
  }
}

class CapturePhotoUseCase {
  const CapturePhotoUseCase(this._repository);
  final CameraRepository _repository;
  Future<MediaResultEntity> call() => _repository.capturePhoto();
}

class VideoRecordingUseCase {
  const VideoRecordingUseCase(this._repository);
  final CameraRepository _repository;
  Future<void> start() => _repository.startVideo();
  Future<MediaResultEntity> stop(Duration duration) =>
      _repository.stopVideo(duration);
  Future<void> pause() => _repository.pauseVideo();
  Future<void> resume() => _repository.resumeVideo();
}

class CameraControlUseCase {
  const CameraControlUseCase(this._repository);
  final CameraRepository _repository;
  Future<void> flash(CameraFlashMode mode) => _repository.setFlashMode(mode);
  Future<void> zoom(double value) => _repository.setZoom(value);
  Future<void> focus(double x, double y) => _repository.setFocusPoint(x, y);
  Future<void> exposurePoint(double x, double y) =>
      _repository.setExposurePoint(x, y);
  Future<void> exposureOffset(double value) =>
      _repository.setExposureOffset(value);
  Future<void> lockPortrait() => _repository.lockPortraitOrientation();
  Future<void> unlockOrientation() => _repository.unlockOrientation();
  Future<void> dispose() => _repository.dispose();
}

class MediaStorageUseCase {
  const MediaStorageUseCase(this._repository);
  final CameraRepository _repository;
  Future<MediaResultEntity> save(MediaResultEntity media) =>
      _repository.saveToGallery(media);
  Future<int> availableBytes() => _repository.getAvailableStorageBytes();
  Future<String> thermalState() => _repository.getThermalState();
}
