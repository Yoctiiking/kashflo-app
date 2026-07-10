import 'package:flutter/material.dart';

enum AddExpenseChoice { newExpense, migrateTransaction }

class AddExpenseChoiceSheet extends StatelessWidget {
  const AddExpenseChoiceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: const Text('Nouvelle dépense'),
            subtitle: const Text('Ajouter directement une dépense partagée'),
            onTap: () => Navigator.pop(context, AddExpenseChoice.newExpense),
          ),
          ListTile(
            leading: const Icon(Icons.move_down_outlined),
            title: const Text('Depuis mes transactions'),
            subtitle: const Text('Déplacer une transaction personnelle existante'),
            onTap: () => Navigator.pop(context, AddExpenseChoice.migrateTransaction),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}