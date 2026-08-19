import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/api_client.dart';
import '../../domain/entities/short_video_entity.dart';
import '../../domain/repositories/short_video_repository.dart';
import '../local/demo_short_video_repository.dart';
import '../models/short_video_model.dart';

class ShortVideoRepositoryImpl implements ShortVideoRepository {
  const ShortVideoRepositoryImpl(this._client);
  final ApiClient _client;

  @override
  Future<List<ShortVideoEntity>> feed({int page = 1, int pageSize = 10}) async {
    try {
      final Map<String, dynamic> data = await _client.get(
        '/videos/feed',
        query: <String, dynamic>{'page': page, 'pageSize': pageSize},
      );
      return ((data['items'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic json) =>
                ShortVideoModel.fromJson((json as Map).cast<String, dynamic>()),
          )
          .toList(growable: false);
    } on AppFailure {
      // The demo never becomes an empty loading screen if the server is being
      // restarted; interaction calls still target the real API when it returns.
      return demoFeedVideos;
    }
  }

  @override
  Future<ShortVideoEntity> setLiked(String id, bool active) =>
      _interaction(id, 'like', active);

  @override
  Future<ShortVideoEntity> setBookmarked(String id, bool active) =>
      _interaction(id, 'bookmark', active);

  Future<ShortVideoEntity> _interaction(
    String id,
    String action,
    bool active,
  ) async {
    final Map<String, dynamic> data = await _client.post(
      '/videos/$id/$action',
      body: <String, dynamic>{'active': active},
    );
    return ShortVideoModel.fromJson(
      (data['video'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<void> recordView(String id) async {
    await _client.post('/videos/$id/view');
  }

  @override
  Future<void> recordShare(String id) async {
    await _client.post('/videos/$id/share');
  }

  @override
  Future<List<VideoCommentEntity>> comments(String id) async {
    final Map<String, dynamic> data = await _client.get('/videos/$id/comments');
    return ((data['items'] as List<dynamic>?) ?? const <dynamic>[])
        .map(
          (dynamic json) => ShortVideoModel.commentFromJson(
            (json as Map).cast<String, dynamic>(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<VideoCommentEntity> addComment(String id, String body) async {
    final Map<String, dynamic> data = await _client.post(
      '/videos/$id/comments',
      body: <String, dynamic>{'body': body},
    );
    return ShortVideoModel.commentFromJson(
      (data['comment'] as Map).cast<String, dynamic>(),
    );
  }
}
