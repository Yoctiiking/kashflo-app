import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/budget_provider.dart';
import '../../providers/currency_provider.dart';
import '../../models/budget_model.dart';

const _expenseCategories = [
  'Alimentation',
  'Transport',
  'Logement',
  'Santé',
  'Loisirs',
  'Vêtements',
  'Abonnements',
  'Restaurants',
  'Éducation',
  'Autre',
];

const _periods = {
  'daily': 'Jour',
  'weekly': 'Semaine',
  'monthly': 'Mois',
};

class AddBudgetSheet extends StatefulWidget {
  /// Si fourni, le formulaire s'ouvre en mode édition pour ce budget.
  final BudgetModel? budget;

  const AddBudgetSheet({super.key, this.budget});

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();

  String? _category;
  late String _period;
  bool _isSaving = false;
  bool _limitInitialized = false;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    _category = widget.budget?.category;
    _period = widget.budget?.period ?? 'monthly';
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  /// Pré-remplit la limite convertie dans la devise d'affichage,
  /// une fois que CurrencyProvider a fini de charger le taux (ready).
  void _prefillLimitIfNeeded(CurrencyProvider currency) {
    if (_limitInitialized || !_isEditing || !currency.ready) return;
    _limitController.text = currency
        .fromBase(widget.budget!.limit)
        .toStringAsFixed(2);
    _limitInitialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _category == null) {
      if (_category == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionne une catégorie')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final currency = context.read<CurrencyProvider>();
    final enteredLimit = double.parse(_limitController.text.replaceAll(',', '.'));
    final limitInBase = currency.toBase(enteredLimit);

    final provider = context.read<BudgetProvider>();

    if (_isEditing) {
      await provider.updateBudgetDetails(
        uid,
        widget.budget!.id,
        category: _category!,
        limit: limitInBase,
        period: _period,
      );
    } else {
      final budget = BudgetModel(
        id: '',
        category: _category!,
        limit: limitInBase,
        period: _period,
        createdAt: DateTime.now(),
      );
      await provider.addBudget(uid, budget);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    _prefillLimitIfNeeded(currency);
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
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
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEditing ? 'Modifier le budget' : 'Nouveau budget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: _expenseCategories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Limite',
                prefixText: '${currency.symbol} ',
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
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : Text(_isEditing ? 'Sauvegarder' : 'Créer le budget'),
            ),
          ],
        ),
      ),
    );
  }
}