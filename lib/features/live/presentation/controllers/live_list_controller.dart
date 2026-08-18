import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/services/network/live_events_client.dart';
import '../../data/models/live_models.dart';
import '../../domain/entities/live_entities.dart';
import '../../domain/usecases/live_usecases.dart';

/// The discovery feed.
///
/// It is kept live by the realtime stream rather than by polling: a room that opens or
/// closes anywhere appears or disappears here immediately, and the list only
/// refetches when the user pulls to refresh or pages.
class LiveListController extends GetxController {
  LiveListController({
    required this.listLiveStreams,
    required this.globalLeaderboard,
    required this.eventsClient,
  });

  final ListLiveStreamsUseCase listLiveStreams;
  final GlobalLeaderboardUseCase globalLeaderboard;
  final LiveEventsClient eventsClient;

  final RxList<LiveStreamEntity> streams = <LiveStreamEntity>[].obs;
  final RxList<LeaderboardEntryEntity> topHosts = <LeaderboardEntryEntity>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool hasMore = false.obs;

  int _page = 1;
  StreamSubscription<LiveRealtimeEvent>? _eventsSubscription;

  @override
  void onInit() {
    super.onInit();
    _eventsSubscription = eventsClient.events.listen(_onRealtimeEvent);
    refreshFeed();
  }

  Future<void> refreshFeed() async {
    isLoading.value = true;
    errorMessage.value = null;
    _page = 1;
    try {
      final PagedResult<LiveStreamEntity> result = await listLiveStreams(page: 1);
      streams.assignAll(result.items);
      hasMore.value = result.hasMore;
      unawaited(_loadTopHosts());
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (!hasMore.value || isLoadingMore.value || isLoading.value) {
      return;
    }
    isLoadingMore.value = true;
    try {
      final PagedResult<LiveStreamEntity> result = await listLiveStreams(page: _page + 1);
      _page += 1;
      // A room can end between pages and reappear on the next one; de-duplicate
      // so the feed never shows the same room twice.
      final Set<String> known = streams.map((LiveStreamEntity s) => s.id).toSet();
      streams.addAll(
        result.items.where((LiveStreamEntity item) => !known.contains(item.id)),
      );
      hasMore.value = result.hasMore;
    } on AppFailure catch (failure) {
      errorMessage.value = failure.message;
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> _loadTopHosts() async {
    try {
      topHosts.assignAll(await globalLeaderboard(board: 'hosts', limit: 10));
    } on AppFailure {
      // The podium is decoration; the feed is still usable without it.
      topHosts.clear();
    }
  }

  void _onRealtimeEvent(LiveRealtimeEvent event) {
    switch (event.name) {
      case LiveEvents.streamStarted:
        final Map<String, dynamic> raw = LiveModelParsers.asMap(event.payload['stream']);
        if (raw.isEmpty) {
          return;
        }
        final LiveStreamEntity started = LiveStreamModel.fromJson(raw);
        if (streams.every((LiveStreamEntity item) => item.id != started.id)) {
          // Newest first, matching how the feed sorts a fresh fetch.
          streams.insert(0, started);
        }

      case LiveEvents.streamEnded:
        final String endedId = LiveModelParsers.asString(event.payload['streamId']);
        streams.removeWhere((LiveStreamEntity item) => item.id == endedId);
    }
  }

  @override
  void onClose() {
    _eventsSubscription?.cancel();
    super.onClose();
  }
}
