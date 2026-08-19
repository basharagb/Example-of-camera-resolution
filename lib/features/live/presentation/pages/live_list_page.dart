import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/live_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_list_controller.dart';
import '../controllers/session_controller.dart';
import '../widgets/coin_top_up_sheet.dart';
import '../widgets/live_cover.dart';

/// The discovery feed, as a full-screen vertical pager.
///
/// One room fills the screen at a time and a vertical swipe moves to the next,
/// which is the shape people already know from short-video apps: no grid of
/// thumbnails to parse, just the room itself. The list stays current over the
/// realtime stream, so rooms appear and disappear as they open and close.
class LiveListPage extends GetView<LiveListController> {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: LiveColors.background,
      // The pager runs edge to edge behind the status bar; the chrome floats
      // above it inside its own SafeArea.
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Obx(() {
            if (controller.isLoading.value && controller.streams.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: LiveColors.accent),
              );
            }
            if (controller.streams.isEmpty) {
              return _EmptyFeed(controller: controller);
            }
            return _LiveFeedPager(controller: controller);
          }),
          _TopBar(session: session, controller: controller),
          _GoLiveButton(),
        ],
      ),
    );
  }
}

class _LiveFeedPager extends StatefulWidget {
  const _LiveFeedPager({required this.controller});

  final LiveListController controller;

  @override
  State<_LiveFeedPager> createState() => _LiveFeedPagerState();
}

class _LiveFeedPagerState extends State<_LiveFeedPager> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<LiveStreamEntity> streams = widget.controller.streams;
      return RefreshIndicator(
        color: LiveColors.accent,
        backgroundColor: LiveColors.surface,
        onRefresh: widget.controller.refreshFeed,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: streams.length,
          onPageChanged: (int index) {
            HapticFeedback.selectionClick();
            // Fetch the next page a little before the end so a fast swipe does
            // not hit a wall.
            if (index >= streams.length - 2) {
              widget.controller.loadMore();
            }
          },
          itemBuilder: (BuildContext context, int index) =>
              _LiveFeedPage(stream: streams[index], isFirst: index == 0),
        ),
      );
    });
  }
}

/// One room, full screen.
class _LiveFeedPage extends StatelessWidget {
  const _LiveFeedPage({required this.stream, required this.isFirst});

  final LiveStreamEntity stream;
  final bool isFirst;

  void _enter() {
    HapticFeedback.mediumImpact();
    Get.toNamed<void>(
      AppRoutes.liveRoom,
      arguments: <String, dynamic>{'streamId': stream.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _enter,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          LiveCover(stream: stream, initialSize: 220),

          // Keeps the white chrome legible over any cover.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: <Color>[
                  Color(0xF2000000),
                  Color(0x99000000),
                  Color(0x33000000),
                  Color(0xB3000000),
                ],
                stops: <double>[0, 0.35, 0.65, 1],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        LiveAvatar(
                          profile: stream.host,
                          size: 52,
                          ring: LiveColors.live,
                          ringWidth: 2,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                stream.host.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LiveTextStyles.title.copyWith(
                                  fontSize: 19,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${stream.host.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LiveTextStyles.caption.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      stream.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LiveTextStyles.body.copyWith(
                        fontSize: 16,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        _Stat(
                          icon: Icons.remove_red_eye_rounded,
                          value: formatCompact(stream.viewerCount),
                          label: 'watching',
                        ),
                        const SizedBox(width: 22),
                        _Stat(
                          emoji: '🪙',
                          value: formatCompact(stream.totalCoins),
                          label: 'coins',
                          tint: LiveColors.coin,
                        ),
                        const SizedBox(width: 22),
                        _Stat(
                          emoji: '❤️',
                          value: formatCompact(stream.totalLikes),
                          label: 'likes',
                          tint: LiveColors.live,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: LiveColors.live,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              LiveMetrics.pillRadius,
                            ),
                          ),
                        ),
                        onPressed: _enter,
                        child: const Text(
                          'Join live',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                    ),
                    // Shown once, on the first room, so the gesture is
                    // discoverable without nagging on every page.
                    if (isFirst) ...<Widget>[
                      const SizedBox(height: 12),
                      const Center(child: _SwipeHint()),
                    ],
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 62,
            left: 20,
            child: Row(
              children: <Widget>[
                const LivePill(),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.remove_red_eye_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        formatCompact(stream.viewerCount),
                        style: LiveTextStyles.badge.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.icon,
    this.emoji,
    this.tint = LiveColors.textPrimary,
  });

  final String value;
  final String label;
  final IconData? icon;
  final String? emoji;
  final Color tint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Row(
        children: <Widget>[
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 13))
          else
            Icon(icon, size: 14, color: tint),
          const SizedBox(width: 5),
          Text(
            value,
            style: LiveTextStyles.title.copyWith(fontSize: 15, color: tint),
          ),
        ],
      ),
      const SizedBox(height: 1),
      Text(label, style: LiveTextStyles.caption.copyWith(fontSize: 10.5)),
    ],
  );
}

