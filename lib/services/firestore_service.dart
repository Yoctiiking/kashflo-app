import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurrence_model.dart';
import '../models/savings_goal_model.dart';
import '../models/transaction_model.dart';
import '../models/budget_model.dart';
import '../models/user_profile_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _transactionsRef(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  CollectionReference _budgetsRef(String uid) =>
      _db.collection('users').doc(uid).collection('budgets');

  CollectionReference _recurrencesRef(String uid) =>
      _db.collection('users').doc(uid).collection('recurrences');

  CollectionReference _savingsGoalsRef(String uid) =>
      _db.collection('users').doc(uid).collection('savingsGoals');

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

  Future<void> updateTransactionDetails(
    String uid,
    String txId, {
    required String type,
    required String category,
    required double amount,
    required String label,
    required DateTime date,
  }) {
    return _transactionsRef(uid).doc(txId).update({
      'type': type,
      'category': category,
      'amount': amount,
      'label': label,
      'date': Timestamp.fromDate(date),
    });
  }

  Future<List<TransactionModel>> getMonthTransactions(
    String uid,
    int year,
    int month,
  ) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final snapshot = await _transactionsRef(uid)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('date', isLessThan: Timestamp.fromDate(endOfMonth))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc))
        .where((t) => t.type == 'expense')
        .toList();
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

  Future<void> updateBudgetDetails(
    String uid,
    String budgetId, {
    required String category,
    required double limit,
    required String period,
  }) {
    return _budgetsRef(uid).doc(budgetId).update({
      'category': category,
      'limit': limit,
      'period': period,
    });
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

  Future<void> updateRecurrenceDetails(
    String uid,
    String id, {
    required String type,
    required String category,
    required double amount,
    required String label,
    required String frequency,
    int? customDays,
    required DateTime nextOccurrence,
  }) {
    return _recurrencesRef(uid).doc(id).update({
      'type': type,
      'category': category,
      'amount': amount,
      'label': label,
      'frequency': frequency,
      'customDays': customDays,
      'nextOccurrence': Timestamp.fromDate(nextOccurrence),
    });
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

  // Objectifs d'épargne
  Stream<List<SavingsGoalModel>> watchSavingsGoals(String uid) {
    return _savingsGoalsRef(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SavingsGoalModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addSavingsGoal(String uid, SavingsGoalModel goal) {
    return _savingsGoalsRef(uid).add(goal.toFirestore());
  }

  Future<void> deleteSavingsGoal(String uid, String goalId) {
    return _savingsGoalsRef(uid).doc(goalId).delete();
  }

  Future<void> updateSavingsGoalDetails(
    String uid,
    String goalId, {
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? targetDate,
  }) {
    return _savingsGoalsRef(uid).doc(goalId).update({
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate) : null,
    });
  }

  Future<void> addToSavingsGoal(String uid, String goalId, double amount) {
    return _savingsGoalsRef(
      uid,
    ).doc(goalId).update({'currentAmount': FieldValue.increment(amount)});
  }

  // User profile
  Future<UserProfileModel?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfileModel.fromFirestore(doc);
  }

  Stream<UserProfileModel?> watchUserProfile(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfileModel.fromFirestore(doc) : null);
  }

  Future<void> updateDisplayName(String uid, String displayName) {
    return _db.collection('users').doc(uid).update({
      'displayName': displayName,
    });
  }

  Future<void> updateUserCurrency(String uid, String currency) {
    return _db.collection('users').doc(uid).update({'currency': currency});
  }

  Future<void> updateUserCategories(
    String uid,
    String type,
    List<String> categories,
  ) {
    final field = type == 'expense' ? 'expenseCategories' : 'incomeCategories';
    return _db.collection('users').doc(uid).update({field: categories});
  }
}
