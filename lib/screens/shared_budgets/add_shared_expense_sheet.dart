import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/shared_budget_detail_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../models/shared_expense_model.dart';
import '../../utils/amount_input_formatter.dart';

class AddSharedExpenseSheet extends StatefulWidget {
  final String budgetId;

  /// Si fourni, le formulaire s'ouvre en mode édition pour cette dépense.
  final SharedExpenseModel? expense;

  const AddSharedExpenseSheet({
    super.key,
    required this.budgetId,
    this.expense,
  });

  @override
  State<AddSharedExpenseSheet> createState() => _AddSharedExpenseSheetState();
}

class _AddSharedExpenseSheetState extends State<AddSharedExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  final _amountController = TextEditingController();
  late DateTime _date;
  bool _isSaving = false;
  bool _initialized = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.expense?.label ?? '');
    _date = widget.expense?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Pré-remplit le montant converti dans la devise d'affichage,
  /// une fois que CurrencyProvider a fini de charger le taux (ready).
  void _prefillAmountIfNeeded(CurrencyProvider currency) {
    if (_initialized || !_isEditing || !currency.ready) return;
    _amountController.text = formatAmountInput(
      currency.fromBase(widget.expense!.amount),
    );
    _initialized = true;
  }

  Future<void> _submit(CurrencyProvider currency) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final enteredAmount = parseAmountInput(_amountController.text)!;
    final amountInBase = currency.toBase(enteredAmount);
    // On ne garde que le jour (sans l'heure) pour que le tri par date reste
    // cohérent avec les entrées créées côté web, qui n'ont pas de composante
    // horaire. Le départage entre dépenses d'un même jour se fait ensuite
    // via createdAt.
    final normalizedDate = DateTime(_date.year, _date.month, _date.day);

    final provider = context.read<SharedBudgetDetailProvider>();

    if (_isEditing) {
      await provider.updateExpense(
        widget.expense!.id,
        amount: amountInBase,
        label: _labelController.text.trim(),
        date: normalizedDate,
      );
    } else {
      final uid = context.read<AuthProvider>().user!.uid;
      final displayName =
          context.read<UserProfileProvider>().profile?.displayName ??
          'Utilisateur';

      await provider.addExpense(
        amount: amountInBase,
        label: _labelController.text.trim(),
        date: normalizedDate,
        addedBy: uid,
        addedByName: displayName,
      );
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
              _isEditing ? 'Modifier la dépense' : 'Nouvelle dépense',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Description requise'
                  : null,
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
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : () => _submit(currency),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Sauvegarder' : 'Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}
