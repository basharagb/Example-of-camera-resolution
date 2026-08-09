import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../features/camera/domain/entities/permission_status_entity.dart';
import '../../../features/camera/domain/repositories/permission_repository.dart';

class PermissionService implements PermissionRepository {
  PermissionService(this._deviceInfo);

  final DeviceInfoPlugin _deviceInfo;

  @override
  Future<PermissionStatusEntity> requestCamera() => _request(Permission.camera);

  @override
  Future<PermissionStatusEntity> requestMicrophone() =>
      _request(Permission.microphone);

  @override
  Future<PermissionStatusEntity> requestGallery({
    required bool readAccess,
  }) async {
    if (Platform.isIOS) {
      return _request(
        readAccess ? Permission.photos : Permission.photosAddOnly,
      );
    }
    if (Platform.isAndroid) {
      final int sdk = (await _deviceInfo.androidInfo).version.sdkInt;
      // MediaStore needs no broad permission when this app only adds its own media.
      if (!readAccess && sdk >= 29) {
        return const PermissionStatusEntity(PermissionStatusKind.granted);
      }
      if (sdk >= 33) {
        final List<PermissionStatus> statuses = await <Permission>[
          Permission.photos,
          Permission.videos,
        ].request().then((value) => value.values.toList());
        return _combine(statuses);
      }
      return _request(Permission.storage);
    }
    return const PermissionStatusEntity(PermissionStatusKind.granted);
  }

  Future<PermissionStatusEntity> _request(Permission permission) async {
    final PermissionStatus current = await permission.status;
    if (current.isGranted ||
        current.isLimited ||
        current.isRestricted ||
        current.isPermanentlyDenied) {
      return _map(current);
    }
    return _map(await permission.request());
  }

  PermissionStatusEntity _combine(List<PermissionStatus> statuses) {
    if (statuses.any((status) => status.isGranted || status.isLimited)) {
      return const PermissionStatusEntity(PermissionStatusKind.granted);
    }
    if (statuses.any((status) => status.isPermanentlyDenied)) {
      return const PermissionStatusEntity(
        PermissionStatusKind.permanentlyDenied,
      );
    }
    return const PermissionStatusEntity(PermissionStatusKind.denied);
  }

  PermissionStatusEntity _map(PermissionStatus status) {
    if (status.isGranted) {
      return const PermissionStatusEntity(PermissionStatusKind.granted);
    }
    if (status.isLimited) {
      return const PermissionStatusEntity(PermissionStatusKind.limited);
    }
    if (status.isPermanentlyDenied) {
      return const PermissionStatusEntity(
        PermissionStatusKind.permanentlyDenied,
      );
    }
    if (status.isRestricted) {
      return const PermissionStatusEntity(PermissionStatusKind.restricted);
    }
    return const PermissionStatusEntity(PermissionStatusKind.denied);
  }

  @override
  Future<bool> openSettings() => openAppSettings();
}
