import 'package:flutter/material.dart';

enum DeleteExpenseChoice { permanent, unshare, cancel }

class DeleteExpenseDialog extends StatelessWidget {
  final String expenseLabel;

  const DeleteExpenseDialog({super.key, required this.expenseLabel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Supprimer cette dépense ?'),
      content: Text(
        '« $expenseLabel » — choisis comment tu veux la retirer du budget partagé.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, DeleteExpenseChoice.cancel),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DeleteExpenseChoice.unshare),
          child: const Text('Désolidariser'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, DeleteExpenseChoice.permanent),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}