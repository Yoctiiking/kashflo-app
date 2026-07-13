import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/savings_provider.dart';
import '../../models/savings_goal_model.dart';
import '../../utils/amount_input_formatter.dart';

class AddSavingsGoalSheet extends StatefulWidget {
  /// Si fourni, le formulaire s'ouvre en mode édition pour cet objectif.
  final SavingsGoalModel? goal;

  const AddSavingsGoalSheet({super.key, this.goal});

  @override
  State<AddSavingsGoalSheet> createState() => _AddSavingsGoalSheetState();
}

class _AddSavingsGoalSheetState extends State<AddSavingsGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _targetAmountController = TextEditingController();
  final _currentAmountController = TextEditingController(text: '0');
  DateTime? _targetDate;
  bool _isSaving = false;
  bool _amountsInitialized = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal?.name ?? '');
    _targetDate = widget.goal?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _currentAmountController.dispose();
    super.dispose();
  }

  /// Pré-remplit les montants convertis dans la devise d'affichage,
  /// une fois que CurrencyProvider a fini de charger le taux (ready).
  void _prefillAmountsIfNeeded(CurrencyProvider currency) {
    if (_amountsInitialized || !_isEditing || !currency.ready) return;
    _targetAmountController.text = formatAmountInput(
      currency.fromBase(widget.goal!.targetAmount),
    );
    _currentAmountController.text = formatAmountInput(
      currency.fromBase(widget.goal!.currentAmount),
    );
    _amountsInitialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final uid = context.read<AuthProvider>().user!.uid;
    final currency = context.read<CurrencyProvider>();
    final targetAmount = currency.toBase(
      parseAmountInput(_targetAmountController.text)!,
    );
    final currentAmount = currency.toBase(
      parseAmountInput(_currentAmountController.text) ?? 0,
    );
    final name = _nameController.text.trim();

    final provider = context.read<SavingsProvider>();

    if (_isEditing) {
      await provider.updateGoalDetails(
        uid,
        widget.goal!.id,
        name: name,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: _targetDate,
      );
    } else {
      final goal = SavingsGoalModel(
        id: '',
        name: name,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        targetDate: _targetDate,
        createdAt: DateTime.now(),
      );
      await provider.addGoal(uid, goal);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    _prefillAmountsIfNeeded(currency);

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
              _isEditing ? "Modifier l'objectif" : "Nouvel objectif d'épargne",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Nom de l'objectif",
                hintText: "Ex: Vacances, Fonds d'urgence...",
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Nom requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Montant cible',
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
              controller: _currentAmountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Montant déjà épargné',
                prefixText: '${currency.symbol} ',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                final parsed = parseAmountInput(value);
                if (parsed == null || parsed < 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _targetDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _targetDate = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date cible (optionnel)',
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  suffixIcon: _targetDate != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _targetDate = null),
                        )
                      : null,
                ),
                child: Text(
                  _targetDate != null
                      ? '${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}'
                      : '',
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
                  : Text(_isEditing ? 'Sauvegarder' : "Créer l'objectif"),
            ),
          ],
        ),
      ),
    );
  }
}
