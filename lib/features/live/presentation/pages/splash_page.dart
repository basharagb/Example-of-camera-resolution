import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../../../core/config/app_config.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/session_controller.dart';

/// Held while the stored session is validated against the server, then routes
/// to the feed or to sign-in. Without this step a returning user would see the
/// login screen flash before being replaced.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final SessionController _session = Get.find<SessionController>();
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    if (AppConfig.demoMode) {
      _route();
      return;
    }
    if (!_session.isRestoring.value) {
      _route();
      return;
    }
    _worker = ever<bool>(_session.isRestoring, (bool restoring) {
      if (!restoring) {
        _route();
      }
    });
  }

  void _route() {
    _worker?.dispose();
    _worker = null;
    // Deferred to the next frame: routing during a build throws.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Get.offAllNamed<void>(
        AppConfig.demoMode || _session.isSignedIn
            ? AppRoutes.home
            : AppRoutes.auth,
      );
    });
  }

  @override
  void dispose() {
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LiveColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: LiveColors.live,
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 22),
          Text('Elite Live', style: LiveTextStyles.displayLarge),
          const SizedBox(height: 26),
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: LiveColors.accent,
            ),
          ),
        ],
      ),
    ),
  );
}
