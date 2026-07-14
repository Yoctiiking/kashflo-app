import 'package:flutter/material.dart';
import '../../main.dart';

/// Écran neutre affiché pendant que l'app est `inactive` (centre de
/// contrôle, volet de notification, changement d'app...), pour qu'aucune
/// donnée sensible n'apparaisse dans l'instantané pris par l'OS à ce
/// moment-là.
class PrivacyCover extends StatelessWidget {
  const PrivacyCover({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kBrandGreen,
      child: Center(
        child: Icon(
          Icons.account_balance_wallet_outlined,
          size: 64,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
