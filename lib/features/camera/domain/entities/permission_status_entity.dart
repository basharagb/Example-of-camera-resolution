enum PermissionStatusKind {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  limited,
}

class PermissionStatusEntity {
  const PermissionStatusEntity(this.status);
  final PermissionStatusKind status;

  bool get isUsable =>
      status == PermissionStatusKind.granted ||
      status == PermissionStatusKind.limited;
  bool get shouldOpenSettings =>
      status == PermissionStatusKind.permanentlyDenied ||
      status == PermissionStatusKind.restricted;
}
