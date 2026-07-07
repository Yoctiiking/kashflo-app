import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurrence_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _transactionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  CollectionReference _budgetsRef(String uid) =>
      _db.collection('users').doc(uid).collection('budgets');

  CollectionReference _recurrencesRef(String uid) =>
      _db.collection('users').doc(uid).collection('recurrences');

  // Transactions
  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _transactionsRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList(),
    );
  }

  Future<void> addTransaction(String uid, TransactionModel tx) {
    return _transactionsRef(uid).add(tx.toFirestore());
  }

  Future<void> deleteTransaction(String uid, String txId) {
    return _transactionsRef(uid).doc(txId).delete();
  }

  // Budgets
  Stream<List<BudgetModel>> watchBudgets(String uid) {
    return _budgetsRef(uid).snapshots().map(
          (snap) => snap.docs.map((doc) => BudgetModel.fromFirestore(doc)).toList(),
    );
  }

  Future<void> addBudget(String uid, BudgetModel budget) {
    return _budgetsRef(uid).add(budget.toFirestore());
  }

  Future<void> deleteBudget(String uid, String budgetId) {
    return _budgetsRef(uid).doc(budgetId).delete();
  }

  // Recurrences
  Stream<List<RecurrenceModel>> watchRecurrences(String uid) {
    return _recurrencesRef(uid)
        .orderBy('nextOccurrence')
        .snapshots()
        .map(
          (snap) => snap.docs
          .map((doc) => RecurrenceModel.fromFirestore(doc))
          .toList(),
    );
  }

  Future<void> addRecurrence(String uid, RecurrenceModel recurrence) {
    return _recurrencesRef(uid).add(recurrence.toFirestore());
  }

  Future<void> deleteRecurrence(String uid, String id) {
    return _recurrencesRef(uid).doc(id).delete();
  }

  Future<void> updateRecurrence(
      String uid,
      String id,
      Map<String, dynamic> data,
      ) {
    return _recurrencesRef(uid).doc(id).update(data);
  }

  Future<void> updateRecurrenceNextOccurrence(
      String uid,
      String recurrenceId,
      DateTime nextOccurrence,
      ) {
    return _recurrencesRef(uid).doc(recurrenceId).update({
      'nextOccurrence': Timestamp.fromDate(nextOccurrence),
    });
  }
}