import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/budget_model.dart';
import 'add_budget_sheet.dart';

class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Budgets partagés',
            onPressed: () => context.push('/shared-budgets'),
          ),
        ],
      ),
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

          return SlidableAutoCloseBehavior(
            child: ListView.builder(
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
                  onEdit: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => AddBudgetSheet(budget: budget),
                  ),
                  onDelete: () {
                    final uid = context.read<AuthProvider>().user!.uid;
                    context.read<BudgetProvider>().deleteBudget(uid, budget.id);
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-budgets',
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  String get _periodLabel {
    switch (budget.period) {
      case 'daily':
        return '/ jour';
      case 'weekly':
        return '/ semaine';
      case 'monthly':
      default:
        return '/ mois';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final progress = budget.limit > 0
        ? (spent / budget.limit).clamp(0.0, 1.0)
        : 0.0;
    final isOverBudget = spent > budget.limit;
    final overAmount = spent - budget.limit;

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  budget.category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _periodLabel,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                children: [
                  TextSpan(
                    text: currency.formatCurrency(spent),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isOverBudget
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextSpan(text: ' / ${currency.formatCurrency(budget.limit)}'),
                ],
              ),
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
                'Dépassé de ${currency.formatCurrency(overAmount)}',
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

    final containerColor = Theme.of(context).scaffoldBackgroundColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        color: containerColor,
        child: Slidable(
          key: ValueKey(budget.id),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.22,
            children: [
              CustomSlidableAction(
                onPressed: (_) => onEdit(),
                backgroundColor: containerColor,
                child: const _CircleActionIcon(
                  color: Colors.blue,
                  icon: Icons.edit_outlined,
                  maxRatio: 0.22,
                ),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.22,
            children: [
              CustomSlidableAction(
                onPressed: (_) => onDelete(),
                backgroundColor: containerColor,
                child: const _CircleActionIcon(
                  color: Colors.red,
                  icon: Icons.delete_outline,
                  maxRatio: 0.22,
                ),
              ),
            ],
          ),
          child: card,
        ),
      ),
    );
  }
}

class _CircleActionIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double maxRatio;

  const _CircleActionIcon({
    required this.color,
    required this.icon,
    required this.maxRatio,
  });

  @override
  Widget build(BuildContext context) {
    final animation = Slidable.of(context)!.animation;
    return Center(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = (animation.value / maxRatio).clamp(0.0, 1.0);
          final scale = 0.03 + 0.97 * progress;
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
