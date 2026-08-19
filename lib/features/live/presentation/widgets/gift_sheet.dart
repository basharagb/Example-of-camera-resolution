import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/live_room_controller.dart';
import '../controllers/session_controller.dart';
import 'coin_top_up_sheet.dart';
import 'gift_artwork.dart';

/// The gift catalogue, opened from the room's toolbar.
///
/// Tiers are tabs, the wallet balance is always visible, and the send button
/// doubles as a combo: holding it repeats the selected gift so a viewer can
/// stack a burst the way the animation layer expects.
class GiftSheet extends StatefulWidget {
  const GiftSheet({required this.controller, required this.session, super.key});

  final LiveRoomController controller;
  final SessionController session;

  static Future<void> show({
    required BuildContext context,
    required LiveRoomController controller,
    required SessionController session,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => GiftSheet(controller: controller, session: session),
  );

  @override
  State<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<GiftSheet> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: GiftTier.values.length,
    vsync: this,
  );

  GiftEntity? _selected;
  int _comboCount = 1;
  bool _sending = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final GiftEntity? gift = _selected;
    if (gift == null || _sending) {
      return;
    }
    setState(() => _sending = true);
    final bool sent = await widget.controller.sendGift(gift, quantity: _comboCount);
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);

    if (sent) {
      HapticFeedback.mediumImpact();
      setState(() => _comboCount = 1);
      return;
    }

    // The most common failure is an empty wallet, and the useful response is
    // to offer a top up rather than just an error.
    final int balance = widget.session.wallet.value.coinBalance;
    if (balance < gift.coinCost * _comboCount) {
      Navigator.of(context).pop();
      await CoinTopUpSheet.show(context: context, session: widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) => Container(
        decoration: const BoxDecoration(
          color: LiveColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: <Widget>[
            const _SheetGrip(),
            _WalletHeader(session: widget.session),
            TabBar(
              controller: _tabController,
              indicatorColor: LiveColors.accent,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: LiveColors.accent,
              unselectedLabelColor: LiveColors.textMuted,
              labelStyle: LiveTextStyles.caption.copyWith(fontWeight: FontWeight.w800),
              tabs: <Widget>[
                for (final GiftTier tier in GiftTier.values)
                  Tab(text: tier.name.toUpperCase()),
              ],
            ),
            Expanded(
              child: Obx(() {
                final List<GiftEntity> all = widget.controller.gifts;
                if (all.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(color: LiveColors.accent),
                  );
                }
                return TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    for (final GiftTier tier in GiftTier.values)
                      _GiftGrid(
                        gifts: all.where((GiftEntity g) => g.tier == tier).toList(),
                        selected: _selected,
                        walletBalance: widget.session.wallet.value.coinBalance,
                        onSelect: (GiftEntity gift) => setState(() {
                          _selected = gift;
                          _comboCount = 1;
                        }),
                      ),
                  ],
                );
              }),
            ),
            _SendBar(
              selected: _selected,
              comboCount: _comboCount,
              sending: _sending,
              onCombo: () => setState(() {
                // The server caps a combo at 99.
                _comboCount = _comboCount >= 99 ? 1 : _comboCount + 1;
              }),
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetGrip extends StatelessWidget {
  const _SheetGrip();

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 4,
    margin: const EdgeInsets.symmetric(vertical: 11),
    decoration: BoxDecoration(
      color: LiveColors.divider,
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

class _WalletHeader extends StatelessWidget {
  const _WalletHeader({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 0, 12, 12),
    child: Row(
      children: <Widget>[
        const Text('🪙', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Obx(
          () => Text(
            formatCompact(session.wallet.value.coinBalance),
            style: LiveTextStyles.title.copyWith(color: LiveColors.coin),
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => CoinTopUpSheet.show(context: context, session: session),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
          label: const Text('Top up'),
          style: TextButton.styleFrom(foregroundColor: LiveColors.accent),
        ),
      ],
    ),
  );
}

class _GiftGrid extends StatelessWidget {
  const _GiftGrid({
    required this.gifts,
    required this.selected,
    required this.onSelect,
    required this.walletBalance,
  });

  final List<GiftEntity> gifts;
  final GiftEntity? selected;
  final ValueChanged<GiftEntity> onSelect;
  final int walletBalance;

  @override
  Widget build(BuildContext context) {
    if (gifts.isEmpty) {
      return Center(
        child: Text('No gifts in this tier yet', style: LiveTextStyles.caption),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
      ),
      itemCount: gifts.length,
      itemBuilder: (BuildContext context, int index) {
        final GiftEntity gift = gifts[index];
        final bool isSelected = selected?.id == gift.id;
        final bool affordable = walletBalance >= gift.coinCost;
        final Color tint = LiveColors.forTier(gift.tier);

        return Opacity(
          opacity: affordable ? 1 : 0.48,
          child: GestureDetector(
            onTap: affordable ? () => onSelect(gift) : null,
            child: AnimatedContainer(
            duration: LiveMetrics.fast,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LiveMetrics.cardRadius),
              color: isSelected
                  ? tint.withValues(alpha: 0.16)
                  : LiveColors.surfaceRaised,
              border: Border.all(
                color: isSelected ? tint : Colors.transparent,
                width: 1.6,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                GiftArtwork(gift: gift, size: 42),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    gift.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: LiveTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('🪙', style: TextStyle(fontSize: 10)),
                    const SizedBox(width: 3),
                    Text(
                      formatCompact(gift.coinCost),
                      style: LiveTextStyles.caption.copyWith(
                        color: LiveColors.coin,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }
}

class _SendBar extends StatelessWidget {
  const _SendBar({
    required this.selected,
    required this.comboCount,
    required this.sending,
    required this.onCombo,
    required this.onSend,
  });

  final GiftEntity? selected;
  final int comboCount;
  final bool sending;
  final VoidCallback onCombo;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final GiftEntity? gift = selected;
    final int total = gift == null ? 0 : gift.coinCost * comboCount;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: <Widget>[
            // Tapping the counter raises the combo, matching how the animation
            // layer groups repeated sends.
            GestureDetector(
              onTap: gift == null ? null : onCombo,
              child: Container(
                height: 50,
                width: 62,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: LiveColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                  border: Border.all(color: LiveColors.divider),
                ),
                child: Text(
                  'x$comboCount',
                  style: LiveTextStyles.title.copyWith(
                    color: gift == null ? LiveColors.textMuted : LiveColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: gift == null || sending ? null : onSend,
                  style: FilledButton.styleFrom(
                    backgroundColor: LiveColors.accent,
                    foregroundColor: LiveColors.accentInk,
                    disabledBackgroundColor: LiveColors.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LiveMetrics.pillRadius),
                    ),
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: LiveColors.accentInk,
                          ),
                        )
                      : Text(
                          gift == null ? 'Pick a gift' : 'Send  ·  🪙 ${formatCompact(total)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
