sealed class AppFailure implements Exception {
  const AppFailure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

final class CameraPermissionFailure extends AppFailure {
  const CameraPermissionFailure(super.message, [super.cause]);
}

final class MicrophonePermissionFailure extends AppFailure {
  const MicrophonePermissionFailure(super.message, [super.cause]);
}

final class CameraInitializationFailure extends AppFailure {
  const CameraInitializationFailure(super.message, [super.cause]);
}

final class UnsupportedResolutionFailure extends AppFailure {
  const UnsupportedResolutionFailure(super.message, [super.cause]);
}

final class RecordingFailure extends AppFailure {
  const RecordingFailure(super.message, [super.cause]);
}

final class CaptureFailure extends AppFailure {
  const CaptureFailure(super.message, [super.cause]);
}

final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, [super.cause]);
}

final class GallerySaveFailure extends AppFailure {
  const GallerySaveFailure(super.message, [super.cause]);
}

final class NativeCameraCapabilityFailure extends AppFailure {
  const NativeCameraCapabilityFailure(super.message, [super.cause]);
}
