import '../../domain/entities/short_video_entity.dart';
import '../../domain/repositories/short_video_repository.dart';

/// The feed, served from the bundle.
///
/// The clips and their covers ship inside the app, so the home screen fills on
/// first frame with no request, no cache warm-up and no spinner waiting on a
/// timeout. Likes, bookmarks, views and comments are held in memory for the
/// life of the process, which is enough for a demo to feel like a real account
/// and short enough that every run starts clean.
class DemoShortVideoRepository implements ShortVideoRepository {
  final Map<String, ShortVideoEntity> _videos = <String, ShortVideoEntity>{
    for (final ShortVideoEntity video in demoFeedVideos) video.id: video,
  };

  final Map<String, List<VideoCommentEntity>> _comments =
      <String, List<VideoCommentEntity>>{};

  int _sequence = 0;

  @override
  Future<List<ShortVideoEntity>> feed({int page = 1, int pageSize = 10}) async {
    if (page > 1) {
      // A fixed bundle is one page; paging past it ends the feed rather than
      // looping the same six clips forever.
      return const <ShortVideoEntity>[];
    }
    return _videos.values.toList(growable: false);
  }

  @override
  Future<ShortVideoEntity> setLiked(String id, bool active) async {
    final ShortVideoEntity video = _require(id);
    return _videos[id] = video.copyWith(
      isLiked: active,
      likesCount: video.likesCount + (active ? 1 : -1),
    );
  }

  @override
  Future<ShortVideoEntity> setBookmarked(String id, bool active) async {
    final ShortVideoEntity video = _require(id);
    return _videos[id] = video.copyWith(
      isBookmarked: active,
      bookmarksCount: video.bookmarksCount + (active ? 1 : -1),
    );
  }

  @override
  Future<void> recordView(String id) async {
    final ShortVideoEntity video = _require(id);
    _videos[id] = video.copyWith(viewsCount: video.viewsCount + 1);
  }

  @override
  Future<void> recordShare(String id) async {
    final ShortVideoEntity video = _require(id);
    _videos[id] = video.copyWith(sharesCount: video.sharesCount + 1);
  }

  @override
  Future<List<VideoCommentEntity>> comments(String id) async =>
      List<VideoCommentEntity>.unmodifiable(_comments[id] ?? _seedComments(id));

  @override
  Future<VideoCommentEntity> addComment(String id, String body) async {
    final VideoCommentEntity comment = VideoCommentEntity(
      id: 'demo-comment-${_sequence++}',
      body: body,
      username: 'bashar',
      displayName: 'Bashar',
      createdAt: DateTime.now(),
    );
    (_comments[id] ??= _seedComments(id)).insert(0, comment);
    final ShortVideoEntity video = _require(id);
    _videos[id] = video.copyWith(commentsCount: video.commentsCount + 1);
    return comment;
  }

  ShortVideoEntity _require(String id) =>
      _videos[id] ?? (throw StateError('Unknown demo video: $id'));

  /// A thread that is already in progress, so the sheet is never an empty box
  /// waiting for the reviewer to type the first line themselves.
  List<VideoCommentEntity> _seedComments(String id) {
    final DateTime now = DateTime.now();
    final List<VideoCommentEntity> seeded = <VideoCommentEntity>[
      VideoCommentEntity(
        id: '$id-c1',
        body: 'التصوير نظيف كثير 👌',
        username: 'sara.q',
        displayName: 'Sara',
        createdAt: now.subtract(const Duration(minutes: 7)),
      ),
      VideoCommentEntity(
        id: '$id-c2',
        body: 'saved this one, thanks!',
        username: 'rami.dev',
        displayName: 'Rami',
        createdAt: now.subtract(const Duration(minutes: 21)),
      ),
      VideoCommentEntity(
        id: '$id-c3',
        body: 'من وين هالمكان؟',
        username: 'khaled.k',
        displayName: 'Khaled',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
    return _comments[id] = seeded;
  }
}

/// The bundled feed. Also used as the networked repository's fallback, so both
/// builds show the same six clips.
const List<ShortVideoEntity> demoFeedVideos = <ShortVideoEntity>[
  ShortVideoEntity(
    id: 'demo-petra',
    videoUrl: 'asset://assets/demo/feed/petra.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/petra.jpg',
    username: 'nour.jordan',
    displayName: 'Nour',
    caption: 'غروب ذهبي من البتراء لا يُنسى',
    hashtags: <String>['الأردن', 'سفر'],
    soundName: 'Jordan nights',
    likesCount: 18200,
    commentsCount: 680,
    bookmarksCount: 910,
    sharesCount: 420,
    viewsCount: 138000,
  ),
  ShortVideoEntity(
    id: 'demo-coffee',
    videoUrl: 'asset://assets/demo/feed/coffee.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/coffee.jpg',
    username: 'daily.lina',
    displayName: 'Lina',
    caption: 'تفاصيل قهوتي الصباحية ☕',
    hashtags: <String>['قهوة', 'روتين'],
    soundName: 'Morning mood',
    likesCount: 16900,
    commentsCount: 633,
    bookmarksCount: 855,
    sharesCount: 389,
    viewsCount: 129200,
  ),
  ShortVideoEntity(
    id: 'demo-basketball',
    videoUrl: 'asset://assets/demo/feed/basketball.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/basketball.jpg',
    username: 'omar.hoops',
    displayName: 'Omar',
    caption: 'آخر ثانية قلبت المباراة',
    hashtags: <String>['رياضة', 'كرة_سلة'],
    soundName: 'Arena bounce',
    likesCount: 15600,
    commentsCount: 586,
    bookmarksCount: 800,
    sharesCount: 358,
    viewsCount: 120400,
  ),
  ShortVideoEntity(
    id: 'demo-food',
    videoUrl: 'asset://assets/demo/feed/healthy-food.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/healthy-food.jpg',
    username: 'fit.sara',
    displayName: 'Sara',
    caption: 'وجبة سريعة ومليئة بالألوان',
    hashtags: <String>['صحي', 'وصفة'],
    soundName: 'Fresh kitchen',
    likesCount: 14300,
    commentsCount: 539,
    bookmarksCount: 745,
    sharesCount: 327,
    viewsCount: 111600,
  ),
  ShortVideoEntity(
    id: 'demo-motorcycle',
    videoUrl: 'asset://assets/demo/feed/motorcycle.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/motorcycle.jpg',
    username: 'ride.with.ali',
    displayName: 'Ali',
    caption: 'حرية الطريق بين رمال وادي رم',
    hashtags: <String>['دراجات', 'مغامرة'],
    soundName: 'Desert engine',
    likesCount: 13000,
    commentsCount: 492,
    bookmarksCount: 690,
    sharesCount: 296,
    viewsCount: 102800,
  ),
  ShortVideoEntity(
    id: 'demo-whale',
    videoUrl: 'asset://assets/demo/feed/whale.mp4',
    thumbnailUrl: 'asset://assets/demo/feed/whale.jpg',
    username: 'blue.world',
    displayName: 'Maya',
    caption: 'لحظة هادئة في العالم الأزرق',
    hashtags: <String>['بحر', 'حياة_برية'],
    soundName: 'Deep ocean',
    likesCount: 11700,
    commentsCount: 445,
    bookmarksCount: 635,
    sharesCount: 265,
    viewsCount: 94000,
  ),
];
