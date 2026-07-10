import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/shared_expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/shared_budget_detail_provider.dart';
import 'add_expense_choice_sheet.dart';
import 'add_shared_expense_sheet.dart';
import 'create_shared_budget_sheet.dart';
import 'delete_expense_dialog.dart';
import 'migrate_transaction_sheet.dart';

const _expiryOptions = [
  (label: '1 heure', minutes: 60),
  (label: '24 heures', minutes: 1440),
  (label: '7 jours', minutes: 10080),
];

class SharedBudgetDetailScreen extends StatefulWidget {
  final String budgetId;

  const SharedBudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<SharedBudgetDetailScreen> createState() =>
      _SharedBudgetDetailScreenState();
}

class _SharedBudgetDetailScreenState extends State<SharedBudgetDetailScreen> {
  bool _showInvite = false;
  bool _multipleUse = false;
  int _expiryMinutes = 1440;
  bool _isGeneratingInvite = false;

  Future<void> _generateInvite() async {
    setState(() => _isGeneratingInvite = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final provider = context.read<SharedBudgetDetailProvider>();
    final code = await provider.createInvite(
      createdBy: uid,
      expiresInMinutes: _expiryMinutes,
      multipleUse: _multipleUse,
    );

    final link =
        'https://kashflo-web.vercel.app/join-budget/${widget.budgetId}--$code';
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;
    setState(() => _isGeneratingInvite = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Lien copié !')));
  }

  Future<void> _confirmRemoveMember(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text('$name n\'aura plus accès à ce budget partagé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<SharedBudgetDetailProvider>().removeMember(uid);
    }
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitter ce budget partagé ?'),
        content: const Text('Tu n\'auras plus accès à ce budget partagé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Quitter', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = context.read<AuthProvider>().user!.uid;
      await context.read<SharedBudgetDetailProvider>().leaveBudget(uid);
      if (mounted) context.go('/budgets');
    }
  }

  Future<void> _handleDeleteExpense(SharedExpenseModel expense) async {
    final choice = await showDialog<DeleteExpenseChoice>(
      context: context,
      builder: (_) => DeleteExpenseDialog(expenseLabel: expense.label),
    );

    if (choice == null || choice == DeleteExpenseChoice.cancel) return;
    if (!mounted) return;

    final provider = context.read<SharedBudgetDetailProvider>();

    if (choice == DeleteExpenseChoice.permanent) {
      await provider.deleteExpensePermanently(expense.id);
    } else if (choice == DeleteExpenseChoice.unshare) {
      await provider.unshareExpense(expense);
    }
  }

  Future<void> _handleAddExpensePressed() async   {
    final detailProvider = context.read<SharedBudgetDetailProvider>();

    final choice = await showModalBottomSheet<AddExpenseChoice>(
      context: context,
      builder: (_) => const AddExpenseChoiceSheet(),
    );

    if (choice == null || !mounted) return;

    if (choice == AddExpenseChoice.newExpense) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => ChangeNotifierProvider.value(
          value: detailProvider,
          child: AddSharedExpenseSheet(budgetId: widget.budgetId),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ChangeNotifierProvider.value(
          value: detailProvider,
          child: const MigrateTransactionSheet(),
        ),
      );
    }
  }

  void _handleEditExpense(SharedExpenseModel expense) {
    final detailProvider = context.read<SharedBudgetDetailProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: detailProvider,
        child: AddSharedExpenseSheet(
          budgetId: widget.budgetId,
          expense: expense,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Consumer<SharedBudgetDetailProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final budget = provider.budget;
        if (budget == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Budget introuvable')),
            body: const Center(child: Text('Ce budget n\'existe pas ou plus.')),
          );
        }

        final uid = context.read<AuthProvider>().user!.uid;
        final isAdmin = budget.createdBy == uid;

        return Scaffold(
          appBar: AppBar(
            title: Text(budget.name),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    final detailProvider = context
                        .read<SharedBudgetDetailProvider>();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      builder: (_) => ChangeNotifierProvider.value(
                        value: detailProvider,
                        child: CreateSharedBudgetSheet(budget: budget),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Progression
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
                            '${currency.formatCurrency(provider.totalSpent)} dépensé',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: provider.isOver ? Colors.red : null,
                            ),
                          ),
                          Text(
                            currency.formatCurrency(budget.limit),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: provider.percentage,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            provider.isOver ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.isOver
                            ? '⚠️ Dépassé de ${currency.formatCurrency(provider.totalSpent - budget.limit)}'
                            : '${currency.formatCurrency(budget.limit - provider.totalSpent)} restant · ${(provider.percentage * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: provider.isOver
                              ? Colors.red
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Membres
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
                            'Membres (${budget.members.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (isAdmin)
                            TextButton(
                              onPressed: () =>
                                  setState(() => _showInvite = !_showInvite),
                              child: const Text('+ Inviter'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...budget.members.map((memberUid) {
                        final name =
                            provider.memberNames[memberUid] ?? memberUid;
                        final isMemberAdmin = memberUid == budget.createdBy;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMemberAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing:
                              isAdmin && !isMemberAdmin && memberUid != uid
                              ? TextButton(
                                  onPressed: () =>
                                      _confirmRemoveMember(memberUid, name),
                                  child: const Text(
                                    'Retirer',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                )
                              : null,
                        );
                      }),
                      if (_showInvite) ...[
                        const Divider(height: 24),
                        Wrap(
                          spacing: 8,
                          children: _expiryOptions.map((opt) {
                            final selected = _expiryMinutes == opt.minutes;
                            return ChoiceChip(
                              label: Text(opt.label),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _expiryMinutes = opt.minutes),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: false,
                              label: Text('🔒 Unique'),
                            ),
                            ButtonSegment(
                              value: true,
                              label: Text('♾️ Multiples'),
                            ),
                          ],
                          selected: {_multipleUse},
                          onSelectionChanged: (s) =>
                              setState(() => _multipleUse = s.first),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _isGeneratingInvite
                              ? null
                              : _generateInvite,
                          child: _isGeneratingInvite
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Générer et copier le lien'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Dépenses
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: const Text(
                              'Dépenses',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextButton(
                              onPressed: () => _handleAddExpensePressed(),
                              child: const Text('+ Ajouter'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (provider.expenses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Aucune dépense pour l\'instant',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      else
                        ...provider.expenses.map((expense) {
                          final dateText = DateFormat(
                            'd MMM',
                            'fr_FR',
                          ).format(expense.date);
                          final isOwner = expense.addedBy == uid;

                          final card = Card(
                            margin: EdgeInsets.zero,
                            shape: const RoundedRectangleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${expense.addedByName} · $dateText',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    currency.formatCurrency(expense.amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );

                          final item = !isOwner
                              ? card
                              : Slidable(
                                  key: ValueKey(expense.id),
                                  startActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    extentRatio: 0.25,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) =>
                                            _handleEditExpense(expense),
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        icon: Icons.edit_outlined,
                                        label: 'Modifier',
                                      ),
                                    ],
                                  ),
                                  endActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    extentRatio: 0.5,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) => context
                                            .read<SharedBudgetDetailProvider>()
                                            .unshareExpense(expense),
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        icon: Icons.call_split,
                                        label: 'Désolid.',
                                      ),
                                      SlidableAction(
                                        onPressed: (_) => context
                                            .read<SharedBudgetDetailProvider>()
                                            .deleteExpensePermanently(
                                              expense.id,
                                            ),
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        icon: Icons.delete_outline,
                                        label: 'Supprimer',
                                      ),
                                    ],
                                  ),
                                  child: card,
                                );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: item,
                          );
                        }),
                    ],
                  ),
                ),
              ),

              if (!isAdmin) ...[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _confirmLeave,
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Quitter ce budget partagé'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
