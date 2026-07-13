import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/recurrence_provider.dart';
import '../../models/recurrence_model.dart';
import 'add_recurrence_sheet.dart';

const _frequencyLabels = {
  'daily': 'Quotidien',
  'weekly': 'Hebdomadaire',
  'monthly': 'Mensuel',
  'yearly': 'Annuel',
  'custom': 'Personnalisé',
};

class RecurrencesScreen extends StatefulWidget {
  const RecurrencesScreen({super.key});

  @override
  State<RecurrencesScreen> createState() => _RecurrencesScreenState();
}

class _RecurrencesScreenState extends State<RecurrencesScreen> {
  bool _isGenerating = false;

  Future<void> _generate() async {
    setState(() => _isGenerating = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final count = await context
        .read<RecurrenceProvider>()
        .generateDueTransactions(uid);

    if (!mounted) return;
    setState(() => _isGenerating = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? '$count transaction${count > 1 ? 's' : ''} générée${count > 1 ? 's' : ''}'
              : 'Aucune transaction à générer — tout est à jour',
        ),
      ),
    );
  }

  void _handleEditRecurrence(RecurrenceModel recurrence) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddRecurrenceSheet(recurrence: recurrence),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Récurrences'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Consumer<RecurrenceProvider>(
              builder: (context, provider, _) {
                final hasDue = provider.dueRecurrences.isNotEmpty;
                return TextButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: Text(hasDue ? 'Générer' : 'À jour'),
                );
              },
            ),
          ),
        ],
      ),
      body: Consumer<RecurrenceProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.recurrences.isEmpty) {
            return Center(
              child: Text(
                'Aucune récurrence pour le moment',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return SlidableAutoCloseBehavior(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.recurrences.length,
              itemBuilder: (context, index) {
                final recurrence = provider.recurrences[index];
                return _RecurrenceCard(
                  recurrence: recurrence,
                  onToggle: () {
                    final uid = context.read<AuthProvider>().user!.uid;
                    context.read<RecurrenceProvider>().toggleRecurrence(
                      uid,
                      recurrence,
                    );
                  },
                  onEdit: () => _handleEditRecurrence(recurrence),
                  onDelete: () {
                    final uid = context.read<AuthProvider>().user!.uid;
                    context.read<RecurrenceProvider>().deleteRecurrence(
                      uid,
                      recurrence.id,
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-recurrences',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddRecurrenceSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecurrenceCard extends StatelessWidget {
  final RecurrenceModel recurrence;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecurrenceCard({
    required this.recurrence,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final isExpense = recurrence.type == 'expense';
    final dateText = DateFormat('dd/MM/yyyy').format(recurrence.nextOccurrence);
    final card = Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isExpense
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
          child: Icon(
            isExpense ? Icons.arrow_downward : Icons.arrow_upward,
            color: isExpense ? Colors.red : Colors.green,
            size: 20,
          ),
        ),
        title: Text(recurrence.label),
        subtitle: Text(
          '${currency.formatCurrency(recurrence.amount)} · ${_frequencyLabels[recurrence.frequency]} · Prochaine: $dateText',
        ),
        isThreeLine: true,
        trailing: Switch(
          value: recurrence.isActive,
          onChanged: (_) => onToggle(),
        ),
      ),
    );

    final containerColor = Theme.of(context).colorScheme.surfaceContainerLow;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        color: containerColor,
        child: Slidable(
          key: ValueKey(recurrence.id),
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
