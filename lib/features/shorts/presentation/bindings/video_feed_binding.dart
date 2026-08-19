import 'package:get/get.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/network/api_client.dart';
import '../../data/local/demo_short_video_repository.dart';
import '../../data/repositories/short_video_repository_impl.dart';
import '../../domain/repositories/short_video_repository.dart';
import '../../domain/usecases/short_video_usecases.dart';
import '../controllers/video_feed_controller.dart';

class VideoFeedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShortVideoRepository>(
      // The demo build never asks the network for the feed, so the first
      // screen is filled from the bundle instead of after a connect timeout.
      () => AppConfig.demoMode
          ? DemoShortVideoRepository()
          : ShortVideoRepositoryImpl(Get.find<ApiClient>()),
      fenix: true,
    );
    Get.lazyPut<VideoFeedController>(() {
      final ShortVideoRepository repository = Get.find<ShortVideoRepository>();
      return VideoFeedController(
        loadFeed: LoadVideoFeedUseCase(repository),
        setLiked: SetVideoLikedUseCase(repository),
        setBookmarked: SetVideoBookmarkedUseCase(repository),
        repository: repository,
      );
    }, fenix: true);
  }
}
