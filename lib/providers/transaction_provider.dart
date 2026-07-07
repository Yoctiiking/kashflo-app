import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/monthly_total.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class TransactionProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  StreamSubscription<List<TransactionModel>>? _subscription;
  String? _uid;
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  /// Transactions du mois en cours uniquement (aligné sur le web)
  List<TransactionModel> get transactions {
    final now = DateTime.now();
    return _transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
  }

  List<TransactionModel> get recentTransactions =>
      transactions.take(5).toList();

  double get balance {
    return transactions.fold(0.0, (sum, t) {
      return t.type == 'income' ? sum + t.amount : sum - t.amount;
    });
  }

  void updateUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;

    _subscription?.cancel();

    if (uid == null) {
      _transactions = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _service.watchTransactions(uid).listen((txs) {
      _transactions = txs;
      _isLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> deleteTransaction(String uid, String txId) {
    return _service.deleteTransaction(uid, txId);
  }

  Future<void> addTransaction(String uid, TransactionModel tx) {
    return _service.addTransaction(uid, tx);
  }

  /// Toutes les transactions chargées, sans filtre de mois
  /// (nécessaire pour le calcul des budgets jour/semaine/mois)
  List<TransactionModel> get allTransactions => _transactions;

  /// Revenus/dépenses agrégés par mois, sur les 6 derniers mois
  /// (basé sur allTransactions, pas seulement le mois courant)
  List<MonthlyTotal> get last6MonthsTotals {
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final date = DateTime(now.year, now.month - (5 - i), 1);
      return date;
    });

    return months.map((month) {
      final monthTx = _transactions.where(
        (t) => t.date.year == month.year && t.date.month == month.month,
      );

      final income = monthTx
          .where((t) => t.type == 'income')
          .fold(0.0, (sum, t) => sum + t.amount);
      final expense = monthTx
          .where((t) => t.type == 'expense')
          .fold(0.0, (sum, t) => sum + t.amount);

      return MonthlyTotal(month: month, income: income, expense: expense);
    }).toList();
  }

  /// Répartition des dépenses par catégorie pour le mois courant
  Map<String, double> get categoryBreakdown {
    final result = <String, double>{};
    for (final t in transactions.where((t) => t.type == 'expense')) {
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }
}
