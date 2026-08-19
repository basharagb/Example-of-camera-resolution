import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/api_client.dart';
import '../../domain/entities/short_video_entity.dart';
import '../../domain/repositories/short_video_repository.dart';
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
          .map((dynamic json) => ShortVideoModel.fromJson((json as Map).cast<String, dynamic>()))
          .toList(growable: false);
    } on AppFailure {
      // The demo never becomes an empty loading screen if the server is being
      // restarted; interaction calls still target the real API when it returns.
      return _demoFeed;
    }
  }

  @override
  Future<ShortVideoEntity> setLiked(String id, bool active) => _interaction(id, 'like', active);

  @override
  Future<ShortVideoEntity> setBookmarked(String id, bool active) => _interaction(id, 'bookmark', active);

  Future<ShortVideoEntity> _interaction(String id, String action, bool active) async {
    final Map<String, dynamic> data = await _client.post(
      '/videos/$id/$action',
      body: <String, dynamic>{'active': active},
    );
    return ShortVideoModel.fromJson((data['video'] as Map).cast<String, dynamic>());
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
        .map((dynamic json) => ShortVideoModel.commentFromJson((json as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  @override
  Future<VideoCommentEntity> addComment(String id, String body) async {
    final Map<String, dynamic> data = await _client.post(
      '/videos/$id/comments',
      body: <String, dynamic>{'body': body},
    );
    return ShortVideoModel.commentFromJson((data['comment'] as Map).cast<String, dynamic>());
  }
}

const List<ShortVideoEntity> _demoFeed = <ShortVideoEntity>[
  ShortVideoEntity(id: 'demo-petra', videoUrl: 'asset://assets/demo/feed/petra.mp4', thumbnailUrl: 'asset://assets/demo/feed/petra.jpg', username: 'nour.jordan', displayName: 'Nour', caption: 'غروب ذهبي من البتراء لا يُنسى', hashtags: <String>['الأردن', 'سفر'], soundName: 'Jordan nights', likesCount: 18200, commentsCount: 680, bookmarksCount: 910, sharesCount: 420, viewsCount: 138000),
  ShortVideoEntity(id: 'demo-coffee', videoUrl: 'asset://assets/demo/feed/coffee.mp4', thumbnailUrl: 'asset://assets/demo/feed/coffee.jpg', username: 'daily.lina', displayName: 'Lina', caption: 'تفاصيل قهوتي الصباحية ☕', hashtags: <String>['قهوة', 'روتين'], soundName: 'Morning mood', likesCount: 16900, commentsCount: 633, bookmarksCount: 855, sharesCount: 389, viewsCount: 129200),
  ShortVideoEntity(id: 'demo-basketball', videoUrl: 'asset://assets/demo/feed/basketball.mp4', thumbnailUrl: 'asset://assets/demo/feed/basketball.jpg', username: 'omar.hoops', displayName: 'Omar', caption: 'آخر ثانية قلبت المباراة', hashtags: <String>['رياضة', 'كرة_سلة'], soundName: 'Arena bounce', likesCount: 15600, commentsCount: 586, bookmarksCount: 800, sharesCount: 358, viewsCount: 120400),
  ShortVideoEntity(id: 'demo-food', videoUrl: 'asset://assets/demo/feed/healthy-food.mp4', thumbnailUrl: 'asset://assets/demo/feed/healthy-food.jpg', username: 'fit.sara', displayName: 'Sara', caption: 'وجبة سريعة ومليئة بالألوان', hashtags: <String>['صحي', 'وصفة'], soundName: 'Fresh kitchen', likesCount: 14300, commentsCount: 539, bookmarksCount: 745, sharesCount: 327, viewsCount: 111600),
  ShortVideoEntity(id: 'demo-motorcycle', videoUrl: 'asset://assets/demo/feed/motorcycle.mp4', thumbnailUrl: 'asset://assets/demo/feed/motorcycle.jpg', username: 'ride.with.ali', displayName: 'Ali', caption: 'حرية الطريق بين رمال وادي رم', hashtags: <String>['دراجات', 'مغامرة'], soundName: 'Desert engine', likesCount: 13000, commentsCount: 492, bookmarksCount: 690, sharesCount: 296, viewsCount: 102800),
  ShortVideoEntity(id: 'demo-whale', videoUrl: 'asset://assets/demo/feed/whale.mp4', thumbnailUrl: 'asset://assets/demo/feed/whale.jpg', username: 'blue.world', displayName: 'Maya', caption: 'لحظة هادئة في العالم الأزرق', hashtags: <String>['بحر', 'حياة_برية'], soundName: 'Deep ocean', likesCount: 11700, commentsCount: 445, bookmarksCount: 635, sharesCount: 265, viewsCount: 94000),
];
