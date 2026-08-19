import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/live_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../../live/presentation/controllers/session_controller.dart';
import '../../domain/entities/short_video_entity.dart';
import '../../domain/repositories/short_video_repository.dart';
import '../controllers/video_feed_controller.dart';

class VideoFeedPage extends StatefulWidget {
  const VideoFeedPage({super.key});

  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  final VideoFeedController _controller = Get.find<VideoFeedController>();
  final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Obx(() {
      if (_controller.isLoading.value && _controller.videos.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      if (_controller.videos.isEmpty) {
        return _FeedError(onRetry: _controller.refreshFeed);
      }
      final int active = _controller.currentIndex.value;
      return Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: _controller.videos.length,
            onPageChanged: _controller.pageChanged,
            itemBuilder: (BuildContext context, int index) => _VideoPage(
              key: ValueKey<String>(_controller.videos[index].id),
              video: _controller.videos[index],
              isActive: index == active,
              shouldLoad: (index - active).abs() <= 1,
              onLike: () => _controller.toggleLike(_controller.videos[index]),
              onBookmark: () =>
                  _controller.toggleBookmark(_controller.videos[index]),
              onShare: () => _controller.share(_controller.videos[index]),
              onComments: () => _CommentsSheet.show(
                context,
                _controller.videos[index],
                _controller.repository,
              ),
            ),
          ),
          const _TopNavigation(),
          const _BottomNavigation(),
        ],
      );
    }),
  );
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.video,
    required this.isActive,
    required this.shouldLoad,
    required this.onLike,
    required this.onBookmark,
    required this.onShare,
    required this.onComments,
    super.key,
  });

  final ShortVideoEntity video;
  final bool isActive;
  final bool shouldLoad;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  final VoidCallback onComments;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _player;
  bool _showHeart = false;
  Timer? _heartTimer;

  @override
  void initState() {
    super.initState();
    if (widget.shouldLoad) unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldLoad && _player == null) unawaited(_load());
    if (!widget.shouldLoad && _player != null) unawaited(_release());
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(_player?.play());
    } else if (!widget.isActive && oldWidget.isActive) {
      unawaited(_player?.pause());
    }
  }

  Future<void> _load() async {
    final VideoPlayerController player = widget.video.isBundled
        ? VideoPlayerController.asset(widget.video.playableUrl)
        : VideoPlayerController.networkUrl(Uri.parse(widget.video.playableUrl));
    _player = player;
    try {
      await player.initialize();
      await player.setLooping(true);
      await player.setVolume(1);
      if (widget.isActive) await player.play();
      if (mounted) setState(() {});
    } catch (_) {
      await player.dispose();
      if (identical(_player, player)) _player = null;
    }
  }

  Future<void> _release() async {
    final VideoPlayerController? player = _player;
    _player = null;
    await player?.dispose();
    if (mounted) setState(() {});
  }

  void _doubleLike() {
    if (!widget.video.isLiked) widget.onLike();
    _heartTimer?.cancel();
    setState(() => _showHeart = true);
    _heartTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  void dispose() {
    _heartTimer?.cancel();
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? player = _player;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (player == null) return;
        player.value.isPlaying ? player.pause() : player.play();
        setState(() {});
      },
      onDoubleTap: _doubleLike,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(widget.video.thumbnailPath, fit: BoxFit.cover),
          if (player?.value.isInitialized ?? false)
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: player!.value.size.width,
                height: player.value.size.height,
                child: VideoPlayer(player),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0x52000000),
                  Colors.transparent,
                  Color(0xC9000000),
                ],
                stops: <double>[0, 0.46, 1],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 82,
            bottom: 88,
            child: _Caption(video: widget.video),
          ),
          Positioned(
            right: 10,
            bottom: 90,
            child: _ActionRail(
              video: widget.video,
              onLike: widget.onLike,
              onComment: widget.onComments,
              onBookmark: widget.onBookmark,
              onShare: widget.onShare,
            ),
          ),
          Center(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: _showHeart ? 1 : 0,
              curve: Curves.easeOutBack,
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 112,
                shadows: <Shadow>[
                  Shadow(color: Colors.black38, blurRadius: 18),
                ],
              ),
            ),
          ),
          if (player != null &&
              player.value.isInitialized &&
              !player.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_arrow_rounded,
                color: Colors.white70,
                size: 72,
              ),
            ),
        ],
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation();

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: <Widget>[
          const _LiveEntryButton(),
          const Spacer(),
          const Text(
            'أتابعه',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 22),
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'لك',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 5),
              SizedBox(
                width: 26,
                child: Divider(height: 2, thickness: 2, color: Colors.white),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.search_rounded, size: 30),
        ],
      ),
    ),
  );
}

class _LiveEntryButton extends StatefulWidget {
  const _LiveEntryButton();

  @override
  State<_LiveEntryButton> createState() => _LiveEntryButtonState();
}

