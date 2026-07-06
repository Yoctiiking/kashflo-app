import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _transactionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  CollectionReference _budgetsRef(String uid) =>
      _db.collection('users').doc(uid).collection('budgets');

  // Transactions
  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _transactionsRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .toList());
  }

  Future<void> addTransaction(String uid, TransactionModel tx) {
    return _transactionsRef(uid).add(tx.toFirestore());
  }

  Future<void> deleteTransaction(String uid, String txId) {
    return _transactionsRef(uid).doc(txId).delete();
  }

  // Budgets
  Stream<List<BudgetModel>> watchBudgets(String uid) {
    return _budgetsRef(uid)
        .snapshots()
        .map((snap) =>
        snap.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList());
  }

  Future<void> addBudget(String uid, BudgetModel budget) {
    return _budgetsRef(uid).add(budget.toFirestore());
  }

  Future<void> deleteBudget(String uid, String budgetId) {
    return _budgetsRef(uid).doc(budgetId).delete();
  }
}