import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/live_theme.dart';
import '../../domain/entities/live_entities.dart';
import '../controllers/session_controller.dart';

/// Coin purchase.
///
/// The packages and prices come from the server, but no payment provider is
/// wired in yet: the backend only credits a wallet when it is explicitly
/// configured to allow unverified top ups, and refuses otherwise. The banner
/// says so plainly rather than implying a real charge took place.
class CoinTopUpSheet extends StatefulWidget {
  const CoinTopUpSheet({required this.session, super.key});

  final SessionController session;

  static Future<void> show({
    required BuildContext context,
    required SessionController session,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => CoinTopUpSheet(session: session),
  );

  @override
  State<CoinTopUpSheet> createState() => _CoinTopUpSheetState();
}

class _CoinTopUpSheetState extends State<CoinTopUpSheet> {
  String? _pendingPackageId;

  @override
  void initState() {
    super.initState();
    widget.session.loadCoinPackages();
  }

  Future<void> _buy(CoinPackageEntity package) async {
    setState(() => _pendingPackageId = package.id);
    final bool ok = await widget.session.purchase(package.id);
    if (!mounted) {
      return;
    }
    setState(() => _pendingPackageId = null);

    final String? error = widget.session.errorMessage.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? LiveColors.surfaceRaised : LiveColors.live,
        content: Text(
          ok
              ? '${package.coins} coins added to your wallet'
              : error ?? 'The top up could not be completed',
        ),
      ),
    );
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: LiveColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: LiveColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  Text('Get coins', style: LiveTextStyles.displayLarge.copyWith(fontSize: 22)),
                  const Spacer(),
                  const Text('🪙', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Obx(
                    () => Text(
                      formatCompact(widget.session.wallet.value.coinBalance),
                      style: LiveTextStyles.title.copyWith(color: LiveColors.coin),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Obx(() {
              final List<CoinPackageEntity> packages = widget.session.coinPackages;
              if (packages.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(color: LiveColors.accent),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: packages.length,
                itemBuilder: (BuildContext context, int index) => _PackageCard(
                  package: packages[index],
                  isBusy: _pendingPackageId == packages[index].id,
                  onTap: () => _buy(packages[index]),
                ),
              );
            }),
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: _SandboxNotice(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.isBusy,
    required this.onTap,
  });

  final CoinPackageEntity package;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isBusy ? null : onTap,
    child: Container(
      decoration: BoxDecoration(
        color: LiveColors.surfaceRaised,
        borderRadius: BorderRadius.circular(LiveMetrics.cardRadius),
        border: Border.all(color: LiveColors.coin.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (isBusy)
            const CircularProgressIndicator(strokeWidth: 2.2, color: LiveColors.coin)
          else ...<Widget>[
            const Text('🪙', style: TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Text(
              formatCompact(package.coins),
              style: LiveTextStyles.title.copyWith(color: LiveColors.coin),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${package.priceUsd.toStringAsFixed(2)}',
              style: LiveTextStyles.caption,
            ),
          ],
        ],
      ),
    ),
  );
}

class _SandboxNotice extends StatelessWidget {
  const _SandboxNotice();

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const Icon(Icons.info_outline_rounded, size: 15, color: LiveColors.textMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'No payment provider is connected yet, so these packages credit the '
          'wallet directly and no money changes hands.',
          style: LiveTextStyles.caption.copyWith(
            color: LiveColors.textMuted,
            fontSize: 11,
          ),
        ),
      ),
    ],
  );
}
