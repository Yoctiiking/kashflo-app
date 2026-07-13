import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Sélecteur de mois (année + grille des 12 mois), affiché en bottom sheet.
/// Retourne le mois choisi (année/mois, jour fixé à 1) via [Navigator.pop].
class MonthPickerSheet extends StatefulWidget {
  final DateTime initialMonth;

  const MonthPickerSheet({super.key, required this.initialMonth});

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialMonth.year;
  }

  bool get _canGoToNextYear => _year < DateTime.now().year;

  bool _isFuture(int month) {
    final now = DateTime.now();
    return _year > now.year || (_year == now.year && month > now.month);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _year--),
              ),
              Text('$_year', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _canGoToNextYear
                    ? () => setState(() => _year++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2,
            children: List.generate(12, (index) {
              final month = index + 1;
              final isSelected =
                  _year == widget.initialMonth.year &&
                  month == widget.initialMonth.month;
              final isFuture = _isFuture(month);
              final label = DateFormat(
                'MMM',
                'fr_FR',
              ).format(DateTime(_year, month));

              return OutlinedButton(
                onPressed: isFuture
                    ? null
                    : () => Navigator.pop(context, DateTime(_year, month)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(label[0].toUpperCase() + label.substring(1)),
              );
            }),
          ),
        ],
      ),
    );
  }
}
