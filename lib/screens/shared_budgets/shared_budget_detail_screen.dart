import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/shared_budget_detail_provider.dart';
import 'add_shared_expense_sheet.dart';

const _expiryOptions = [
  (label: '1 heure', minutes: 60),
  (label: '24 heures', minutes: 1440),
  (label: '7 jours', minutes: 10080),
];

class SharedBudgetDetailScreen extends StatefulWidget {
  final String budgetId;
  const SharedBudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<SharedBudgetDetailScreen> createState() => _SharedBudgetDetailScreenState();
}

class _SharedBudgetDetailScreenState extends State<SharedBudgetDetailScreen> {
  bool _showInvite = false;
  bool _multipleUse = false;
  int _expiryMinutes = 1440;
  bool _isGeneratingInvite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharedBudgetDetailProvider>().listen(widget.budgetId);
    });
  }

  Future<void> _generateInvite() async {
    setState(() => _isGeneratingInvite = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final provider = context.read<SharedBudgetDetailProvider>();
    final code = await provider.createInvite(
      createdBy: uid,
      expiresInMinutes: _expiryMinutes,
      multipleUse: _multipleUse,
    );

    final link = 'https://kashflo-web.vercel.app/join-budget/${widget.budgetId}--$code';
    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;
    setState(() => _isGeneratingInvite = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié !')),
    );
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

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Consumer<SharedBudgetDetailProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                    // TODO: réutiliser CreateSharedBudgetSheet en mode édition
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
                          color: provider.isOver ? Colors.red : Colors.grey.shade600,
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
                              onPressed: () => setState(() => _showInvite = !_showInvite),
                              child: const Text('+ Inviter'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...budget.members.map((memberUid) {
                        final name = provider.memberNames[memberUid] ?? memberUid;
                        final isMemberAdmin = memberUid == budget.createdBy;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                          ),
                          title: Row(
                            children: [
                              Flexible(child: Text(name, overflow: TextOverflow.ellipsis)),
                              if (isMemberAdmin) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Admin', style: TextStyle(fontSize: 11, color: Colors.green)),
                                ),
                              ],
                            ],
                          ),
                          trailing: isAdmin && !isMemberAdmin && memberUid != uid
                              ? TextButton(
                            onPressed: () => _confirmRemoveMember(memberUid, name),
                            child: const Text('Retirer', style: TextStyle(color: Colors.red)),
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
                              onSelected: (_) => setState(() => _expiryMinutes = opt.minutes),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('🔒 Unique')),
                            ButtonSegment(value: true, label: Text('♾️ Multiples')),
                          ],
                          selected: {_multipleUse},
                          onSelectionChanged: (s) => setState(() => _multipleUse = s.first),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _isGeneratingInvite ? null : _generateInvite,
                          child: _isGeneratingInvite
                              ? const SizedBox(
                            height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Dépenses', style: TextStyle(fontWeight: FontWeight.w600)),
                          TextButton(
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              ),
                              builder: (_) => AddSharedExpenseSheet(budgetId: widget.budgetId),
                            ),
                            child: const Text('+ Ajouter'),
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
                          final dateText = DateFormat('d MMM', 'fr_FR').format(expense.date);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(expense.label),
                            subtitle: Text('${expense.addedByName} · $dateText'),
                            trailing: Text(
                              currency.formatCurrency(expense.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                            ),
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