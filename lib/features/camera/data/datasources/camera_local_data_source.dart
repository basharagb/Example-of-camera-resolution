import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/resolution_selection_service.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/camera_device_entity.dart';
import '../../domain/entities/camera_enums.dart';
import '../../domain/entities/camera_resolution_entity.dart';
import '../../domain/entities/camera_session_entity.dart';
import '../../domain/entities/media_result_entity.dart';
import '../models/native_camera_model.dart';

abstract interface class CameraLocalDataSource {
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

class CameraLocalDataSourceImpl implements CameraLocalDataSource {
  CameraLocalDataSourceImpl(this._resolutionSelectionService);

  final ResolutionSelectionService _resolutionSelectionService;
  static const MethodChannel _channel = MethodChannel(
    AppConstants.cameraChannel,
  );
  CameraController? _controller;
  Map<String, CameraDescription> _descriptions = <String, CameraDescription>{};
  bool get _usesNativeCamera => Platform.isIOS || Platform.isAndroid;

  CameraController get _activeController {
    final CameraController? value = _controller;
    if (value == null || !value.value.isInitialized) {
      throw const CameraInitializationFailure(
        'The camera session is not ready.',
      );
    }
    return value;
  }

  @override
  Future<List<CameraDeviceEntity>> getCameras() async {
    try {
      final List<CameraDescription> pluginCameras = _usesNativeCamera
          ? const <CameraDescription>[]
          : await availableCameras();
      _descriptions = <String, CameraDescription>{
        for (final CameraDescription camera in pluginCameras)
          camera.name: camera,
      };
      final List<Object?> native =
          await _channel.invokeListMethod<Object?>('getCameraCapabilities') ??
          const <Object?>[];
      final List<CameraDeviceEntity> result = <CameraDeviceEntity>[];
      for (final Object? item in native) {
        if (item is! Map<Object?, Object?>) continue;
        final CameraDeviceEntity raw = NativeCameraModel.fromMap(item).entity;
        if (!_usesNativeCamera && !_descriptions.containsKey(raw.id)) continue;
        final List<CameraResolutionEntity> stable = _resolutionSelectionService
            .selectStableProfiles(raw.resolutions);
        if (stable.isEmpty) continue;
        result.add(
          CameraDeviceEntity(
            id: raw.id,
            name: raw.name,
            lensDirection: raw.lensDirection,
            lensType: raw.lensType,
            sensorOrientation: raw.sensorOrientation,
            focalLengths: raw.focalLengths,
            flashSupported: raw.flashSupported,
            videoStabilizationSupported: raw.videoStabilizationSupported,
            opticalStabilizationSupported: raw.opticalStabilizationSupported,
            resolutions: stable,
            photoWidth: raw.photoWidth,
            photoHeight: raw.photoHeight,
          ),
        );
      }
      if (result.isEmpty) {
        throw const NativeCameraCapabilityFailure(
          'Native camera modes could not be matched to an available camera.',
        );
      }
      return result;
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      debugLog('Capability discovery failed', error, stackTrace);
      throw NativeCameraCapabilityFailure(
        'This device did not return a usable camera capability table.',
        error,
      );
    }
  }

