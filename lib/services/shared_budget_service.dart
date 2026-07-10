import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shared_budget_model.dart';
import '../models/shared_expense_model.dart';
import '../models/shared_budget_invite_model.dart';

class SharedBudgetService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _sharedBudgetsRef => _db.collection('sharedBudgets');

  // ─── SHARED BUDGETS ───

  Stream<List<SharedBudgetModel>> watchSharedBudgets(String uid) {
    return _sharedBudgetsRef
        .where('members', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => SharedBudgetModel.fromFirestore(doc))
        .toList());
  }

  Stream<SharedBudgetModel?> watchSharedBudget(String budgetId) {
    return _sharedBudgetsRef.doc(budgetId).snapshots().map(
          (doc) => doc.exists ? SharedBudgetModel.fromFirestore(doc) : null,
    );
  }

  Future<String> createSharedBudget({
    required String name,
    required double limit,
    required String period,
    required String category,
    required String createdBy,
  }) async {
    final docRef = await _sharedBudgetsRef.add({
      'name': name,
      'limit': limit,
      'period': period,
      'category': category,
      'createdBy': createdBy,
      'members': [createdBy],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> updateSharedBudget(
      String budgetId, {
        required String name,
        required double limit,
        required String period,
        required String category,
      }) {
    return _sharedBudgetsRef.doc(budgetId).update({
      'name': name,
      'limit': limit,
      'period': period,
      'category': category,
    });
  }

  Future<void> deleteSharedBudget(String budgetId) {
    return _sharedBudgetsRef.doc(budgetId).delete();
  }

  Future<void> removeMember(String budgetId, String uid) {
    return _sharedBudgetsRef.doc(budgetId).update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> leaveSharedBudget(String budgetId, String uid) {
    return removeMember(budgetId, uid);
  }

  // ─── SHARED EXPENSES ───

  Stream<List<SharedExpenseModel>> watchSharedExpenses(String budgetId) {
    return _sharedBudgetsRef
        .doc(budgetId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => SharedExpenseModel.fromFirestore(doc))
        .toList());
  }

  Future<void> addSharedExpense(
      String budgetId, {
        required double amount,
        required String label,
        required DateTime date,
        required String addedBy,
        required String addedByName,
      }) {
    return _sharedBudgetsRef.doc(budgetId).collection('expenses').add({
      'amount': amount,
      'label': label,
      'date': Timestamp.fromDate(date),
      'addedBy': addedBy,
      'addedByName': addedByName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSharedExpense(String budgetId, String expenseId) {
    return _sharedBudgetsRef.doc(budgetId).collection('expenses').doc(expenseId).delete();
  }

  /// Supprime une dépense partagée et recrée une transaction personnelle
  /// équivalente pour l'utilisateur qui l'avait ajoutée.
  Future<void> unshareExpenseToPersonal(
      String budgetId,
      String expenseId, {
        required double amount,
        required String label,
        required DateTime date,
        required String addedBy,
      }) async {
    final batch = _db.batch();

    final expenseRef = _sharedBudgetsRef.doc(budgetId).collection('expenses').doc(expenseId);
    batch.delete(expenseRef);

    final transactionRef = _db.collection('users').doc(addedBy).collection('transactions').doc();
    batch.set(transactionRef, {
      'amount': amount,
      'type': 'expense',
      'category': 'Autre',
      'label': label,
      'date': Timestamp.fromDate(date),
      'addedBy': addedBy,
      'recurrenceId': null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ─── INVITES ───

  String _generateInviteCode([int length = 10]) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> createInvite(
      String budgetId, {
        required String createdBy,
        required int expiresInMinutes,
        required bool multipleUse,
      }) async {
    final code = _generateInviteCode();
    final expiresAt = DateTime.now().add(Duration(minutes: expiresInMinutes));

    final budgetDoc = await _sharedBudgetsRef.doc(budgetId).get();
    final budgetName = budgetDoc.exists
        ? (budgetDoc.data() as Map<String, dynamic>)['name'] ?? 'Budget partagé'
        : 'Budget partagé';

    await _sharedBudgetsRef.doc(budgetId).collection('invites').doc(code).set({
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'multipleUse': multipleUse,
      'usedCount': 0,
      'budgetName': budgetName,
    });

    return code;
  }

  Future<SharedBudgetInviteModel?> getInvite(String budgetId, String code) async {
    final doc = await _sharedBudgetsRef.doc(budgetId).collection('invites').doc(code).get();
    if (!doc.exists) return null;
    return SharedBudgetInviteModel.fromFirestore(code, doc.data()!);
  }

  Future<({bool success, String? error})> useInvite(
      String budgetId,
      String code,
      String uid,
      ) async {
    final invite = await getInvite(budgetId, code);
    if (invite == null) return (success: false, error: 'Lien invalide');
    if (invite.isExpired) return (success: false, error: 'Lien expiré');
    if (!invite.multipleUse && invite.usedCount >= 1) {
      return (success: false, error: 'Lien déjà utilisé');
    }

    await _sharedBudgetsRef.doc(budgetId).update({
      'members': FieldValue.arrayUnion([uid]),
    });
    await _sharedBudgetsRef.doc(budgetId).collection('invites').doc(code).update({
      'usedCount': FieldValue.increment(1),
    });

    return (success: true, error: null);
  }
}