import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/shared_budgets_provider.dart';
import 'create_shared_budget_sheet.dart';
import 'join_shared_budget_dialog.dart';

const _periodLabels = {
  'daily': '/ jour',
  'weekly': '/ semaine',
  'monthly': '/ mois',
};

class SharedBudgetsScreen extends StatelessWidget {
  const SharedBudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets partagés'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Rejoindre avec un code',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const JoinSharedBudgetDialog(),
            ),
          ),
        ],
      ),
      body: Consumer<SharedBudgetsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.budgets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun budget partagé pour le moment',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.budgets.length,
            itemBuilder: (context, index) {
              final budget = provider.budgets[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.group)),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: budget.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' · ${budget.members.length} membre${budget.members.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                  subtitle: Text(
                    '${currency.formatCurrency(budget.limit)} ${_periodLabels[budget.period]}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/shared-budgets/${budget.id}'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab-shared-budgets',
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const CreateSharedBudgetSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