  @override
  Future<CameraSessionEntity> initialize({
    required CameraDeviceEntity device,
    required CameraResolutionEntity resolution,
    required int fps,
    required bool enableAudio,
    required bool enableHdr,
    required bool photoMode,
  }) async {
    await dispose();
    if (_usesNativeCamera) {
      return _initializeNativeCamera(
        device: device,
        resolution: resolution,
        fps: fps,
        enableAudio: enableAudio,
        enableHdr: enableHdr,
        photoMode: photoMode,
      );
    }
    final CameraDescription? description = _descriptions[device.id];
    if (description == null) {
      throw const CameraInitializationFailure(
        'The selected physical camera is no longer available.',
      );
    }
    final ResolutionPreset preset = _presetFor(device, resolution);
    final CameraController controller = CameraController(
      description,
      preset,
      enableAudio: enableAudio,
      fps: fps,
      videoBitrate: resolution.bitrateFor(fps),
      audioBitrate: 192000,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );
    _controller = controller;
    try {
      await controller.initialize().timeout(AppConstants.initializationTimeout);
      if (device.videoStabilizationSupported) {
        try {
          await controller.setVideoStabilizationMode(
            VideoStabilizationMode.level2,
          );
        } catch (error) {
          debugLog('Video stabilization could not be enabled', error);
        }
      }
      final List<double> values = await Future.wait(<Future<double>>[
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
        controller.getMinExposureOffset(),
        controller.getMaxExposureOffset(),
      ]);
      final Size size = controller.value.previewSize ?? const Size(1, 1);
      return CameraSessionEntity(
        previewHandle: controller,
        previewWidth: size.width,
        previewHeight: size.height,
        minZoom: values[0],
        maxZoom: values[1],
        minExposure: values[2],
        maxExposure: values[3],
        usesNativePreview: false,
        hdrActive: false,
      );
    } catch (error, stackTrace) {
      debugLog('Camera initialization failed', error, stackTrace);
      await dispose();
      throw CameraInitializationFailure(
        '${resolution.label} could not be initialized on ${device.displayName}.',
        error,
      );
    }
  }

  Future<CameraSessionEntity> _initializeNativeCamera({
    required CameraDeviceEntity device,
    required CameraResolutionEntity resolution,
    required int fps,
    required bool enableAudio,
    required bool enableHdr,
    required bool photoMode,
  }) async {
    try {
      final Map<Object?, Object?>? value = await _channel
          .invokeMapMethod<Object?, Object?>(
            Platform.isIOS
                ? 'initializeNativeCamera'
                : 'initializeNativeAndroidCamera',
            <String, Object>{
              'cameraId': device.id,
              'width': resolution.longEdge,
              'height': resolution.shortEdge,
              'fps': fps,
              'enableAudio': enableAudio,
              'enableHdr': enableHdr && resolution.hdrSupported,
              'videoBitrate': resolution.bitrateFor(fps),
              'photoWidth': device.photoWidth,
              'photoHeight': device.photoHeight,
              'videoStabilizationSupported': device.videoStabilizationSupported,
              'preferPhoto': photoMode,
            },
          )
          .timeout(AppConstants.initializationTimeout);
      if (value == null) {
        throw const CameraInitializationFailure(
          'The native camera returned no session information.',
        );
      }
      if (Platform.isAndroid && resolution.isVideoAspect && !photoMode) {
        final int actualWidth = _asInt(value['videoWidth']);
        final int actualHeight = _asInt(value['videoHeight']);
        final int actualLong = actualWidth > actualHeight
            ? actualWidth
            : actualHeight;
        final int actualShort = actualWidth < actualHeight
            ? actualWidth
            : actualHeight;
        if (actualLong < resolution.longEdge * 0.95 ||
            actualShort < resolution.shortEdge * 0.95) {
          await _channel.invokeMethod<void>('disposeNativeAndroidCamera');
          throw CameraInitializationFailure(
            '${resolution.displayLabel} is advertised by Camera2, but this '
            'device encoder only accepted $actualLong×$actualShort.',
          );
        }
      }
      return CameraSessionEntity(
        previewHandle: Platform.isIOS
            ? 'apex-native-ios-preview'
            : 'apex-native-android-preview',
        previewWidth: _asDouble(value['previewWidth'], resolution.longEdge),
        previewHeight: _asDouble(value['previewHeight'], resolution.shortEdge),
        minZoom: _asDouble(value['minZoom'], 1),
        maxZoom: _asDouble(value['maxZoom'], 1),
        minExposure: _asDouble(value['minExposure'], 0),
        maxExposure: _asDouble(value['maxExposure'], 0),
        usesNativePreview: true,
        hdrActive: value['hdrActive'] == true,
      );
    } catch (error, stackTrace) {
      debugLog('Native camera initialization failed', error, stackTrace);
      throw CameraInitializationFailure(
        '${resolution.displayLabel} could not be initialized on ${device.displayName}.',
        error,
      );
    }
  }

