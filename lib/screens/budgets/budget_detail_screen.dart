import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/budget_model.dart';
import 'add_budget_sheet.dart';

const _periodLabels = {
  'daily': '/ jour',
  'weekly': '/ semaine',
  'monthly': '/ mois',
};

class BudgetDetailScreen extends StatelessWidget {
  final String budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  Widget build(BuildContext context) {
    return Consumer2<BudgetProvider, TransactionProvider>(
      builder: (context, budgetProvider, txProvider, _) {
        if (budgetProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        BudgetModel? budget;
        for (final b in budgetProvider.budgets) {
          if (b.id == budgetId) {
            budget = b;
            break;
          }
        }

        if (budget == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Budget introuvable')),
            body: const Center(child: Text('Ce budget n\'existe pas ou plus.')),
          );
        }

        final currency = context.watch<CurrencyProvider>();
        final spent = budgetProvider.spentFor(
          budget,
          txProvider.allTransactions,
        );
        final transactions = budgetProvider.transactionsFor(
          budget,
          txProvider.allTransactions,
        );
        final progress = budget.limit > 0
            ? (spent / budget.limit).clamp(0.0, 1.0)
            : 0.0;
        final isOverBudget = spent > budget.limit;
        final overAmount = spent - budget.limit;

        return Scaffold(
          appBar: AppBar(
            title: Text(budget.category),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => AddBudgetSheet(budget: budget),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, budget!.id),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            currency.formatCurrency(spent),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isOverBudget ? Colors.red : null,
                                ),
                          ),
                          Text(
                            '${currency.formatCurrency(budget.limit)} ${_periodLabels[budget.period] ?? ''}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            isOverBudget ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOverBudget
                            ? '⚠️ Dépassé de ${currency.formatCurrency(overAmount)}'
                            : '${currency.formatCurrency(budget.limit - spent)} restant · ${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverBudget
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Transactions',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Aucune dépense sur cette période',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ...transactions.map((tx) {
                  final dateText = DateFormat('dd/MM/yyyy').format(tx.date);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(tx.label),
                      subtitle: Text(dateText),
                      trailing: Text(
                        currency.formatCurrency(tx.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, String budgetId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce budget ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<BudgetProvider>().deleteBudget(uid, budgetId);
    if (context.mounted) context.pop();
  }
}
