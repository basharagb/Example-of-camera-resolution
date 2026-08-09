abstract final class AppConstants {
  static const String cameraChannel =
      'com.highest.camera.apex_camera/capabilities';
  static const int criticalStorageBytes = 500 * 1024 * 1024;
  static const int eightKWarningBytesPerMinute = 600 * 1024 * 1024;
  static const Duration initializationTimeout = Duration(seconds: 20);
  static const Duration controlsAnimationDuration = Duration(milliseconds: 220);
}
