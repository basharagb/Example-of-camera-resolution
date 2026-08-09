import '../entities/camera_device_entity.dart';
import '../entities/camera_enums.dart';
import '../entities/camera_resolution_entity.dart';
import '../entities/camera_session_entity.dart';
import '../entities/media_result_entity.dart';

abstract interface class CameraRepository {
  Future<List<CameraDeviceEntity>> getCameras();
  Future<CameraSessionEntity> initialize({
    required CameraDeviceEntity device,
    required CameraResolutionEntity resolution,
    required int fps,
    required bool enableAudio,
    required bool enableHdr,
    required bool photoMode,
  });
  Future<void> dispose();
  Future<MediaResultEntity> capturePhoto();
  Future<void> startVideo();
  Future<MediaResultEntity> stopVideo(Duration duration);
  Future<void> pauseVideo();
  Future<void> resumeVideo();
  Future<void> setFlashMode(CameraFlashMode mode);
  Future<void> setZoom(double zoom);
  Future<void> setFocusPoint(double x, double y);
  Future<void> setExposurePoint(double x, double y);
  Future<void> setExposureOffset(double offset);
  Future<void> lockPortraitOrientation();
  Future<void> unlockOrientation();
  Future<MediaResultEntity> saveToGallery(MediaResultEntity media);
  Future<int> getAvailableStorageBytes();
  Future<String> getThermalState();
}
