import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/camera_device_entity.dart';
import '../../domain/entities/camera_enums.dart';
import '../../domain/entities/camera_resolution_entity.dart';
import '../../domain/entities/camera_session_entity.dart';
import '../../domain/entities/media_result_entity.dart';
import '../../domain/entities/permission_status_entity.dart';
import '../../domain/usecases/camera_usecases.dart';
import '../../domain/usecases/permission_usecases.dart';

class CameraControllerGetX extends GetxController with WidgetsBindingObserver {
  CameraControllerGetX({
    required this.getCameras,
    required this.initializeCamera,
    required this.capturePhoto,
    required this.videoRecording,
    required this.cameraControl,
    required this.mediaStorage,
    required this.requestCameraPermission,
    required this.requestMicrophonePermission,
    required this.requestGalleryPermission,
    required this.openSettings,
  });

  final GetCameraDevicesUseCase getCameras;
  final InitializeCameraUseCase initializeCamera;
  final CapturePhotoUseCase capturePhoto;
  final VideoRecordingUseCase videoRecording;
  final CameraControlUseCase cameraControl;
  final MediaStorageUseCase mediaStorage;
  final RequestCameraPermissionUseCase requestCameraPermission;
  final RequestMicrophonePermissionUseCase requestMicrophonePermission;
  final RequestGalleryPermissionUseCase requestGalleryPermission;
  final OpenApplicationSettingsUseCase openSettings;

  final RxBool isInitialized = false.obs;
  final RxBool isInitializing = false.obs;
  final RxBool isRecording = false.obs;
  final RxBool isPaused = false.obs;
  final RxBool isTakingPhoto = false.obs;
  final Rx<CameraMode> selectedMode = CameraMode.video.obs;
  final Rxn<CameraResolutionEntity> selectedResolution =
      Rxn<CameraResolutionEntity>();
  final RxList<CameraResolutionEntity> availableResolutions =
      <CameraResolutionEntity>[].obs;
  final Rxn<CameraDeviceEntity> selectedCamera = Rxn<CameraDeviceEntity>();
  final RxList<CameraDeviceEntity> availableCameras =
      <CameraDeviceEntity>[].obs;
  final RxDouble zoomLevel = 1.0.obs;
  final RxDouble minZoom = 1.0.obs;
  final RxDouble maxZoom = 1.0.obs;
  final RxDouble exposureOffset = 0.0.obs;
  final RxDouble minExposure = 0.0.obs;
  final RxDouble maxExposure = 0.0.obs;
  final Rx<CameraFlashMode> flashMode = CameraFlashMode.off.obs;
  final Rx<Duration> recordingDuration = Duration.zero.obs;
  final RxnString errorMessage = RxnString();
  final Rxn<PermissionStatusKind> cameraPermissionStatus =
      Rxn<PermissionStatusKind>();
  final Rxn<CameraSessionEntity> session = Rxn<CameraSessionEntity>();
  final Rxn<MediaResultEntity> lastMedia = Rxn<MediaResultEntity>();
  final RxInt selectedFps = 30.obs;
  final RxBool hdrEnabled = false.obs;
  final Rx<CaptureDurationOption> durationMode =
      CaptureDurationOption.sixtySeconds.obs;
  final RxInt timerSeconds = 0.obs;
  final RxInt countdown = 0.obs;
  final RxInt availableStorageBytes = 0.obs;
  final RxString thermalState = 'unknown'.obs;
  final Rxn<Offset> focusPoint = Rxn<Offset>();
  final RxBool focusVisible = false.obs;

  Timer? _recordingTimer;
  Timer? _focusTimer;
  double _baseZoom = 1;
  bool _audioEnabled = false;
  bool _lifecycleTransition = false;
  bool _stoppingRecording = false;
  bool _photoSessionActive = false;

  List<int> get availableFps {
    final CameraResolutionEntity? resolution = selectedResolution.value;
    if (resolution != null && resolution.supportedFps.isNotEmpty) {
      return List<int>.of(resolution.supportedFps)..sort();
    }
    final int maximum = resolution?.maxFps ?? 30;
    final List<int> standard = <int>[
      24,
      30,
      60,
      120,
      240,
    ].where((fps) => fps <= maximum).toList();
    if (standard.isEmpty) standard.add(maximum.clamp(1, 240));
    return standard;
  }

