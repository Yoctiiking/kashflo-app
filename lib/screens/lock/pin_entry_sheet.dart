import 'package:flutter/material.dart';

/// Affiche le sheet de saisie de code et retourne les 4 chiffres saisis,
/// ou `null` si l'utilisateur l'a fermé sans terminer.
Future<String?> showPinEntrySheet(
  BuildContext context, {
  required String title,
  String? errorText,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PinEntrySheet(title: title, errorText: errorText),
  );
}

/// Bottom sheet de saisie d'un code à 4 chiffres.
/// Retourne le code saisi via [Navigator.pop] une fois les 4 chiffres entrés.
class PinEntrySheet extends StatefulWidget {
  final String title;
  final String? errorText;

  const PinEntrySheet({super.key, required this.title, this.errorText});

  @override
  State<PinEntrySheet> createState() => _PinEntrySheetState();
}

class _PinEntrySheetState extends State<PinEntrySheet> {
  String _pin = '';

  void _onDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) {
      Navigator.pop(context, _pin);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final filled = i < _pin.length;
              return Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              );
            }),
          ),
          if (widget.errorText != null) ...[
            const SizedBox(height: 12),
            Text(widget.errorText!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
          ])
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((d) => _key(context, d)).toList(),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 72, height: 72),
              _key(context, '0'),
              SizedBox(
                width: 72,
                height: 72,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(36),
                    onTap: _onBackspace,
                    child: const Center(
                      child: Icon(Icons.backspace_outlined, size: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _key(BuildContext context, String digit) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: () => _onDigit(digit),
          child: Center(
            child: Text(
              digit,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
      ),
    );
  }
}
