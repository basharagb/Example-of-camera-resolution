import 'package:get/get.dart';

import '../features/camera/presentation/bindings/camera_binding.dart';
import '../features/camera/presentation/pages/camera_page.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static final List<GetPage<void>> pages = <GetPage<void>>[
    GetPage<void>(
      name: AppRoutes.camera,
      page: CameraPage.new,
      binding: CameraBinding(),
    ),
  ];
}
