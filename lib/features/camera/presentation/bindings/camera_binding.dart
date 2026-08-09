import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';

import '../../../../core/services/permissions/permission_service.dart';
import '../../../../core/services/resolution_selection_service.dart';
import '../../data/datasources/camera_local_data_source.dart';
import '../../data/repositories/camera_repository_impl.dart';
import '../../domain/repositories/camera_repository.dart';
import '../../domain/repositories/permission_repository.dart';
import '../../domain/usecases/camera_usecases.dart';
import '../../domain/usecases/permission_usecases.dart';
import '../controllers/camera_controller_getx.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermissionRepository>(
      () => PermissionService(DeviceInfoPlugin()),
      fenix: true,
    );
    Get.lazyPut<CameraLocalDataSource>(
      () => CameraLocalDataSourceImpl(const ResolutionSelectionService()),
      fenix: true,
    );
    Get.lazyPut<CameraRepository>(
      () => CameraRepositoryImpl(Get.find()),
      fenix: true,
    );
    Get.lazyPut(() => GetCameraDevicesUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => InitializeCameraUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => CapturePhotoUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => VideoRecordingUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => CameraControlUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => MediaStorageUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => RequestCameraPermissionUseCase(Get.find()), fenix: true);
    Get.lazyPut(
      () => RequestMicrophonePermissionUseCase(Get.find()),
      fenix: true,
    );
    Get.lazyPut(() => RequestGalleryPermissionUseCase(Get.find()), fenix: true);
    Get.lazyPut(() => OpenApplicationSettingsUseCase(Get.find()), fenix: true);
    Get.lazyPut(
      () => CameraControllerGetX(
        getCameras: Get.find(),
        initializeCamera: Get.find(),
        capturePhoto: Get.find(),
        videoRecording: Get.find(),
        cameraControl: Get.find(),
        mediaStorage: Get.find(),
        requestCameraPermission: Get.find(),
        requestMicrophonePermission: Get.find(),
        requestGalleryPermission: Get.find(),
        openSettings: Get.find(),
      ),
    );
  }
}
