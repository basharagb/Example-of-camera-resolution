import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../utils/debug_log.dart';
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

    // Already settled in a way no prompt would change.
    if (current.isGranted || current.isLimited) {
      return _map(current);
    }

    // Everything else goes through request(). Asking is always safe: when the
    // user has already made a permanent choice the platform returns it
    // immediately without showing anything, and when the status was merely
    // "not yet determined" this is the call that actually shows the prompt.
    //
    // Reading `status` alone is not enough to decide: on iOS a permission that
    // has never been asked for reports the same value as one the user denied,
    // so trusting it would send a first-time user straight to a Settings
    // screen they never needed to visit.
    final PermissionStatus result = await permission.request();

    // Logged because the difference between "never asked" and "refused
    // earlier" is invisible in the UI but decides whether a prompt can still
    // appear at all.
    debugLog('permission $permission: $current -> $result');
    return _map(result);
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
