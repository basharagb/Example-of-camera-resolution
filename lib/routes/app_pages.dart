import 'package:get/get.dart';

import '../features/camera/presentation/bindings/camera_binding.dart';
import '../features/camera/presentation/pages/camera_page.dart';
import '../features/live/presentation/bindings/live_bindings.dart';
import '../features/live/presentation/pages/auth_page.dart';
import '../features/live/presentation/pages/go_live_page.dart';
import '../features/live/presentation/pages/live_list_page.dart';
import '../features/live/presentation/pages/live_room_page.dart';
import '../features/live/presentation/pages/splash_page.dart';
import '../features/shorts/presentation/bindings/video_feed_binding.dart';
import '../features/shorts/presentation/pages/video_feed_page.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage<void>> pages = <GetPage<void>>[
    GetPage<void>(name: AppRoutes.splash, page: SplashPage.new),
    GetPage<void>(name: AppRoutes.auth, page: AuthPage.new),
    GetPage<void>(
      name: AppRoutes.home,
      page: VideoFeedPage.new,
      binding: VideoFeedBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.liveList,
      page: LiveListPage.new,
      binding: LiveListBinding(),
    ),
    GetPage<void>(name: AppRoutes.goLive, page: GoLivePage.new),
    GetPage<void>(
      name: AppRoutes.liveRoom,
      page: LiveRoomPage.new,
      binding: LiveRoomBinding(),
      // A room is a full-screen context; the fade avoids the horizontal slide
      // fighting the video that is already rendering underneath.
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.camera,
      page: CameraPage.new,
      binding: CameraBinding(),
    ),
  ];
}
