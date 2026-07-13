import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/shared_budget_detail_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/transaction_model.dart';

class MigrateTransactionSheet extends StatefulWidget {
  const MigrateTransactionSheet({super.key});

  @override
  State<MigrateTransactionSheet> createState() => _MigrateTransactionSheetState();
}

class _MigrateTransactionSheetState extends State<MigrateTransactionSheet> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();

  late int _year;
  late int _month; // 1-12
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  bool _isMigrating = false;
  final Set<String> _selectedIds = {};

  final _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _year = _now.year;
    _month = _now.month;
    _loadMonth();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isCurrentMonth => _year == _now.year && _month == _now.month;

  Future<void> _loadMonth() async {
    setState(() => _isLoading = true);
    final uid = context.read<AuthProvider>().user!.uid;
    final txs = await _firestoreService.getMonthTransactions(uid, _year, _month);
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year -= 1;
      } else {
        _month -= 1;
      }
    });
    _loadMonth();
  }

  void _goToNextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year += 1;
      } else {
        _month += 1;
      }
    });
    _loadMonth();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  List<TransactionModel> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _transactions;
    return _transactions.where((t) {
      return t.label.toLowerCase().contains(query) ||
          t.amount.toString().contains(query);
    }).toList();
  }

  double get _selectedTotal => _transactions
      .where((t) => _selectedIds.contains(t.id))
      .fold(0.0, (sum, t) => sum + t.amount);

  Future<void> _handleMigrate() async {
    final toMigrate = _transactions.where((t) => _selectedIds.contains(t.id)).toList();
    if (toMigrate.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Déplacer ${toMigrate.length} transaction${toMigrate.length > 1 ? 's' : ''} ?'),
        content: const Text(
          'Elles seront retirées de tes transactions personnelles et ajoutées à ce budget partagé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Déplacer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isMigrating = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final displayName =
        context.read<UserProfileProvider>().profile?.displayName ??
        'Utilisateur';

    await context.read<SharedBudgetDetailProvider>().migrateTransactions(
      toMigrate,
      uid,
      displayName,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final monthLabel = DateFormat.yMMMM('fr_FR').format(DateTime(_year, _month));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Ajouter depuis mes transactions', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),

                // Navigation mois
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _goToPreviousMonth,
                    ),
                    SizedBox(
                      width: 160,
                      child: Text(
                        monthLabel[0].toUpperCase() + monthLabel.substring(1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _isCurrentMonth ? null : _goToNextMonth,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Recherche
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher par nom ou montant',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // Liste
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                      ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Aucune dépense ce mois-ci'
                          : 'Aucun résultat',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                      : ListView.builder(
                    controller: scrollController,
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final tx = _filtered[index];
                      final isSelected = _selectedIds.contains(tx.id);
                      final dateText = DateFormat('d MMM yyyy', 'fr_FR').format(tx.date);

                      return Card(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                            : null,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _isMigrating ? null : () => _toggleSelect(tx.id),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: _isMigrating ? null : (_) => _toggleSelect(tx.id),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.label,
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${tx.category} · $dateText',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  currency.formatCurrency(tx.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Bandeau bas si sélection
                if (_selectedIds.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_selectedIds.length} sélectionnée${_selectedIds.length > 1 ? 's' : ''}'),
                      Text(
                        currency.formatCurrency(_selectedTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isMigrating ? null : _handleMigrate,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isMigrating
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('Déplacer ${_selectedIds.length} transaction${_selectedIds.length > 1 ? 's' : ''}'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}