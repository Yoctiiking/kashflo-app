import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class BudgetProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  StreamSubscription<List<BudgetModel>>? _subscription;
  String? _uid;
  List<BudgetModel> _budgets = [];
  bool _isLoading = true;

  List<BudgetModel> get budgets => _budgets;
  bool get isLoading => _isLoading;

  void updateUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;

    _subscription?.cancel();

    if (uid == null) {
      _budgets = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _service.watchBudgets(uid).listen((budgets) {
      _budgets = budgets;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addBudget(String uid, BudgetModel budget) {
    return _service.addBudget(uid, budget);
  }

  Future<void> deleteBudget(String uid, String budgetId) {
    return _service.deleteBudget(uid, budgetId);
  }

  /// Calcule le montant dépensé pour un budget donné, sur la période
  /// calendaire correspondante (jour / semaine ISO / mois civil),
  /// à partir de TOUTES les transactions de l'utilisateur (pas seulement
  /// celles du mois courant), pour que budgets journaliers/hebdo restent
  /// corrects même en fin de mois.
  double spentFor(BudgetModel budget, List<TransactionModel> allTransactions) {
    final range = _periodRange(budget.period);

    return allTransactions
        .where((t) =>
    t.type == 'expense' &&
        t.category == budget.category &&
        !t.date.isBefore(range.start) &&
        t.date.isBefore(range.end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  ({DateTime start, DateTime end}) _periodRange(String period) {
    final now = DateTime.now();

    switch (period) {
      case 'day':
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return (start: start, end: end);

      case 'week':
      // Semaine ISO : lundi -> dimanche
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(Duration(days: today.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return (start: start, end: end);

      case 'month':
      default:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start: start, end: end);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}