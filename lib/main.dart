import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const ApexCameraApp());
}

class ApexCameraApp extends StatelessWidget {
  const ApexCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Bashar Camera',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.camera,
      getPages: AppPages.pages,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD9EC35),
          secondary: Color(0xFF5AD5FF),
          surface: Color(0xFF151719),
        ),
        fontFamily: 'SF Pro Display',
      ),
    );
  }
}
