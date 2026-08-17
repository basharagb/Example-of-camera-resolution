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

// ---------------------------------------------------------------------------
// Live streaming and API failures.
//
// AppFailure is sealed, so every variant lives here. The payoff is that a
// single `switch` over an AppFailure is exhaustive and the compiler flags any
// case the UI forgot to handle.
// ---------------------------------------------------------------------------

/// The request never reached the server: no connectivity, DNS, or a timeout.
final class NetworkFailure extends AppFailure {
  const NetworkFailure(super.message, [super.cause]);
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure(super.message, [super.cause]);
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure(super.message, [super.cause]);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message, [super.cause]);
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure(super.message, [super.cause]);
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message, [super.cause]);
}

/// A gift cost more than the wallet holds. Carries the shortfall so the sheet
/// can offer to top up exactly what is missing instead of a generic error.
final class InsufficientBalanceFailure extends AppFailure {
  const InsufficientBalanceFailure(
    super.message, {
    required this.requiredCoins,
    required this.availableCoins,
  });

  final int requiredCoins;
  final int availableCoins;

  int get missingCoins => requiredCoins - availableCoins;
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure(super.message, [super.cause]);
}

final class ServerFailure extends AppFailure {
  const ServerFailure(super.message, [super.cause]);
}

/// The media engine failed: bad token, channel rejected, or a lost publish.
final class BroadcastFailure extends AppFailure {
  const BroadcastFailure(super.message, [super.cause]);
}