class _LiveEntryButtonState extends State<_LiveEntryButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final bool ready = await Get.find<SessionController>().ensureReadyForLive();
    if (ready) {
      await Get.toNamed<void>(AppRoutes.liveList);
    } else {
      await Get.toNamed<void>(AppRoutes.auth);
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _opening ? null : _open,
    child: Container(
      width: 68,
      height: 30,
      decoration: BoxDecoration(
        color: LiveColors.live,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        child: _opening
            ? const SizedBox(
                key: ValueKey<String>('loading'),
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                key: ValueKey<String>('live'),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.sensors_rounded, size: 15),
                  SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption({required this.video});
  final ShortVideoEntity video;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        '@${video.username}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 8),
      Text(
        '${video.caption}  ${video.hashtags.map((String tag) => '#$tag').join(' ')}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          fontSize: 14.5,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 11),
      Row(
        children: <Widget>[
          const Icon(Icons.music_note_rounded, size: 17),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              video.soundName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ],
  );
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.video,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onShare,
  });
  final ShortVideoEntity video;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Text(
              video.displayName.characters.first,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const Positioned(
            bottom: -8,
            child: CircleAvatar(
              radius: 9,
              backgroundColor: LiveColors.live,
              child: Icon(Icons.add, size: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: 21),
      _Action(
        icon: video.isLiked
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        color: video.isLiked ? LiveColors.live : Colors.white,
        count: video.likesCount,
        onTap: onLike,
      ),
      _Action(
        icon: Icons.mode_comment_rounded,
        count: video.commentsCount,
        onTap: onComment,
      ),
      _Action(
        icon: video.isBookmarked
            ? Icons.bookmark_rounded
            : Icons.bookmark_border_rounded,
        color: video.isBookmarked ? const Color(0xFFFFD54F) : Colors.white,
        count: video.bookmarksCount,
        onTap: onBookmark,
      ),
      _Action(
        icon: Icons.reply_rounded,
        count: video.sharesCount,
        onTap: onShare,
      ),
      const SizedBox(height: 4),
      Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(9),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: <Color>[Color(0xFF252525), Colors.black],
          ),
        ),
        child: const CircleAvatar(
          backgroundColor: Colors.white,
          child: Icon(Icons.music_note, size: 17, color: Colors.black),
        ),
      ),
    ],
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.count,
    required this.onTap,
    this.color = Colors.white,
  });
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          Icon(
            icon,
            color: color,
            size: 34,
            shadows: const <Shadow>[
              Shadow(color: Colors.black54, blurRadius: 6),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            _compact(count),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 11),
      decoration: const BoxDecoration(
        color: Color(0xD9000000),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          const _NavItem(Icons.home_filled, 'الرئيسية', active: true),
          const _NavItem(Icons.people_outline_rounded, 'الأصدقاء'),
          const _BroadcastEntryButton(),
          const _NavItem(Icons.inbox_outlined, 'البريد'),
          const _NavItem(Icons.person_outline_rounded, 'حسابي'),
        ],
      ),
    ),
  );
}

class _BroadcastEntryButton extends StatefulWidget {
  const _BroadcastEntryButton();

  @override
  State<_BroadcastEntryButton> createState() => _BroadcastEntryButtonState();
}

class _BroadcastEntryButtonState extends State<_BroadcastEntryButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final bool ready = await Get.find<SessionController>().ensureReadyForLive();
    if (ready) {
      await Get.toNamed<void>(AppRoutes.goLive);
    } else {
      await Get.toNamed<void>(AppRoutes.auth);
    }
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _opening ? null : _open,
    child: Container(
      width: 48,
      height: 31,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0xFF22D3EE), offset: Offset(-4, 0)),
          BoxShadow(color: Color(0xFFFE2C55), offset: Offset(4, 0)),
        ],
      ),
      alignment: Alignment.center,
      child: _opening
          ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.black,
              ),
            )
          : const Icon(Icons.add_rounded, color: Colors.black, size: 27),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem(this.icon, this.label, {this.active = false});
  final IconData icon;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Icon(icon, size: 25, color: active ? Colors.white : Colors.white70),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: active ? Colors.white : Colors.white70,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.video, required this.repository});
  final ShortVideoEntity video;
  final ShortVideoRepository repository;

  static Future<void> show(
    BuildContext context,
    ShortVideoEntity video,
    ShortVideoRepository repository,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF171719),
    builder: (_) => _CommentsSheet(video: video, repository: repository),
  );

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _text = TextEditingController();
  List<VideoCommentEntity> _comments = const <VideoCommentEntity>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      _comments = await widget.repository.comments(widget.video.id);
    } catch (_) {
      // The empty state remains useful when the demo server is restarting.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final String body = _text.text.trim();
    if (body.isEmpty) return;
    try {
      final VideoCommentEntity comment = await widget.repository.addComment(
        widget.video.id,
        body,
      );
      _text.clear();
      setState(() => _comments = <VideoCommentEntity>[comment, ..._comments]);
    } catch (_) {
      // Keep the composer open so the user can retry without losing the text.
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .66,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${_compact(widget.video.commentsCount)} تعليق',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? const Center(child: Text('كن أول من يعلّق'))
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (_, int index) {
                      final VideoCommentEntity comment = _comments[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(comment.displayName.characters.first),
                        ),
                        title: Text(
                          '@${comment.username}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                        subtitle: Text(
                          comment.body,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _text,
                      decoration: InputDecoration(
                        hintText: 'أضف تعليقاً...',
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _send,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: LiveColors.live,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.cloud_off_rounded, size: 48),
        const SizedBox(height: 12),
        const Text('تعذر تحميل المقاطع'),
        TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}

String _compact(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return '$value';
}
