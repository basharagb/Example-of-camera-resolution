import 'package:apex_camera/features/shorts/domain/entities/short_video_entity.dart';
import 'package:apex_camera/features/shorts/domain/repositories/short_video_repository.dart';
import 'package:apex_camera/features/shorts/domain/usecases/short_video_usecases.dart';
import 'package:apex_camera/features/shorts/presentation/controllers/video_feed_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('optimistic like is reconciled with repository response', () async {
    final _FakeVideoRepository repository = _FakeVideoRepository();
    final VideoFeedController controller = VideoFeedController(
      loadFeed: LoadVideoFeedUseCase(repository),
      setLiked: SetVideoLikedUseCase(repository),
      setBookmarked: SetVideoBookmarkedUseCase(repository),
      repository: repository,
    )..videos.addAll(<ShortVideoEntity>[repository.video]);

    await controller.toggleLike(repository.video);

    expect(controller.videos.single.isLiked, isTrue);
    expect(controller.videos.single.likesCount, 11);
    expect(repository.lastLike, isTrue);
  });

  test('feed model exposes bundled asset path without its scheme', () {
    const ShortVideoEntity video = ShortVideoEntity(
      id: 'v1',
      videoUrl: 'asset://assets/demo/feed/petra.mp4',
      thumbnailUrl: 'asset://assets/demo/feed/petra.jpg',
      username: 'nour',
      displayName: 'Nour',
      caption: 'Petra',
      hashtags: <String>['Jordan'],
      soundName: 'demo',
      likesCount: 1,
      commentsCount: 2,
      bookmarksCount: 3,
      sharesCount: 4,
      viewsCount: 5,
    );

    expect(video.isBundled, isTrue);
    expect(video.playableUrl, 'assets/demo/feed/petra.mp4');
  });
}

class _FakeVideoRepository implements ShortVideoRepository {
  final ShortVideoEntity video = const ShortVideoEntity(
    id: 'v1',
    videoUrl: 'asset://assets/demo/feed/petra.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/petra.jpg',
    username: 'nour',
    displayName: 'Nour',
    caption: 'Petra',
    hashtags: <String>['Jordan'],
    soundName: 'demo',
    likesCount: 10,
    commentsCount: 2,
    bookmarksCount: 3,
    sharesCount: 4,
    viewsCount: 5,
  );

  bool? lastLike;

  @override
  Future<List<ShortVideoEntity>> feed({
    int page = 1,
    int pageSize = 10,
  }) async => <ShortVideoEntity>[video];

  @override
  Future<ShortVideoEntity> setLiked(String id, bool active) async {
    lastLike = active;
    return video.copyWith(isLiked: active, likesCount: 11);
  }

  @override
  Future<ShortVideoEntity> setBookmarked(String id, bool active) async =>
      video.copyWith(isBookmarked: active);

  @override
  Future<void> recordView(String id) async {}

  @override
  Future<void> recordShare(String id) async {}

  @override
  Future<List<VideoCommentEntity>> comments(String id) async =>
      const <VideoCommentEntity>[];

  @override
  Future<VideoCommentEntity> addComment(String id, String body) =>
      throw UnimplementedError();
}