  bool get hdrAvailable => selectedResolution.value?.hdrSupported ?? false;
  bool get controlsLocked => isInitializing.value || isTakingPhoto.value;
  Object? get previewHandle => session.value?.previewHandle;
  String get previewDimensions {
    final CameraSessionEntity? value = session.value;
    if (value == null) return '';
    return '${value.previewWidth.round()} × ${value.previewHeight.round()} preview';
  }

  String get recordingTimeText {
    final Duration value = recordingDuration.value;
    final String minutes = value.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final String seconds = value.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get storageText {
    final int bytes = availableStorageBytes.value;
    if (bytes <= 0) return 'Storage unknown';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB free';
  }

  String get estimatedRecordingSize {
    final CameraResolutionEntity? resolution = selectedResolution.value;
    if (resolution == null) return '';
    final int bytes =
        (resolution.bitrateFor(selectedFps.value) /
                8 *
                recordingDuration.value.inSeconds)
            .round();
    return bytes >= 1024 * 1024
        ? '~${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB'
        : '~${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(boot());
  }

  Future<void> boot() async {
    if (isInitializing.value) return;
    isInitializing.value = true;
    errorMessage.value = null;
    try {
      final PermissionStatusEntity permission = await requestCameraPermission();
      cameraPermissionStatus.value = permission.status;
      if (!permission.isUsable) {
        throw const CameraPermissionFailure(
          'Camera access is required. You can enable it in the application settings.',
        );
      }
      final List<CameraDeviceEntity> devices = await getCameras();
      if (devices.isEmpty) {
        throw const NativeCameraCapabilityFailure(
          'No usable physical cameras were found.',
        );
      }
      availableCameras.assignAll(devices);
      final List<CameraDeviceEntity> rearCameras = devices
          .where((device) => device.lensDirection == CameraLensDirection.back)
          .toList();
      final CameraDeviceEntity preferred = rearCameras.firstWhere(
        (device) => device.lensType == 'Multi-lens',
        orElse: () => rearCameras.isEmpty ? devices.first : rearCameras.first,
      );
      selectedCamera.value = preferred;
      availableResolutions.assignAll(preferred.resolutions);
      final InitializedCamera initialized = await initializeCamera
          .highestWithFallback(preferred);
      _applyInitialized(initialized);
      unawaited(refreshDeviceSafety());
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
    } catch (error, stackTrace) {
      debugLog('Camera boot failed', error, stackTrace);
      errorMessage.value = 'The camera could not be opened on this device.';
    } finally {
      isInitializing.value = false;
    }
  }

  void _applyInitialized(
    InitializedCamera initialized, {
    bool photoSession = false,
  }) {
    session.value = initialized.session;
    selectedResolution.value = initialized.resolution;
    selectedFps.value = initialized.fps;
    minZoom.value = initialized.session.minZoom;
    maxZoom.value = initialized.session.maxZoom;
    minExposure.value = initialized.session.minExposure;
    maxExposure.value = initialized.session.maxExposure;
    zoomLevel.value = zoomLevel.value.clamp(minZoom.value, maxZoom.value);
    exposureOffset.value = exposureOffset.value.clamp(
      minExposure.value,
      maxExposure.value,
    );
    hdrEnabled.value = initialized.session.hdrActive;
    _photoSessionActive = photoSession;
    isInitialized.value = true;
  }

  Future<void> retry() async {
    await cameraControl.dispose();
    isInitialized.value = false;
    await boot();
  }

  Future<void> openApplicationSettings() => openSettings();

  Future<void> switchCamera() async {
    if (controlsLocked || availableCameras.length < 2) return;
    if (isRecording.value) await stopRecording();
    final int current = availableCameras.indexWhere(
      (item) => item.id == selectedCamera.value?.id,
    );
    await selectCamera(
      availableCameras[(current + 1) % availableCameras.length],
    );
  }

  Future<void> selectCamera(CameraDeviceEntity device) async {
    if (controlsLocked || device.id == selectedCamera.value?.id) return;
    isInitializing.value = true;
    isInitialized.value = false;
    errorMessage.value = null;
    final CameraDeviceEntity? previousDevice = selectedCamera.value;
    final CameraResolutionEntity? previousResolution = selectedResolution.value;
    final int previousFps = selectedFps.value;
    try {
      selectedCamera.value = device;
      availableResolutions.assignAll(device.resolutions);
      selectedFps.value = _fpsForResolution(device.resolutions.first);
      final InitializedCamera initialized = await initializeCamera
          .highestWithFallback(
            device,
            enableAudio: _audioEnabled,
            enableHdr: hdrEnabled.value,
          );
      _applyInitialized(initialized);
      await _restoreControls();
    } catch (error) {
      if (previousDevice != null && previousResolution != null) {
        selectedCamera.value = previousDevice;
        availableResolutions.assignAll(previousDevice.resolutions);
        try {
          final InitializedCamera restored = await initializeCamera(
            device: previousDevice,
            resolution: previousResolution,
            fps: previousFps,
            enableAudio: _audioEnabled,
            enableHdr: hdrEnabled.value && previousResolution.hdrSupported,
          );
          _applyInitialized(restored);
        } catch (_) {
          errorMessage.value = 'The camera could not be restored.';
        }
      }
      _showError('That camera could not be opened.');
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> selectResolution(CameraResolutionEntity resolution) async {
    final CameraDeviceEntity? device = selectedCamera.value;
    final CameraResolutionEntity? previous = selectedResolution.value;
    if (device == null || previous == resolution || controlsLocked) return;
    if (isRecording.value) await stopRecording();
    isInitializing.value = true;
    isInitialized.value = false;
    try {
      final int fps = resolution.supportedFps.contains(selectedFps.value)
          ? selectedFps.value
          : _fpsForResolution(resolution);
      final InitializedCamera initialized = await initializeCamera(
        device: device,
        resolution: resolution,
        fps: fps,
        enableAudio: _audioEnabled,
        enableHdr: hdrEnabled.value && resolution.hdrSupported,
      );
      selectedFps.value = fps;
      _applyInitialized(initialized);
      await _restoreControls();
    } catch (error) {
      if (previous != null) {
        try {
          final InitializedCamera restored = await initializeCamera(
            device: device,
            resolution: previous,
            fps: selectedFps.value.clamp(1, previous.maxFps),
            enableAudio: _audioEnabled,
            enableHdr: hdrEnabled.value && previous.hdrSupported,
          );
          _applyInitialized(restored);
        } catch (_) {
          errorMessage.value = 'The previous resolution could not be restored.';
        }
      }
      _showError(
        '${resolution.displayLabel} is declared by the device but failed during session setup.',
      );
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> selectFps(int fps) async {
    final CameraDeviceEntity? device = selectedCamera.value;
    final CameraResolutionEntity? resolution = selectedResolution.value;
    if (device == null ||
        resolution == null ||
        fps == selectedFps.value ||
        controlsLocked) {
      return;
    }
    final int previous = selectedFps.value;
    isInitializing.value = true;
    isInitialized.value = false;
    try {
      final InitializedCamera initialized = await initializeCamera(
        device: device,
        resolution: resolution,
        fps: fps,
        enableAudio: _audioEnabled,
        enableHdr: hdrEnabled.value && resolution.hdrSupported,
      );
      selectedFps.value = fps;
      _applyInitialized(initialized);
      await _restoreControls();
    } catch (_) {
      selectedFps.value = previous;
      try {
        _applyInitialized(
          await initializeCamera(
            device: device,
            resolution: resolution,
            fps: previous,
            enableAudio: _audioEnabled,
            enableHdr: hdrEnabled.value && resolution.hdrSupported,
          ),
        );
      } catch (_) {
        errorMessage.value = 'The camera session could not be restored.';
      }
      _showError(
        '$fps FPS is not stable for this resolution on the current device.',
      );
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> _restoreControls() async {
    zoomLevel.value = zoomLevel.value.clamp(minZoom.value, maxZoom.value);
    await cameraControl.zoom(zoomLevel.value);
    if (selectedCamera.value?.flashSupported == true) {
      try {
        await cameraControl.flash(flashMode.value);
      } catch (_) {
        flashMode.value = CameraFlashMode.off;
      }
    }
  }

  int _fpsForResolution(CameraResolutionEntity resolution) {
    if (resolution.supportedFps.contains(30)) return 30;
    if (resolution.supportedFps.contains(24)) return 24;
    if (resolution.supportedFps.isNotEmpty) {
      final List<int> safe = resolution.supportedFps
          .where((fps) => fps <= 30)
          .toList();
      return safe.isEmpty ? resolution.supportedFps.first : safe.last;
    }
    if (resolution.maxFps >= 30) return 30;
    if (resolution.maxFps >= 24) return 24;
    return resolution.maxFps.clamp(1, 30);
  }

  void selectMode(CameraMode mode) {
    if (isRecording.value || controlsLocked) return;
    selectedMode.value = mode;
    if (mode == CameraMode.video) unawaited(_ensureVideoSession());
  }

  Future<void> _ensureVideoSession() async {
    final CameraDeviceEntity? device = selectedCamera.value;
    if (device == null) return;
    final CameraResolutionEntity? videoMode = availableResolutions
        .firstWhereOrNull((resolution) => resolution.isVideoAspect);
    if (!_photoSessionActive) {
      if (videoMode != null && selectedResolution.value != videoMode) {
        await selectResolution(videoMode);
      }
      return;
    }
    isInitializing.value = true;
    isInitialized.value = false;
    try {
      final InitializedCamera initialized = await initializeCamera
          .highestWithFallback(
            device,
            enableAudio: _audioEnabled,
            enableHdr: hdrEnabled.value,
          );
      _applyInitialized(initialized);
      await _restoreControls();
    } on AppFailure catch (failure) {
      _showError(failure.message);
    } finally {
      isInitializing.value = false;
    }
  }

  void selectDuration(CaptureDurationOption value) =>
      durationMode.value = value;

  void cycleTimer() {
    timerSeconds.value = switch (timerSeconds.value) {
      0 => 3,
      3 => 10,
      _ => 0,
    };
  }

  Future<void> onCapturePressed() async {
    if (!isInitialized.value || controlsLocked) return;
    if (selectedMode.value == CameraMode.video) {
      if (isRecording.value) {
        await stopRecording();
      } else {
        await _withCountdown(startRecording);
      }
    } else {
      await _withCountdown(takePhoto);
    }
  }

  Future<void> _withCountdown(Future<void> Function() action) async {
    if (timerSeconds.value == 0) return action();
    countdown.value = timerSeconds.value;
    while (countdown.value > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      countdown.value--;
    }
    await action();
  }

  Future<void> takePhoto() async {
    if (isTakingPhoto.value || !isInitialized.value) return;
    isTakingPhoto.value = true;
    try {
      await _ensureMaximumStillSession();
      HapticFeedback.mediumImpact();
      final MediaResultEntity media = await capturePhoto();
      lastMedia.value = await _saveOriginal(media);
      _showMediaResult(lastMedia.value!);
      unawaited(refreshDeviceSafety());
    } on AppFailure catch (failure) {
      _showError(failure.message);
    } finally {
      isTakingPhoto.value = false;
    }
  }

  Future<void> _ensureMaximumStillSession() async {
    final CameraDeviceEntity? device = selectedCamera.value;
    final CameraResolutionEntity? current = selectedResolution.value;
    if (device == null ||
        current == null ||
        device.resolutions.first == current) {
      return;
    }
    isInitializing.value = true;
    isInitialized.value = false;
    final int previousFps = selectedFps.value;
    final bool previousAudio = _audioEnabled;
    try {
      final CameraResolutionEntity maximum = device.resolutions.reduce(
        (current, next) => next.pixels > current.pixels ? next : current,
      );
      final int fps = _fpsForResolution(maximum);
      _applyInitialized(
        await initializeCamera(
          device: device,
          resolution: maximum,
          fps: fps,
          enableAudio: false,
          enableHdr: maximum.hdrSupported,
          photoMode: true,
        ),
        photoSession: true,
      );
      _audioEnabled = false;
      await _restoreControls();
    } catch (error) {
      try {
        _applyInitialized(
          await initializeCamera(
            device: device,
            resolution: current,
            fps: previousFps.clamp(1, current.maxFps),
            enableAudio: previousAudio,
            enableHdr: hdrEnabled.value && current.hdrSupported,
          ),
        );
        _audioEnabled = previousAudio;
        await _restoreControls();
      } catch (_) {
        errorMessage.value = 'The camera session could not be restored.';
      }
      throw CaptureFailure(
        'The maximum-quality still session could not be initialized.',
        error,
      );
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> startRecording() async {
    final CameraResolutionEntity? resolution = selectedResolution.value;
    if (resolution == null || isRecording.value) return;
    await refreshDeviceSafety();
    if (availableStorageBytes.value > 0 &&
        availableStorageBytes.value < AppConstants.criticalStorageBytes) {
      _showError('Recording needs at least 500 MB of free storage.');
      return;
    }
    if (thermalState.value == 'critical' || thermalState.value == 'danger') {
      _showError(
        'The device is too hot for safe high-resolution recording. Let it cool first.',
      );
      return;
    }
    if (resolution.isEightK && !await _confirmEightK()) return;
    final PermissionStatusEntity microphone =
        await requestMicrophonePermission();
    if (!microphone.isUsable) {
      await _permissionFailure(
        'Microphone access is required for video with sound.',
        microphone,
      );
      return;
    }
    if (!_audioEnabled) {
      final CameraDeviceEntity? device = selectedCamera.value;
      if (device == null) return;
      isInitializing.value = true;
      isInitialized.value = false;
      try {
        _applyInitialized(
          await initializeCamera(
            device: device,
            resolution: resolution,
            fps: selectedFps.value,
            enableAudio: true,
            enableHdr: hdrEnabled.value && resolution.hdrSupported,
          ),
        );
        _audioEnabled = true;
        await _restoreControls();
      } catch (_) {
        _showError(
          'The audio-enabled camera session could not be initialized.',
        );
        isInitializing.value = false;
        return;
      }
      isInitializing.value = false;
    }
    try {
      await cameraControl.lockPortrait();
      await WakelockPlus.enable();
      await videoRecording.start();
      recordingDuration.value = Duration.zero;
      isRecording.value = true;
      isPaused.value = false;
      HapticFeedback.heavyImpact();
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (isPaused.value) return;
        recordingDuration.value += const Duration(seconds: 1);
        final Duration? limit = durationMode.value.limit;
        if (limit != null && recordingDuration.value >= limit) {
          unawaited(stopRecording());
        }
        if (recordingDuration.value.inSeconds % 10 == 0) {
          unawaited(_monitorRecordingSafety());
        }
      });
    } on AppFailure catch (failure) {
      await _recordingCleanup();
      _showError(failure.message);
    }
  }

  Future<void> stopRecording() async {
    if (!isRecording.value || _stoppingRecording) return;
    _stoppingRecording = true;
    _recordingTimer?.cancel();
    final Duration duration = recordingDuration.value;
    try {
      final MediaResultEntity media = await videoRecording.stop(duration);
      isRecording.value = false;
      lastMedia.value = await _saveOriginal(media);
      _showMediaResult(lastMedia.value!);
    } on AppFailure catch (failure) {
      _showError(failure.message);
    } finally {
      await _recordingCleanup();
      unawaited(refreshDeviceSafety());
      _stoppingRecording = false;
    }
  }

  Future<void> _monitorRecordingSafety() async {
    if (!isRecording.value || _stoppingRecording) return;
    await refreshDeviceSafety();
    final bool storageCritical =
        availableStorageBytes.value > 0 &&
        availableStorageBytes.value < AppConstants.criticalStorageBytes;
    final bool temperatureCritical =
        thermalState.value == 'critical' || thermalState.value == 'danger';
    if (storageCritical || temperatureCritical) {
      _showError(
        storageCritical
            ? 'Recording stopped safely because free storage fell below 500 MB.'
            : 'Recording stopped safely because the device became too hot.',
      );
      await stopRecording();
    }
  }

  Future<void> togglePause() async {
    if (!isRecording.value) return;
    try {
      if (isPaused.value) {
        await videoRecording.resume();
      } else {
        await videoRecording.pause();
      }
      isPaused.toggle();
    } catch (_) {
      _showError('Pause/resume is not supported by this camera session.');
    }
  }

  Future<void> _recordingCleanup() async {
    _recordingTimer?.cancel();
    isRecording.value = false;
    isPaused.value = false;
    await WakelockPlus.disable();
    try {
      await cameraControl.unlockOrientation();
    } catch (_) {}
  }

  Future<MediaResultEntity> _saveOriginal(MediaResultEntity media) async {
    final PermissionStatusEntity permission = await requestGalleryPermission();
    if (!permission.isUsable) {
      await _permissionFailure(
        'The capture is safe in temporary storage, but gallery permission is needed to keep it.',
        permission,
      );
      return media;
    }
    try {
      return await mediaStorage.save(media);
    } on AppFailure catch (failure) {
      _showError(failure.message);
      return media;
    }
  }

  Future<void> cycleFlash() async {
    if (selectedCamera.value?.flashSupported != true || controlsLocked) {
      _showError('Flash is not available on this camera.');
      return;
    }
    final CameraFlashMode next = switch (flashMode.value) {
      CameraFlashMode.off => CameraFlashMode.auto,
      CameraFlashMode.auto => CameraFlashMode.always,
      CameraFlashMode.always => CameraFlashMode.torch,
      CameraFlashMode.torch => CameraFlashMode.off,
    };
    try {
      await cameraControl.flash(next);
      flashMode.value = next;
    } catch (_) {
      _showError('${next.name} flash is not supported in this mode.');
    }
  }

  void onScaleStart() => _baseZoom = zoomLevel.value;

  Future<void> onScaleUpdate(double scale) async {
    if (!isInitialized.value) return;
    final double next = (_baseZoom * scale).clamp(minZoom.value, maxZoom.value);
    zoomLevel.value = next;
    try {
      await cameraControl.zoom(next);
    } catch (_) {}
  }

  Future<void> selectZoom(double value) async {
    final double next = value.clamp(minZoom.value, maxZoom.value);
    zoomLevel.value = next;
    await cameraControl.zoom(next);
  }

  Future<void> focusAt(Offset normalized, Offset visualPoint) async {
    if (!isInitialized.value) return;
    focusPoint.value = visualPoint;
    focusVisible.value = true;
    _focusTimer?.cancel();
    _focusTimer = Timer(
      const Duration(milliseconds: 1100),
      () => focusVisible.value = false,
    );
    try {
      await Future.wait<void>(<Future<void>>[
        cameraControl.focus(normalized.dx, normalized.dy),
        cameraControl.exposurePoint(normalized.dx, normalized.dy),
      ]);
    } catch (_) {}
  }

  Future<void> setExposure(double value) async {
    exposureOffset.value = value;
    try {
      await cameraControl.exposureOffset(value);
    } catch (_) {}
  }

  Future<void> toggleHdr() async {
    if (!hdrAvailable) {
      _showError('HDR is not exposed for this exact resolution and camera.');
      return;
    }
    final CameraDeviceEntity? device = selectedCamera.value;
    final CameraResolutionEntity? resolution = selectedResolution.value;
    if (device == null || resolution == null || controlsLocked) return;
    if (isRecording.value) await stopRecording();
    final bool previous = hdrEnabled.value;
    final bool desired = !previous;
    isInitializing.value = true;
    isInitialized.value = false;
    try {
      final InitializedCamera initialized = await initializeCamera(
        device: device,
        resolution: resolution,
        fps: selectedFps.value,
        enableAudio: _audioEnabled,
        enableHdr: desired,
      );
      _applyInitialized(initialized);
      await _restoreControls();
      if (desired && !initialized.session.hdrActive) {
        _showError('The active backend could not enable HDR for this format.');
      }
    } catch (_) {
      try {
        _applyInitialized(
          await initializeCamera(
            device: device,
            resolution: resolution,
            fps: selectedFps.value,
            enableAudio: _audioEnabled,
            enableHdr: previous,
          ),
        );
      } catch (_) {
        errorMessage.value = 'The camera session could not be restored.';
      }
      _showError('HDR could not be changed for this camera format.');
    } finally {
      isInitializing.value = false;
    }
  }

  Future<void> requestGalleryForUpload() async {
    final PermissionStatusEntity permission = await requestGalleryPermission(
      readAccess: true,
    );
    if (permission.isUsable) {
      Get.snackbar(
        'Upload',
        'Gallery access is ready. Media picker integration is the next workflow step.',
      );
    } else {
      await _permissionFailure(
        'Gallery access is required to choose existing media.',
        permission,
      );
    }
  }

  Future<void> refreshDeviceSafety() async {
    try {
      availableStorageBytes.value = await mediaStorage.availableBytes();
      thermalState.value = await mediaStorage.thermalState();
    } catch (error) {
      debugLog('Device safety state unavailable', error);
    }
  }

  Future<bool> _confirmEightK() async {
    return await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF17191B),
            title: const Text('Record in real 8K?'),
            content: const Text(
              '8K can use roughly 600 MB per minute, heat the device quickly, and drain the battery. Recording will stop safely if storage or temperature becomes critical.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Record 8K'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _permissionFailure(
    String message,
    PermissionStatusEntity permission,
  ) async {
    if (!permission.shouldOpenSettings) {
      _showError(message);
      return;
    }
    final bool open =
        await Get.dialog<bool>(
          AlertDialog(
            backgroundColor: const Color(0xFF17191B),
            title: const Text('Permission needed'),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Get.back(result: false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Get.back(result: true),
                child: const Text('Open settings'),
              ),
            ],
          ),
        ) ??
        false;
    if (open) await openSettings();
  }

  void _showMediaResult(MediaResultEntity media) {
    final String destination = media.galleryUri == null
        ? 'temporary file'
        : 'gallery';
    Get.snackbar(
      media.type == CapturedMediaType.photo
          ? 'Original photo saved'
          : 'Original video saved',
      '${media.dimensions} • ${media.fileSize} • $destination',
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(16, 56, 16, 0),
      backgroundColor: Colors.black87,
      colorText: Colors.white,
    );
  }

  void _showError(String message) {
    Get.snackbar(
      'Camera',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: const Color(0xDD7B1E27),
      colorText: Colors.white,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_moveToBackground());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeFromBackground());
    }
  }

  Future<void> _moveToBackground() async {
    if (_lifecycleTransition) return;
    _lifecycleTransition = true;
    if (isRecording.value) await stopRecording();
    await cameraControl.dispose();
    isInitialized.value = false;
    session.value = null;
    _lifecycleTransition = false;
  }

  Future<void> _resumeFromBackground() async {
    if (_lifecycleTransition || isInitialized.value) return;
    final CameraDeviceEntity? device = selectedCamera.value;
    final CameraResolutionEntity? resolution = selectedResolution.value;
    if (device == null || resolution == null) {
      await boot();
      return;
    }
    _lifecycleTransition = true;
    isInitializing.value = true;
    try {
      _applyInitialized(
        await initializeCamera(
          device: device,
          resolution: resolution,
          fps: selectedFps.value,
          enableAudio: _audioEnabled,
          enableHdr: hdrEnabled.value && resolution.hdrSupported,
        ),
      );
      await _restoreControls();
    } catch (_) {
      errorMessage.value = 'The camera could not resume. Tap retry.';
    } finally {
      isInitializing.value = false;
      _lifecycleTransition = false;
    }
  }

  void closeApp() => SystemNavigator.pop();

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _focusTimer?.cancel();
    unawaited(WakelockPlus.disable());
    unawaited(cameraControl.dispose());
    super.onClose();
  }
}
