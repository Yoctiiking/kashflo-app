import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/savings_provider.dart';
import '../../models/savings_goal_model.dart';
import '../../utils/amount_input_formatter.dart';
import 'add_savings_goal_sheet.dart';

class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Épargne')),
      body: Consumer<SavingsProvider>(
        builder: (context, savingsProvider, _) {
          if (savingsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (savingsProvider.goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Aucun objectif d'épargne",
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crée un objectif pour suivre ta progression',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SlidableAutoCloseBehavior(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savingsProvider.goals.length,
              itemBuilder: (context, index) {
                final goal = savingsProvider.goals[index];
                return _SavingsGoalCard(
                  goal: goal,
                  onEdit: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (_) => AddSavingsGoalSheet(goal: goal),
                  ),
                  onDelete: () => _confirmDelete(context, goal.id),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-savings',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddSavingsGoalSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String goalId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet objectif ?'),
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
    await context.read<SavingsProvider>().deleteGoal(uid, goalId);
  }
}

class _SavingsGoalCard extends StatefulWidget {
  final SavingsGoalModel goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SavingsGoalCard({
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SavingsGoalCard> createState() => _SavingsGoalCardState();
}

class _SavingsGoalCardState extends State<_SavingsGoalCard> {
  final _amountController = TextEditingController();
  bool _isAddingAmount = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _confirmAddAmount(CurrencyProvider currency) async {
    final parsed = parseAmountInput(_amountController.text);
    if (parsed == null || parsed <= 0) return;

    setState(() => _isSubmitting = true);
    final uid = context.read<AuthProvider>().user!.uid;
    await context.read<SavingsProvider>().addToGoal(
      uid,
      widget.goal.id,
      currency.toBase(parsed),
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _isAddingAmount = false;
      _amountController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final goal = widget.goal;
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final isComplete = goal.currentAmount >= goal.targetAmount;
    final remaining = goal.targetAmount - goal.currentAmount;

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              goal.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (goal.targetDate != null) ...[
              const SizedBox(height: 2),
              Text(
                'Objectif : ${DateFormat('d MMM yyyy', 'fr_FR').format(goal.targetDate!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currency.formatCurrency(goal.currentAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isComplete ? Colors.green : null,
                  ),
                ),
                Text(
                  currency.formatCurrency(goal.targetAmount),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  isComplete ? Colors.green : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isComplete
                  ? '🎉 Objectif atteint !'
                  : '${currency.formatCurrency(remaining)} restant · ${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                color: isComplete ? Colors.green : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            if (_isAddingAmount) ...[
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ThousandsSeparatorInputFormatter()],
                decoration: InputDecoration(
                  labelText: 'Montant à ajouter',
                  prefixText: '${currency.symbol} ',
                  isDense: true,
                ),
                onSubmitted: (_) => _confirmAddAmount(currency),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _confirmAddAmount(currency),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirmer'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _isAddingAmount = false;
                        _amountController.clear();
                      }),
                      child: const Text('Annuler'),
                    ),
                  ),
                ],
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _isAddingAmount = true),
                  child: const Text('+ Ajouter un montant'),
                ),
              ),
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
          key: ValueKey(goal.id),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.22,
            children: [
              CustomSlidableAction(
                onPressed: (_) => widget.onEdit(),
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
                onPressed: (_) => widget.onDelete(),
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
