import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/shared_budget_detail_provider.dart';

class AddSharedExpenseSheet extends StatefulWidget {
  final String budgetId;
  const AddSharedExpenseSheet({super.key, required this.budgetId});

  @override
  State<AddSharedExpenseSheet> createState() => _AddSharedExpenseSheetState();
}

class _AddSharedExpenseSheetState extends State<AddSharedExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final currency = context.read<CurrencyProvider>();
    final uid = authProvider.user!.uid;
    final displayName = authProvider.user!.displayName ?? 'Utilisateur';

    final enteredAmount = double.parse(_amountController.text.replaceAll(',', '.'));

    await context.read<SharedBudgetDetailProvider>().addExpense(
      amount: currency.toBase(enteredAmount),
      label: _labelController.text.trim(),
      date: _date,
      addedBy: uid,
      addedByName: displayName,
    );

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
            Text('Nouvelle dépense', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) =>
              (value == null || value.isEmpty) ? 'Description requise' : null,
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
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context, initialDate: _date,
                  firstDate: DateTime(2020), lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date', prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text('${_date.day}/${_date.month}/${_date.year}'),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }
}