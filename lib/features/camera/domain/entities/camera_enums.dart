enum CameraMode { photo, video }

enum CameraLensDirection { front, back, external }

enum CameraFlashMode { off, auto, always, torch }

enum CaptureDurationOption {
  fifteenSeconds('15s', Duration(seconds: 15)),
  sixtySeconds('60s', Duration(seconds: 60)),
  threeMinutes('3m', Duration(minutes: 3)),
  unlimited('∞', null);

  const CaptureDurationOption(this.label, this.limit);
  final String label;
  final Duration? limit;
}
