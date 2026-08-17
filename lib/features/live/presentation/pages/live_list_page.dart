import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_list_controller.dart';
import '../controllers/session_controller.dart';
import '../widgets/coin_top_up_sheet.dart';

/// The discovery feed: who is live right now.
///
/// It stays current over the socket, so a room that opens or closes appears or
/// disappears without a refresh.
class LiveListPage extends GetView<LiveListController> {
  const LiveListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = Get.find<SessionController>();

    return Scaffold(
      backgroundColor: LiveColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(session: session),
            _TopHostsStrip(controller: controller),
            Expanded(
              child: RefreshIndicator(
                color: LiveColors.accent,
                backgroundColor: LiveColors.surface,
                onRefresh: controller.refreshFeed,
                child: Obx(() {
                  if (controller.isLoading.value && controller.streams.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: LiveColors.accent),
                    );
                  }
                  if (controller.streams.isEmpty) {
                    return _EmptyFeed(controller: controller);
                  }
                  return _FeedGrid(controller: controller);
                }),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: LiveColors.live,
        foregroundColor: Colors.white,
        onPressed: () => Get.toNamed<void>(AppRoutes.goLive),
        icon: const Icon(Icons.videocam_rounded),
        label: const Text('Go live', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(LiveMetrics.screenPadding, 10, 10, 12),
    child: Row(
      children: <Widget>[
        Text('Live', style: LiveTextStyles.displayLarge),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: LiveColors.live,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('NOW', style: LiveTextStyles.badge),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => CoinTopUpSheet.show(context: context, session: session),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: LiveColors.surfaceRaised,
              borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
              border: Border.all(color: LiveColors.coin.withValues(alpha: 0.3)),
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
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          color: LiveColors.surfaceRaised,
          icon: const Icon(Icons.more_vert_rounded, color: LiveColors.textSecondary),
          onSelected: (String value) async {
            if (value == 'logout') {
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
              value: 'logout',
              child: Text('Sign out', style: LiveTextStyles.body),
            ),
          ],
        ),
      ],
    ),
  );
}

/// The weekly top earning hosts, shown as a horizontal strip above the feed.
class _TopHostsStrip extends StatelessWidget {
  const _TopHostsStrip({required this.controller});

  final LiveListController controller;

  @override
  Widget build(BuildContext context) => Obx(() {
    final List<LeaderboardEntryEntity> hosts = controller.topHosts;
    if (hosts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(LiveMetrics.screenPadding, 0, 0, 8),
          child: Row(
            children: <Widget>[
              const Text('💎', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                'Top hosts this week',
                style: LiveTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: LiveMetrics.screenPadding,
            ),
            itemCount: hosts.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int index) {
              final LeaderboardEntryEntity entry = hosts[index];
              final Color ring = switch (entry.rank) {
                1 => const Color(0xFFFFD700),
                2 => const Color(0xFFC0C6CE),
                3 => const Color(0xFFCD7F32),
                _ => LiveColors.divider,
              };
              return SizedBox(
                width: 56,
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: LiveColors.surfaceRaised,
                        border: Border.all(color: ring, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        entry.user.initial,
                        style: LiveTextStyles.title.copyWith(fontSize: 17),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatCompact(entry.totalDiamonds),
                      style: LiveTextStyles.caption.copyWith(
                        color: LiveColors.diamond,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  });
}

class _FeedGrid extends StatelessWidget {
  const _FeedGrid({required this.controller});

  final LiveListController controller;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // Prefetch a page before the user reaches the bottom.
        if (notification.metrics.pixels >
            notification.metrics.maxScrollExtent - 400) {
          controller.loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          LiveMetrics.screenPadding,
          0,
          LiveMetrics.screenPadding,
          90,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: controller.streams.length,
        itemBuilder: (BuildContext context, int index) =>
            _StreamCard(stream: controller.streams[index]),
      ),
    );
  }
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({required this.stream});

  final LiveStreamEntity stream;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.toNamed<void>(
        AppRoutes.liveRoom,
        arguments: <String, dynamic>{'streamId': stream.id},
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LiveMetrics.cardRadius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // Real thumbnails need a media server snapshot; until then the
            // host's initial on a tinted ground keeps the grid legible.
            _CoverPlaceholder(stream: stream),

            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[Color(0xE6000000), Colors.transparent],
                  stops: <double>[0, 0.62],
                ),
              ),
            ),

            Positioned(
              top: 9,
              left: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: LiveColors.live,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('LIVE', style: LiveTextStyles.badge),
              ),
            ),

            Positioned(
              top: 9,
              right: 9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.remove_red_eye_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatCompact(stream.viewerCount),
                      style: LiveTextStyles.badge.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    stream.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LiveTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LiveColors.accent.withValues(alpha: 0.25),
                          border: Border.all(color: LiveColors.accent, width: 1),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          stream.host.initial,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stream.host.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LiveTextStyles.caption.copyWith(fontSize: 11),
                        ),
                      ),
                      if (stream.totalCoins > 0) ...<Widget>[
                        const Text('🪙', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(
                          formatCompact(stream.totalCoins),
                          style: LiveTextStyles.caption.copyWith(
                            color: LiveColors.coin,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.stream});

  final LiveStreamEntity stream;

  /// A stable per-host tint, so the same host always gets the same card colour
  /// and the grid does not reshuffle its palette on every refresh.
  static const List<List<Color>> _grounds = <List<Color>>[
    <Color>[Color(0xFF2A1B4A), Color(0xFF0E0A18)],
    <Color>[Color(0xFF1B3A4A), Color(0xFF0A1418)],
    <Color>[Color(0xFF4A2B1B), Color(0xFF180E0A)],
    <Color>[Color(0xFF1B4A2E), Color(0xFF0A180F)],
    <Color>[Color(0xFF4A1B38), Color(0xFF180A13)],
  ];

  @override
  Widget build(BuildContext context) {
    if (stream.coverUrl != null && stream.coverUrl!.startsWith('http')) {
      return Image.network(
        stream.coverUrl!,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stackTrace) =>
                _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final List<Color> ground =
        _grounds[stream.host.id.hashCode.abs() % _grounds.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ground,
        ),
      ),
      child: Center(
        child: Text(
          stream.host.initial,
          style: const TextStyle(
            fontSize: 54,
            fontWeight: FontWeight.w900,
            color: Color(0x33FFFFFF),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.controller});

  final LiveListController controller;

  @override
  Widget build(BuildContext context) => ListView(
    children: <Widget>[
      SizedBox(height: MediaQuery.of(context).size.height * 0.2),
      const Icon(Icons.videocam_off_rounded, size: 54, color: LiveColors.textMuted),
      const SizedBox(height: 16),
      Center(
        child: Text(
          controller.errorMessage.value ?? 'Nobody is live right now',
          style: LiveTextStyles.body,
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text('Be the first to go live', style: LiveTextStyles.caption),
      ),
    ],
  );
}
