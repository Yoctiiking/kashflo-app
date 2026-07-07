import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recurrence_provider.dart';
import '../../models/recurrence_model.dart';

const _expenseCategories = [
  'Alimentation', 'Transport', 'Logement', 'Santé', 'Loisirs',
  'Vêtements', 'Abonnements', 'Restaurants', 'Éducation', 'Autre',
];
const _incomeCategories = ['Salaire', 'Freelance', 'Investissements', 'Remboursement', 'Autre'];

const _frequencies = {
  'daily': 'Quotidien',
  'weekly': 'Hebdomadaire',
  'monthly': 'Mensuel',
  'yearly': 'Annuel',
  'custom': 'Personnalisé',
};

class AddRecurrenceSheet extends StatefulWidget {
  const AddRecurrenceSheet({super.key});

  @override
  State<AddRecurrenceSheet> createState() => _AddRecurrenceSheetState();
}

class _AddRecurrenceSheetState extends State<AddRecurrenceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _labelController = TextEditingController();
  final _customDaysController = TextEditingController();

  String _type = 'expense';
  String? _category;
  String _frequency = 'monthly';
  DateTime _nextOccurrence = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  List<String> get _categories =>
      _type == 'expense' ? _expenseCategories : _incomeCategories;

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
    final recurrence = RecurrenceModel(
      id: '',
      type: _type,
      category: _category!,
      amount: double.parse(_amountController.text.replaceAll(',', '.')),
      label: _labelController.text.trim(),
      frequency: _frequency,
      customDays: _frequency == 'custom'
          ? int.tryParse(_customDaysController.text)
          : null,
      nextOccurrence: _nextOccurrence,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await context.read<RecurrenceProvider>().addRecurrence(uid, recurrence);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Nouvelle récurrence', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Dépense')),
                ButtonSegment(value: 'income', label: Text('Revenu')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                  _category = null;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Montant', prefixText: '\$ '),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Montant requis';
                final parsed = double.tryParse(value.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Description (ex: Spotify)'),
              validator: (value) => (value == null || value.isEmpty) ? 'Description requise' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Fréquence'),
              items: _frequencies.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (value) => setState(() => _frequency = value!),
            ),
            if (_frequency == 'custom') ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tous les combien de jours ?',
                  suffixText: 'jours',
                ),
                validator: (value) {
                  if (_frequency != 'custom') return null;
                  if (value == null || value.isEmpty) return 'Nombre de jours requis';
                  final parsed = int.tryParse(value);
                  if (parsed == null || parsed <= 0) return 'Valeur invalide';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _nextOccurrence,
                  firstDate: DateTime.now(), lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _nextOccurrence = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Prochaine date', prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text('${_nextOccurrence.day}/${_nextOccurrence.month}/${_nextOccurrence.year}'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Créer la récurrence'),
            ),
          ],
        ),
      ),
    );
  }
}