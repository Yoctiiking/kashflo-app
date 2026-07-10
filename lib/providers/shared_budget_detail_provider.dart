import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/shared_budget_model.dart';
import '../models/shared_expense_model.dart';
import '../services/shared_budget_service.dart';
import '../services/firestore_service.dart';

class SharedBudgetDetailProvider extends ChangeNotifier {
  final SharedBudgetService _service = SharedBudgetService();
  final FirestoreService _firestoreService = FirestoreService();

  String? _budgetId;
  StreamSubscription<SharedBudgetModel?>? _budgetSub;
  StreamSubscription<List<SharedExpenseModel>>? _expensesSub;

  SharedBudgetModel? budget;
  List<SharedExpenseModel> expenses = [];
  Map<String, String> memberNames = {};
  bool isLoading = true;

  double get totalSpent => expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get percentage =>
      budget == null || budget!.limit == 0 ? 0 : (totalSpent / budget!.limit).clamp(0.0, 1.0);
  bool get isOver => budget != null && totalSpent > budget!.limit;

  void listen(String budgetId) {
    if (_budgetId == budgetId) return;
    _budgetId = budgetId;

    _budgetSub?.cancel();
    _expensesSub?.cancel();

    isLoading = true;
    notifyListeners();

    _budgetSub = _service.watchSharedBudget(budgetId).listen((b) {
      budget = b;
      isLoading = false;
      notifyListeners();
      if (b != null) _loadMemberNames(b.members);
    });

    _expensesSub = _service.watchSharedExpenses(budgetId).listen((list) {
      expenses = list;
      notifyListeners();
    });
  }

  Future<void> _loadMemberNames(List<String> uids) async {
    final names = <String, String>{};
    await Future.wait(uids.map((uid) async {
      final profile = await _firestoreService.getUserProfile(uid);
      names[uid] = profile?.displayName ?? uid;
    }));
    memberNames = names;
    notifyListeners();
  }

  Future<void> addExpense({
    required double amount,
    required String label,
    required DateTime date,
    required String addedBy,
    required String addedByName,
  }) {
    return _service.addSharedExpense(
      _budgetId!,
      amount: amount,
      label: label,
      date: date,
      addedBy: addedBy,
      addedByName: addedByName,
    );
  }

  Future<void> deleteExpensePermanently(String expenseId) {
    return _service.deleteSharedExpense(_budgetId!, expenseId);
  }

  Future<void> unshareExpense(SharedExpenseModel expense) {
    return _service.unshareExpenseToPersonal(
      _budgetId!,
      expense.id,
      amount: expense.amount,
      label: expense.label,
      date: expense.date,
      addedBy: expense.addedBy,
    );
  }

  Future<String> createInvite({
    required String createdBy,
    required int expiresInMinutes,
    required bool multipleUse,
  }) {
    return _service.createInvite(
      _budgetId!,
      createdBy: createdBy,
      expiresInMinutes: expiresInMinutes,
      multipleUse: multipleUse,
    );
  }

  Future<void> removeMember(String uid) {
    return _service.removeMember(_budgetId!, uid);
  }

  Future<void> leaveBudget(String uid) {
    return _service.leaveSharedBudget(_budgetId!, uid);
  }

  Future<void> updateBudget({
    required String name,
    required double limit,
    required String period,
    required String category,
  }) {
    return _service.updateSharedBudget(
      _budgetId!,
      name: name,
      limit: limit,
      period: period,
      category: category,
    );
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
    _expensesSub?.cancel();
    super.dispose();
  }
}