  ResolutionPreset _presetFor(
    CameraDeviceEntity device,
    CameraResolutionEntity resolution,
  ) {
    if (resolution.label == '8K') {
      return ResolutionPreset.max;
    }
    if (resolution.longEdge >= 3800 && resolution.isVideoAspect) {
      return ResolutionPreset.ultraHigh;
    }
    if (!resolution.isVideoAspect) return ResolutionPreset.max;
    return switch (resolution.label) {
      '4K' => ResolutionPreset.ultraHigh,
      '1080p' => ResolutionPreset.veryHigh,
      '720p' => ResolutionPreset.high,
      '480p' => ResolutionPreset.medium,
      _ => ResolutionPreset.max,
    };
  }

  @override
  Future<void> dispose() async {
    if (_usesNativeCamera) {
      try {
        await _channel.invokeMethod<void>(
          Platform.isIOS ? 'disposeNativeCamera' : 'disposeNativeAndroidCamera',
        );
      } catch (error) {
        debugLog('Native camera disposal failed', error);
      }
      return;
    }
    final CameraController? old = _controller;
    _controller = null;
    if (old != null) {
      try {
        await old.dispose();
      } catch (error) {
        debugLog('Camera disposal failed', error);
      }
    }
  }

  @override
  Future<MediaResultEntity> capturePhoto() async {
    if (_usesNativeCamera) {
      final String? path = await _channel.invokeMethod<String>(
        Platform.isIOS ? 'captureNativePhoto' : 'captureNativeAndroidPhoto',
      );
      if (path == null || path.isEmpty) {
        throw const CaptureFailure(
          'The native photo capture returned no file.',
        );
      }
      return _inspect(path, CapturedMediaType.photo);
    }
    final XFile file = await _activeController.takePicture();
    return _inspect(file.path, CapturedMediaType.photo);
  }

  @override
  Future<void> startVideo() async {
    if (_usesNativeCamera) {
      await _channel.invokeMethod<void>(
        Platform.isIOS ? 'startNativeVideo' : 'startNativeAndroidVideo',
      );
      return;
    }
    await _activeController.prepareForVideoRecording();
    await _activeController.startVideoRecording();
  }

  @override
  Future<MediaResultEntity> stopVideo(Duration duration) async {
    if (_usesNativeCamera) {
      final String? path = await _channel.invokeMethod<String>(
        Platform.isIOS ? 'stopNativeVideo' : 'stopNativeAndroidVideo',
      );
      if (path == null || path.isEmpty) {
        throw const RecordingFailure('The native recording returned no file.');
      }
      return _inspect(path, CapturedMediaType.video, duration: duration);
    }
    final XFile file = await _activeController.stopVideoRecording();
    return _inspect(file.path, CapturedMediaType.video, duration: duration);
  }

  @override
  Future<void> pauseVideo() => _usesNativeCamera
      ? _channel.invokeMethod<void>(
          Platform.isIOS ? 'pauseNativeVideo' : 'pauseNativeAndroidVideo',
        )
      : _activeController.pauseVideoRecording();

  @override
  Future<void> resumeVideo() => _usesNativeCamera
      ? _channel.invokeMethod<void>(
          Platform.isIOS ? 'resumeNativeVideo' : 'resumeNativeAndroidVideo',
        )
      : _activeController.resumeVideoRecording();

