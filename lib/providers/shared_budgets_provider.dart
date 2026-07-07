import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/shared_budget_model.dart';
import '../services/shared_budget_service.dart';

class SharedBudgetsProvider extends ChangeNotifier {
  final SharedBudgetService _service = SharedBudgetService();

  StreamSubscription<List<SharedBudgetModel>>? _subscription;
  String? _uid;
  List<SharedBudgetModel> _budgets = [];
  bool _isLoading = true;

  List<SharedBudgetModel> get budgets => _budgets;
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

    _subscription = _service.watchSharedBudgets(uid).listen((list) {
      _budgets = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<String> createSharedBudget({
    required String name,
    required double limit,
    required String period,
    required String category,
    required String createdBy,
  }) {
    return _service.createSharedBudget(
      name: name,
      limit: limit,
      period: period,
      category: category,
      createdBy: createdBy,
    );
  }

  Future<({bool success, String? error})> joinWithInvite(
      String budgetId,
      String code,
      String uid,
      ) {
    return _service.useInvite(budgetId, code, uid);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}