import '../../domain/entities/short_video_entity.dart';

abstract final class ShortVideoModel {
  static ShortVideoEntity fromJson(Map<String, dynamic> json) =>
      ShortVideoEntity(
        id: _string(json['id']),
        videoUrl: _string(json['videoUrl']),
        thumbnailUrl: _string(json['thumbnailUrl']),
        username: _string(json['username']),
        displayName: _string(json['displayName']),
        avatarUrl: json['avatarUrl'] as String?,
        caption: _string(json['caption']),
        hashtags: (json['hashtags'] as List<dynamic>? ?? const <dynamic>[])
            .map((dynamic item) => item.toString())
            .toList(growable: false),
        soundName: _string(json['soundName']),
        likesCount: _int(json['likesCount']),
        commentsCount: _int(json['commentsCount']),
        bookmarksCount: _int(json['bookmarksCount']),
        sharesCount: _int(json['sharesCount']),
        viewsCount: _int(json['viewsCount']),
        isLiked: json['isLiked'] == true,
        isBookmarked: json['isBookmarked'] == true,
      );

  static VideoCommentEntity commentFromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> user =
        (json['user'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return VideoCommentEntity(
      id: _string(json['id']),
      body: _string(json['body']),
      username: _string(user['username'], 'viewer'),
      displayName: _string(user['displayName'], 'Viewer'),
      avatarUrl: user['avatarUrl'] as String?,
      createdAt:
          DateTime.tryParse(_string(json['createdAt'])) ?? DateTime.now(),
    );
  }

  static String _string(Object? value, [String fallback = '']) =>
      value?.toString() ?? fallback;
  static int _int(Object? value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
}
