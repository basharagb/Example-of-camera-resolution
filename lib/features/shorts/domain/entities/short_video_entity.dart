import 'package:flutter/foundation.dart';

@immutable
class ShortVideoEntity {
  const ShortVideoEntity({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.username,
    required this.displayName,
    required this.caption,
    required this.hashtags,
    required this.soundName,
    required this.likesCount,
    required this.commentsCount,
    required this.bookmarksCount,
    required this.sharesCount,
    required this.viewsCount,
    this.avatarUrl,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String caption;
  final List<String> hashtags;
  final String soundName;
  final int likesCount;
  final int commentsCount;
  final int bookmarksCount;
  final int sharesCount;
  final int viewsCount;
  final bool isLiked;
  final bool isBookmarked;

  bool get isBundled => videoUrl.startsWith('asset://');
  String get playableUrl => videoUrl.replaceFirst('asset://', '');
  String get thumbnailPath => thumbnailUrl.replaceFirst('asset://', '');

  ShortVideoEntity copyWith({
    int? likesCount,
    int? commentsCount,
    int? bookmarksCount,
    int? sharesCount,
    int? viewsCount,
    bool? isLiked,
    bool? isBookmarked,
  }) => ShortVideoEntity(
    id: id,
    videoUrl: videoUrl,
    thumbnailUrl: thumbnailUrl,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    caption: caption,
    hashtags: hashtags,
    soundName: soundName,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    bookmarksCount: bookmarksCount ?? this.bookmarksCount,
    sharesCount: sharesCount ?? this.sharesCount,
    viewsCount: viewsCount ?? this.viewsCount,
    isLiked: isLiked ?? this.isLiked,
    isBookmarked: isBookmarked ?? this.isBookmarked,
  );
}

@immutable
class VideoCommentEntity {
  const VideoCommentEntity({
    required this.id,
    required this.body,
    required this.username,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
  });

  final String id;
  final String body;
  final String username;
  final String displayName;
  final DateTime createdAt;
  final String? avatarUrl;
}
