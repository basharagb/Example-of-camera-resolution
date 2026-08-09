import '../entities/permission_status_entity.dart';

abstract interface class PermissionRepository {
  Future<PermissionStatusEntity> requestCamera();
  Future<PermissionStatusEntity> requestMicrophone();
  Future<PermissionStatusEntity> requestGallery({required bool readAccess});
  Future<bool> openSettings();
}
