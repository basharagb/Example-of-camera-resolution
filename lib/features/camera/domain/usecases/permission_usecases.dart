import '../entities/permission_status_entity.dart';
import '../repositories/permission_repository.dart';

class RequestCameraPermissionUseCase {
  const RequestCameraPermissionUseCase(this._repository);
  final PermissionRepository _repository;
  Future<PermissionStatusEntity> call() => _repository.requestCamera();
}

class RequestMicrophonePermissionUseCase {
  const RequestMicrophonePermissionUseCase(this._repository);
  final PermissionRepository _repository;
  Future<PermissionStatusEntity> call() => _repository.requestMicrophone();
}

class RequestGalleryPermissionUseCase {
  const RequestGalleryPermissionUseCase(this._repository);
  final PermissionRepository _repository;
  Future<PermissionStatusEntity> call({bool readAccess = false}) =>
      _repository.requestGallery(readAccess: readAccess);
}

class OpenApplicationSettingsUseCase {
  const OpenApplicationSettingsUseCase(this._repository);
  final PermissionRepository _repository;
  Future<bool> call() => _repository.openSettings();
}
