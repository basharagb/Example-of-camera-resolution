import '../entities/short_video_entity.dart';

abstract interface class ShortVideoRepository {
  Future<List<ShortVideoEntity>> feed({int page = 1, int pageSize = 10});
  Future<ShortVideoEntity> setLiked(String id, bool active);
  Future<ShortVideoEntity> setBookmarked(String id, bool active);
  Future<void> recordView(String id);
  Future<void> recordShare(String id);
  Future<List<VideoCommentEntity>> comments(String id);
  Future<VideoCommentEntity> addComment(String id, String body);
}
