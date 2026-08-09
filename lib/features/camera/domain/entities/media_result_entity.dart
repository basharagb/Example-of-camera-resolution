enum CapturedMediaType { photo, video }

class MediaResultEntity {
  const MediaResultEntity({
    required this.path,
    required this.type,
    required this.width,
    required this.height,
    required this.bytes,
    this.duration = Duration.zero,
    this.galleryUri,
  });

  final String path;
  final CapturedMediaType type;
  final int width;
  final int height;
  final int bytes;
  final Duration duration;
  final String? galleryUri;

  String get dimensions =>
      width > 0 && height > 0 ? '$width × $height' : 'Metadata unavailable';
  String get fileSize {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  MediaResultEntity copyWith({String? galleryUri}) => MediaResultEntity(
    path: path,
    type: type,
    width: width,
    height: height,
    bytes: bytes,
    duration: duration,
    galleryUri: galleryUri ?? this.galleryUri,
  );
}
