import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/utils/debug_log.dart';
import '../../domain/entities/short_video_entity.dart';
import '../../domain/repositories/short_video_repository.dart';
import '../../domain/usecases/short_video_usecases.dart';

class VideoFeedController extends GetxController {
  VideoFeedController({
    required this.loadFeed,
    required this.setLiked,
    required this.setBookmarked,
    required this.repository,
  });

  final LoadVideoFeedUseCase loadFeed;
  final SetVideoLikedUseCase setLiked;
  final SetVideoBookmarkedUseCase setBookmarked;
  final ShortVideoRepository repository;

  final RxList<ShortVideoEntity> videos = <ShortVideoEntity>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxBool isLoading = true.obs;
  final RxnString errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(refreshFeed());
  }

  Future<void> refreshFeed() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      videos.assignAll(await loadFeed());
      if (videos.isNotEmpty) {
        unawaited(
          repository.recordView(videos.first.id).catchError((Object error) {
            debugLog('Initial view tracking failed', error);
          }),
        );
      }
    } catch (error, stackTrace) {
      debugLog('Video feed failed', error, stackTrace);
      errorMessage.value = 'تعذر تحميل المقاطع';
    } finally {
      isLoading.value = false;
    }
  }

  void pageChanged(int index) {
    currentIndex.value = index;
    if (index >= 0 && index < videos.length) {
      unawaited(
        repository.recordView(videos[index].id).catchError((Object error) {
          debugLog('View tracking failed', error);
        }),
      );
    }
  }

  Future<void> toggleLike(ShortVideoEntity video) async {
    final int index = videos.indexWhere(
      (ShortVideoEntity item) => item.id == video.id,
    );
    if (index < 0) return;
    final bool next = !videos[index].isLiked;
    videos[index] = videos[index].copyWith(
      isLiked: next,
      likesCount: videos[index].likesCount + (next ? 1 : -1),
    );
    try {
      videos[index] = await setLiked(video.id, next);
    } catch (error) {
      debugLog('Like sync failed', error);
    }
  }

  Future<void> toggleBookmark(ShortVideoEntity video) async {
    final int index = videos.indexWhere(
      (ShortVideoEntity item) => item.id == video.id,
    );
    if (index < 0) return;
    final bool next = !videos[index].isBookmarked;
    videos[index] = videos[index].copyWith(
      isBookmarked: next,
      bookmarksCount: videos[index].bookmarksCount + (next ? 1 : -1),
    );
    try {
      videos[index] = await setBookmarked(video.id, next);
    } catch (error) {
      debugLog('Bookmark sync failed', error);
    }
  }

  Future<void> share(ShortVideoEntity video) async {
    final int index = videos.indexWhere(
      (ShortVideoEntity item) => item.id == video.id,
    );
    if (index >= 0) {
      videos[index] = videos[index].copyWith(
        sharesCount: videos[index].sharesCount + 1,
      );
    }
    try {
      await repository.recordShare(video.id);
    } catch (error) {
      debugLog('Share tracking failed', error);
    }
  }
}
