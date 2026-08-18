import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/theme/live_theme.dart';
import 'core/config/app_config.dart';
import 'features/live/presentation/bindings/live_bindings.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initializeEndpoint();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // The whole product is dark, so the status bar icons are light everywhere.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const EliteLiveApp());
}

class EliteLiveApp extends StatelessWidget {
  const EliteLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Elite Live',
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      // Registered before the first route builds, because the splash screen
      // already needs the session controller to decide where to go.
      initialBinding: LiveCoreBinding(),
      getPages: AppPages.pages,
      theme: _buildTheme(),
    );
  }

  ThemeData _buildTheme() {
    const ColorScheme scheme = ColorScheme.dark(
      primary: LiveColors.accent,
      onPrimary: LiveColors.accentInk,
      secondary: LiveColors.diamond,
      surface: LiveColors.surface,
      error: LiveColors.live,
    );

    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: LiveColors.background,
      fontFamily: 'SF Pro Display',
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LiveColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: LiveColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: LiveColors.surfaceRaised,
        contentTextStyle: TextStyle(color: LiveColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: LiveColors.accent,
        selectionColor: Color(0x66D9EC35),
        selectionHandleColor: LiveColors.accent,
      ),
    );
  }
}
