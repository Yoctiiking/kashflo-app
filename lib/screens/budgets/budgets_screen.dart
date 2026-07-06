import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/budget_model.dart';
import 'add_budget_sheet.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Consumer2<BudgetProvider, TransactionProvider>(
        builder: (context, budgetProvider, txProvider, _) {
          if (budgetProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (budgetProvider.budgets.isEmpty) {
            return Center(
              child: Text(
                'Aucun budget pour le moment',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: budgetProvider.budgets.length,
            itemBuilder: (context, index) {
              final budget = budgetProvider.budgets[index];
              final spent = budgetProvider.spentFor(
                budget,
                txProvider.allTransactions,
              );
              return _BudgetCard(
                budget: budget,
                spent: spent,
                currencyFormat: currencyFormat,
                onDelete: () {
                  final uid = context.read<AuthProvider>().user!.uid;
                  context.read<BudgetProvider>().deleteBudget(uid, budget.id);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddBudgetSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetModel budget;
  final double spent;
  final NumberFormat currencyFormat;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.currencyFormat,
    required this.onDelete,
  });

  String get _periodLabel {
    switch (budget.period) {
      case 'day':
        return '/ jour';
      case 'week':
        return '/ semaine';
      case 'month':
      default:
        return '/ mois';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = budget.limit > 0 ? (spent / budget.limit).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = spent > budget.limit;
    final overAmount = spent - budget.limit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    budget.category,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${currencyFormat.format(spent)} / ${currencyFormat.format(budget.limit)} $_periodLabel',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? Colors.red : Colors.green,
                ),
              ),
            ),
            if (isOverBudget) ...[
              const SizedBox(height: 6),
              Text(
                'Dépassé de ${currencyFormat.format(overAmount)}',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}