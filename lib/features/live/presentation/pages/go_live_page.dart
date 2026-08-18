import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/session_controller.dart';

/// The pre-flight screen: name the broadcast before the camera opens.
///
/// Asking for a title here rather than after going live means the room appears
/// in the feed already labelled, instead of as "Untitled" for its first
/// seconds.
class GoLivePage extends StatefulWidget {
  const GoLivePage({super.key});

  @override
  State<GoLivePage> createState() => _GoLivePageState();
}

class _GoLivePageState extends State<GoLivePage> {
  final TextEditingController _title = TextEditingController();
  final SessionController _session = Get.find<SessionController>();

  @override
  void initState() {
    super.initState();
    final String name = _session.user.value?.displayName ?? '';
    _title.text = name.isEmpty ? 'Live now' : "$name's live";
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _start() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    HapticFeedback.mediumImpact();
    FocusManager.instance.primaryFocus?.unfocus();
    // Replaces this route so backing out of the room lands on the feed, not
    // back on the setup screen.
    Get.offNamed<void>(
      AppRoutes.liveRoom,
      arguments: <String, dynamic>{'mode': 'host', 'title': title},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiveColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Get.back<void>(),
        ),
        title: Text('Go live', style: LiveTextStyles.title),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 20),
              Text('What is your live about?', style: LiveTextStyles.body),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 80,
                maxLines: 2,
                minLines: 1,
                autofocus: true,
                style: LiveTextStyles.body.copyWith(fontSize: 16),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: LiveColors.surface,
                  counterStyle: LiveTextStyles.caption.copyWith(fontSize: 10),
                  hintText: 'Add a title viewers will see',
                  hintStyle: LiveTextStyles.caption,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: LiveColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: LiveColors.accent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const _ChecklistCard(),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: LiveColors.live,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        LiveMetrics.pillRadius,
                      ),
                    ),
                  ),
                  onPressed: _start,
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text(
                    'Start broadcasting',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sets expectations before the permission prompts appear, so the dialogs are
/// not the first explanation the user gets.
class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: LiveColors.surface,
      borderRadius: BorderRadius.circular(LiveMetrics.cardRadius),
      border: Border.all(color: LiveColors.divider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ChecklistRow(
          icon: Icons.videocam_rounded,
          text: 'Your camera and microphone will be used while you are live',
        ),
        SizedBox(height: 11),
        _ChecklistRow(
          icon: Icons.card_giftcard_rounded,
          text: 'Viewers can send gifts that become diamonds in your wallet',
        ),
        SizedBox(height: 11),
        _ChecklistRow(
          icon: Icons.stop_circle_outlined,
          text: 'Ending the broadcast closes the room for everyone watching',
        ),
      ],
    ),
  );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(icon, size: 17, color: LiveColors.accent),
      const SizedBox(width: 11),
      Expanded(
        child: Text(text, style: LiveTextStyles.caption.copyWith(fontSize: 12)),
      ),
    ],
  );
}
