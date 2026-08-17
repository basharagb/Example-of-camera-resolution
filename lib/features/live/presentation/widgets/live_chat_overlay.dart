import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_room_controller.dart';

/// The scrolling conversation over the video.
///
/// It occupies the lower-left corner and fades toward the top so lines
/// dissolve into the video instead of ending on a hard edge, and it always
/// follows the newest message unless the viewer has scrolled up to read back.
class LiveChatOverlay extends StatefulWidget {
  const LiveChatOverlay({required this.controller, super.key});

  final LiveRoomController controller;

  @override
  State<LiveChatOverlay> createState() => _LiveChatOverlayState();
}

class _LiveChatOverlayState extends State<LiveChatOverlay> {
  final ScrollController _scrollController = ScrollController();
  Worker? _messagesWorker;

  /// False while the viewer is reading older lines, so new arrivals do not
  /// yank the list out from under them.
  bool _followTail = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messagesWorker = ever<List<ChatMessageEntity>>(
      widget.controller.messages,
      (_) => _scrollToBottomSoon(),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final double distanceFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    _followTail = distanceFromBottom < 60;
  }

  void _scrollToBottomSoon() {
    if (!_followTail) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: LiveMetrics.fast,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _messagesWorker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.transparent, Colors.white, Colors.white],
        stops: <double>[0, 0.25, 1],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: Obx(() {
        final List<ChatMessageEntity> messages = widget.controller.messages;
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 30, bottom: 6),
          itemCount: messages.length,
          physics: const ClampingScrollPhysics(),
          itemBuilder: (BuildContext context, int index) =>
              _ChatLine(message: messages[index]),
        );
      }),
    );
  }
}

class _ChatLine extends StatelessWidget {
  const _ChatLine({required this.message});

  final ChatMessageEntity message;

  @override
  Widget build(BuildContext context) {
    if (message.kind == ChatMessageKind.join) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: LiveColors.accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                border: Border.all(color: LiveColors.accent.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${message.sender.displayName} joined',
                style: LiveTextStyles.caption.copyWith(color: LiveColors.accent),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(16),
              ),
              child: RichText(
                text: TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: '${message.sender.displayName}  ',
                      style: LiveTextStyles.caption.copyWith(
                        color: LiveColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextSpan(
                      text: message.body ?? '',
                      style: LiveTextStyles.body.copyWith(fontSize: 13.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