  @override
  Future<void> setFlashMode(CameraFlashMode mode) {
    if (_usesNativeCamera) {
      return _channel.invokeMethod<void>(
        Platform.isIOS ? 'setNativeFlashMode' : 'setNativeAndroidFlashMode',
        <String, Object>{'mode': mode.name},
      );
    }
    final FlashMode pluginMode = switch (mode) {
      CameraFlashMode.off => FlashMode.off,
      CameraFlashMode.auto => FlashMode.auto,
      CameraFlashMode.always => FlashMode.always,
      CameraFlashMode.torch => FlashMode.torch,
    };
    return _activeController.setFlashMode(pluginMode);
  }

  @override
  Future<void> setZoom(double zoom) => _usesNativeCamera
      ? _channel.invokeMethod<void>(
          Platform.isIOS ? 'setNativeZoom' : 'setNativeAndroidZoom',
          <String, Object>{'zoom': zoom},
        )
      : _activeController.setZoomLevel(zoom);

  @override
  Future<void> setFocusPoint(double x, double y) => _usesNativeCamera
      ? _channel.invokeMethod<void>(
          Platform.isIOS ? 'setNativeFocusPoint' : 'setNativeAndroidFocusPoint',
          <String, Object>{'x': x, 'y': y},
        )
      : _activeController.setFocusPoint(Offset(x.clamp(0, 1), y.clamp(0, 1)));

  @override
  Future<void> setExposurePoint(double x, double y) => _usesNativeCamera
      ? _channel.invokeMethod<void>(
          Platform.isIOS
              ? 'setNativeExposurePoint'
              : 'setNativeAndroidExposurePoint',
          <String, Object>{'x': x, 'y': y},
        )
      : _activeController.setExposurePoint(
          Offset(x.clamp(0, 1), y.clamp(0, 1)),
        );

  @override
  Future<void> setExposureOffset(double offset) => _usesNativeCamera
      ? _channel.invokeMethod<void>(
          Platform.isIOS
              ? 'setNativeExposureOffset'
              : 'setNativeAndroidExposureOffset',
          <String, Object>{'offset': offset},
        )
      : _activeController.setExposureOffset(offset);

  @override
  Future<void> lockPortraitOrientation() => _usesNativeCamera
      ? Future<void>.value()
      : _activeController.lockCaptureOrientation(DeviceOrientation.portraitUp);

  @override
  Future<void> unlockOrientation() => _usesNativeCamera
      ? Future<void>.value()
      : _activeController.unlockCaptureOrientation();

  Future<MediaResultEntity> _inspect(
    String path,
    CapturedMediaType type, {
    Duration duration = Duration.zero,
  }) async {
    final File file = File(path);
    final int bytes = await file.length();
    int width = 0;
    int height = 0;
    try {
      final Map<Object?, Object?>? metadata = await _channel
          .invokeMapMethod<Object?, Object?>('inspectMedia', <String, Object>{
            'path': path,
            'type': type.name,
          });
      width = _asInt(metadata?['width']);
      height = _asInt(metadata?['height']);
    } catch (error) {
      debugLog('Media metadata inspection failed', error);
    }
    return MediaResultEntity(
      path: path,
      type: type,
      width: width,
      height: height,
      bytes: bytes,
      duration: duration,
    );
  }

  @override
  Future<MediaResultEntity> saveToGallery(MediaResultEntity media) async {
    final String? uri = await _channel.invokeMethod<String>(
      'saveMedia',
      <String, Object>{'path': media.path, 'type': media.type.name},
    );
    if (uri == null || uri.isEmpty) {
      throw const GallerySaveFailure(
        'The system gallery did not return a saved media identifier.',
      );
    }
    return media.copyWith(galleryUri: uri);
  }

  @override
  Future<int> getAvailableStorageBytes() async =>
      await _channel.invokeMethod<int>('getAvailableStorageBytes') ?? 0;

  @override
  Future<String> getThermalState() async =>
      await _channel.invokeMethod<String>('getThermalState') ?? 'unknown';

  int _asInt(Object? value) =>
      value is num ? value.round() : int.tryParse('$value') ?? 0;

  double _asDouble(Object? value, num fallback) =>
      value is num ? value.toDouble() : fallback.toDouble();
}
