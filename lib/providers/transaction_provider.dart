import 'dart:async';
import 'package:flutter/foundation.dart';
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
}