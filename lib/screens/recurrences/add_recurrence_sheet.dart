import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/recurrence_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../models/recurrence_model.dart';
import '../../utils/amount_input_formatter.dart';
import '../../utils/default_categories.dart';
import '../../widgets/category_select.dart';

const _frequencies = {
  'daily': 'Quotidien',
  'weekly': 'Hebdomadaire',
  'monthly': 'Mensuel',
  'yearly': 'Annuel',
  'custom': 'Personnalisé',
};

class AddRecurrenceSheet extends StatefulWidget {
  /// Si fournie, le formulaire s'ouvre en mode édition pour cette récurrence.
  final RecurrenceModel? recurrence;

  const AddRecurrenceSheet({super.key, this.recurrence});

  @override
  State<AddRecurrenceSheet> createState() => _AddRecurrenceSheetState();
}

class _AddRecurrenceSheetState extends State<AddRecurrenceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  late final TextEditingController _labelController;
  late final TextEditingController _customDaysController;

  late String _type;
  String? _category;
  late String _frequency;
  late DateTime _nextOccurrence;
  bool _isSaving = false;
  bool _amountInitialized = false;

  bool get _isEditing => widget.recurrence != null;

  @override
  void initState() {
    super.initState();
    final recurrence = widget.recurrence;
    _type = recurrence?.type ?? 'expense';
    _category = recurrence?.category;
    _frequency = recurrence?.frequency ?? 'monthly';
    _nextOccurrence = recurrence?.nextOccurrence ?? DateTime.now();
    _labelController = TextEditingController(text: recurrence?.label ?? '');
    _customDaysController = TextEditingController(
      text: recurrence?.customDays?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  /// Pré-remplit le montant converti dans la devise d'affichage,
  /// une fois que CurrencyProvider a fini de charger le taux (ready).
  void _prefillAmountIfNeeded(CurrencyProvider currency) {
    if (_amountInitialized || !_isEditing || !currency.ready) return;
    _amountController.text = formatAmountInput(
      currency.fromBase(widget.recurrence!.amount),
    );
    _amountInitialized = true;
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
    final enteredAmount = parseAmountInput(_amountController.text)!;
    final amountInBase = currency.toBase(enteredAmount);
    final customDays = _frequency == 'custom'
        ? int.tryParse(_customDaysController.text)
        : null;

    final provider = context.read<RecurrenceProvider>();

    if (_isEditing) {
      await provider.updateRecurrenceDetails(
        uid,
        widget.recurrence!.id,
        type: _type,
        category: _category!,
        amount: amountInBase,
        label: _labelController.text.trim(),
        frequency: _frequency,
        customDays: customDays,
        nextOccurrence: _nextOccurrence,
      );
    } else {
      final recurrence = RecurrenceModel(
        id: '',
        type: _type,
        category: _category!,
        amount: amountInBase,
        label: _labelController.text.trim(),
        frequency: _frequency,
        customDays: customDays,
        nextOccurrence: _nextOccurrence,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await provider.addRecurrence(uid, recurrence);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    _prefillAmountIfNeeded(currency);
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
              _isEditing ? 'Modifier la récurrence' : 'Nouvelle récurrence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
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
            CategorySelect(
              categories:
                  context.watch<UserProfileProvider>().profile?.categoriesFor(
                    _type,
                  ) ??
                  (_type == 'expense'
                      ? kDefaultExpenseCategories
                      : kDefaultIncomeCategories),
              value: _category,
              onChanged: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Montant',
                prefixText: '${currency.symbol} ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Montant requis';
                final parsed = parseAmountInput(value);
                if (parsed == null || parsed <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Description (ex: Spotify)',
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Description requise'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Fréquence'),
              items: _frequencies.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
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
                  if (value == null || value.isEmpty)
                    return 'Nombre de jours requis';
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
                  context: context,
                  initialDate: _nextOccurrence,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _nextOccurrence = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Prochaine date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${_nextOccurrence.day}/${_nextOccurrence.month}/${_nextOccurrence.year}',
                ),
              ),
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
                  : Text(_isEditing ? 'Sauvegarder' : 'Créer la récurrence'),
            ),
          ],
        ),
      ),
    );
  }
}
