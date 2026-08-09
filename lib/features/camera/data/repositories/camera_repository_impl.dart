import '../../../../core/errors/failures.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/camera_device_entity.dart';
import '../../domain/entities/camera_enums.dart';
import '../../domain/entities/camera_resolution_entity.dart';
import '../../domain/entities/camera_session_entity.dart';
import '../../domain/entities/media_result_entity.dart';
import '../../domain/repositories/camera_repository.dart';
import '../datasources/camera_local_data_source.dart';

class CameraRepositoryImpl implements CameraRepository {
  const CameraRepositoryImpl(this._local);
  final CameraLocalDataSource _local;

  @override
  Future<List<CameraDeviceEntity>> getCameras() => _local.getCameras();

  @override
  Future<CameraSessionEntity> initialize({
    required CameraDeviceEntity device,
    required CameraResolutionEntity resolution,
    required int fps,
    required bool enableAudio,
    required bool enableHdr,
    required bool photoMode,
  }) => _local.initialize(
    device: device,
    resolution: resolution,
    fps: fps,
    enableAudio: enableAudio,
    enableHdr: enableHdr,
    photoMode: photoMode,
  );

  @override
  Future<void> dispose() => _local.dispose();

  @override
  Future<MediaResultEntity> capturePhoto() async {
    try {
      return await _local.capturePhoto();
    } catch (error, stackTrace) {
      debugLog('Photo capture failed', error, stackTrace);
      throw CaptureFailure(
        'The photo could not be captured. Please try again.',
        error,
      );
    }
  }

  @override
  Future<void> startVideo() async {
    try {
      await _local.startVideo();
    } catch (error) {
      throw RecordingFailure('Video recording could not start.', error);
    }
  }

  @override
  Future<MediaResultEntity> stopVideo(Duration duration) async {
    try {
      return await _local.stopVideo(duration);
    } catch (error) {
      throw RecordingFailure('Video recording could not be finalized.', error);
    }
  }

  @override
  Future<void> pauseVideo() => _local.pauseVideo();
  @override
  Future<void> resumeVideo() => _local.resumeVideo();
  @override
  Future<void> setFlashMode(CameraFlashMode mode) => _local.setFlashMode(mode);
  @override
  Future<void> setZoom(double zoom) => _local.setZoom(zoom);
  @override
  Future<void> setFocusPoint(double x, double y) => _local.setFocusPoint(x, y);
  @override
  Future<void> setExposurePoint(double x, double y) =>
      _local.setExposurePoint(x, y);
  @override
  Future<void> setExposureOffset(double offset) =>
      _local.setExposureOffset(offset);
  @override
  Future<void> lockPortraitOrientation() => _local.lockPortraitOrientation();
  @override
  Future<void> unlockOrientation() => _local.unlockOrientation();

  @override
  Future<MediaResultEntity> saveToGallery(MediaResultEntity media) async {
    try {
      return await _local.saveToGallery(media);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw GallerySaveFailure(
        'The original file could not be saved to the gallery.',
        error,
      );
    }
  }

  @override
  Future<int> getAvailableStorageBytes() async {
    try {
      return await _local.getAvailableStorageBytes();
    } catch (error) {
      throw StorageFailure('Available storage could not be read.', error);
    }
  }

  @override
  Future<String> getThermalState() => _local.getThermalState();
}
