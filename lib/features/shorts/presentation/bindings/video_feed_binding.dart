import 'package:get/get.dart';

import '../../../../core/services/network/api_client.dart';
import '../../data/repositories/short_video_repository_impl.dart';
import '../../domain/repositories/short_video_repository.dart';
import '../../domain/usecases/short_video_usecases.dart';
import '../controllers/video_feed_controller.dart';

class VideoFeedBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ShortVideoRepository>(
      () => ShortVideoRepositoryImpl(Get.find<ApiClient>()),
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
