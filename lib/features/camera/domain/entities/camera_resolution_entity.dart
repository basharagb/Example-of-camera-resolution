class CameraResolutionEntity {
  const CameraResolutionEntity({
    required this.width,
    required this.height,
    required this.maxFps,
    required this.hdrSupported,
    this.supportedFps = const <int>[],
    this.recommended = false,
  });

  final int width;
  final int height;
  final int maxFps;
  final List<int> supportedFps;
  final bool hdrSupported;
  final bool recommended;

  int get longEdge => width > height ? width : height;
  int get shortEdge => width < height ? width : height;
  int get pixels => width * height;
  double get aspectRatio => longEdge / shortEdge;
  bool get isVideoAspect => (aspectRatio - (16 / 9)).abs() < 0.12;

  String get label {
    if (longEdge >= 7000 || shortEdge >= 4000) return '8K';
    if (longEdge >= 3800 || shortEdge >= 2100) return '4K';
    if (longEdge >= 2500 || shortEdge >= 1400) return '2K';
    if (longEdge >= 1900 || shortEdge >= 1000) return '1080p';
    if (longEdge >= 1200 || shortEdge >= 700) return '720p';
    if (longEdge >= 700 || shortEdge >= 470) return '480p';
    return '${shortEdge}p';
  }

  String get dimensions => '$longEdge × $shortEdge';
  String get displayLabel => isVideoAspect ? label : '$label MAX';
  bool get isEightK => label == '8K';

  int bitrateFor(int fps) {
    final double fpsFactor = fps / 30.0;
    final int base = switch (label) {
      '8K' => 100000000,
      '4K' => 48000000,
      '2K' => 24000000,
      '1080p' => 16000000,
      '720p' => 8000000,
      _ => 4000000,
    };
    return (base * fpsFactor.clamp(0.7, 1.65)).round();
  }

  @override
  bool operator ==(Object other) =>
      other is CameraResolutionEntity &&
      width == other.width &&
      height == other.height;

  @override
  int get hashCode => Object.hash(width, height);
}