class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_controller),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.keyboard_arrow_up_rounded,
          size: 17,
          color: LiveColors.textSecondary,
        ),
        const SizedBox(width: 5),
        Text(
          'Swipe for more lives',
          style: LiveTextStyles.caption.copyWith(fontSize: 11.5),
        ),
      ],
    ),
  );
}

/// Floating chrome: identity, wallet and the account menu.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.controller});

  final SessionController session;
  final LiveListController controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 10, 0),
      child: Row(
        children: <Widget>[
          Text(
            'Live',
            style: LiveTextStyles.displayLarge.copyWith(
              shadows: <Shadow>[
                const Shadow(color: Color(0xCC000000), blurRadius: 12),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                CoinTopUpSheet.show(context: context, session: session),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                border: Border.all(
                  color: LiveColors.coin.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Obx(
                    () => Text(
                      formatCompact(session.wallet.value.coinBalance),
                      style: LiveTextStyles.caption.copyWith(
                        color: LiveColors.coin,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: LiveColors.surfaceRaised,
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (String value) async {
              if (value == 'refresh') {
                await controller.refreshFeed();
              } else if (value == 'logout') {
                await session.logout();
                Get.offAllNamed<void>(AppRoutes.auth);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Obx(
                  () => Text(
                    session.user.value?.displayName ?? '',
                    style: LiveTextStyles.caption,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'refresh',
                child: Text('Refresh', style: LiveTextStyles.body),
              ),
              // There is nothing to sign out of in the local build: the
              // account exists on the device and the sign-in screen is not
              // part of the flow.
              if (!AppConfig.demoMode)
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Sign out', style: LiveTextStyles.body),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _GoLiveButton extends StatefulWidget {
  @override
  State<_GoLiveButton> createState() => _GoLiveButtonState();
}

class _GoLiveButtonState extends State<_GoLiveButton> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    HapticFeedback.mediumImpact();
    try {
      final bool ready = await Get.find<SessionController>()
          .ensureReadyForLive();
      await Get.toNamed<void>(ready ? AppRoutes.goLive : AppRoutes.auth);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Positioned(
    right: 18,
    bottom: MediaQuery.of(context).padding.bottom + 250,
    child: Semantics(
      button: true,
      label: 'Go live',
      child: GestureDetector(
        onTap: _opening ? null : _open,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFFFF365E), Color(0xFFFF7A3D)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: LiveColors.live.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: _opening
                ? const SizedBox(
                    key: ValueKey<String>('opening'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.videocam_rounded,
                    key: ValueKey<String>('camera'),
                    color: Colors.white,
                    size: 27,
                  ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.controller});

  final LiveListController controller;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: LiveColors.accent,
    backgroundColor: LiveColors.surface,
    onRefresh: controller.refreshFeed,
    child: ListView(
      children: <Widget>[
        SizedBox(height: MediaQuery.of(context).size.height * 0.28),
        Center(
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiveColors.live.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.videocam_off_rounded,
              size: 42,
              color: LiveColors.live,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Text(
            controller.errorMessage.value ?? 'Nobody is live right now',
            style: LiveTextStyles.title,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Tap the red button to start your own',
            style: LiveTextStyles.caption,
          ),
        ),
      ],
    ),
  );
}
