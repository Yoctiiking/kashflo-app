import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shared_budgets_provider.dart';

const _expenseCategories = [
  'Alimentation',
  'Transport',
  'Logement',
  'Santé',
  'Loisirs',
  'Vêtements',
  'Abonnements',
  'Restaurants',
  'Éducation',
  'Autre',
];

const _periods = {'daily': 'Jour', 'weekly': 'Semaine', 'monthly': 'Mois'};

class CreateSharedBudgetSheet extends StatefulWidget {
  const CreateSharedBudgetSheet({super.key});

  @override
  State<CreateSharedBudgetSheet> createState() =>
      _CreateSharedBudgetSheetState();
}

class _CreateSharedBudgetSheetState extends State<CreateSharedBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();

  String? _category;
  String _period = 'monthly';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionne une catégorie')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final budgetId = await context
        .read<SharedBudgetsProvider>()
        .createSharedBudget(
          name: _nameController.text.trim(),
          limit: double.parse(_limitController.text.replaceAll(',', '.')),
          period: _period,
          category: _category!,
          createdBy: uid,
        );

    if (!mounted) return;
    Navigator.pop(context);
    context.push('/shared-budgets/$budgetId');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Nouveau budget partagé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom (ex: Appartement)',
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: _expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Limite',
                prefixText: '\$ ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Limite requise';
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: _periods.entries
                  .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                  .toList(),
              selected: {_period},
              onSelectionChanged: (selection) =>
                  setState(() => _period = selection.first),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
