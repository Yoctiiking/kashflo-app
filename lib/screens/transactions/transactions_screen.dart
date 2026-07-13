import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../utils/transactions_csv_export.dart';
import 'add_transaction_sheet.dart';
import 'month_picker_sheet.dart';

enum TransactionFilter { all, expense, income }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TransactionFilter _filter = TransactionFilter.all;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearching() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
  }

  Future<void> _pickMonth(TransactionProvider txProvider) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MonthPickerSheet(initialMonth: txProvider.selectedMonth),
    );
    if (picked != null) txProvider.goToMonth(picked);
  }

  Future<void> _export(
    TransactionProvider txProvider,
    CurrencyProvider currency,
  ) async {
    // Ancre requise pour le popover de partage (iPad / certains simulateurs).
    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    setState(() => _isExporting = true);
    try {
      await exportTransactionsToCsv(
        transactions: txProvider.transactionsForSelectedMonth,
        month: txProvider.selectedMonth,
        currency: currency,
        sharePositionOrigin: origin,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher une transaction',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Consumer<TransactionProvider>(
                builder: (context, txProvider, _) {
                  final monthLabel = DateFormat.yMMMM(
                    'fr_FR',
                  ).format(txProvider.selectedMonth);
                  final label =
                      monthLabel[0].toUpperCase() + monthLabel.substring(1);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: txProvider.goToPreviousMonth,
                        visualDensity: VisualDensity.compact,
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _pickMonth(txProvider),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(label),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: txProvider.canGoToNextMonth
                            ? txProvider.goToNextMonth
                            : null,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  );
                },
              ),
        actions: [
          if (_isSearching)
            IconButton(icon: const Icon(Icons.close), onPressed: _stopSearching)
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
            Consumer<TransactionProvider>(
              builder: (context, txProvider, _) => IconButton(
                icon: _isExporting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                onPressed: _isExporting
                    ? null
                    : () => _export(txProvider, currency),
              ),
            ),
          ],
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, txProvider, _) {
          if (txProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _searchController.text.trim().toLowerCase();

          final filtered = txProvider.transactionsForSelectedMonth.where((t) {
            final matchesFilter = switch (_filter) {
              TransactionFilter.expense => t.type == 'expense',
              TransactionFilter.income => t.type == 'income',
              TransactionFilter.all => true,
            };
            final matchesQuery =
                query.isEmpty ||
                t.label.toLowerCase().contains(query) ||
                t.category.toLowerCase().contains(query);
            return matchesFilter && matchesQuery;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<TransactionFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TransactionFilter.all,
                      label: Text('Tout'),
                    ),
                    ButtonSegment(
                      value: TransactionFilter.expense,
                      label: Text('Dépenses'),
                    ),
                    ButtonSegment(
                      value: TransactionFilter.income,
                      label: Text('Revenus'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) {
                    setState(() => _filter = selection.first);
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Aucune transaction',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : SlidableAutoCloseBehavior(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final tx = filtered[index];
                            return _TransactionCard(
                              transaction: tx,
                              onEdit: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (_) =>
                                    AddTransactionSheet(transaction: tx),
                              ),
                              onDelete: () async {
                                final confirmed = await _confirmDelete(context);
                                if (!confirmed || !context.mounted) return;
                                final uid = context
                                    .read<AuthProvider>()
                                    .user!
                                    .uid;
                                context
                                    .read<TransactionProvider>()
                                    .deleteTransaction(uid, tx.id);
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-transactions',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const AddTransactionSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette transaction ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final isExpense = transaction.type == 'expense';
    final amountText =
        '${isExpense ? '-' : '+'}${currency.formatCurrency(transaction.amount)}';
    final dateText = DateFormat('dd/MM/yyyy').format(transaction.date);

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
        title: Text(transaction.label),
        subtitle: Text('${transaction.category} · $dateText'),
        trailing: Text(
          amountText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
      ),
    );

    final containerColor = Theme.of(context).scaffoldBackgroundColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        color: containerColor,
        child: Slidable(
          key: ValueKey(transaction.id),
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
