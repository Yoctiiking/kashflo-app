import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/savings_goal_model.dart';
import '../services/firestore_service.dart';

class SavingsProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  StreamSubscription<List<SavingsGoalModel>>? _subscription;
  String? _uid;
  List<SavingsGoalModel> _goals = [];
  bool _isLoading = true;

  List<SavingsGoalModel> get goals => _goals;
  bool get isLoading => _isLoading;

  void updateUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;

    _subscription?.cancel();

    if (uid == null) {
      _goals = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _service.watchSavingsGoals(uid).listen((goals) {
      _goals = goals;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addGoal(String uid, SavingsGoalModel goal) {
    return _service.addSavingsGoal(uid, goal);
  }

  Future<void> deleteGoal(String uid, String goalId) {
    return _service.deleteSavingsGoal(uid, goalId);
  }

  Future<void> updateGoalDetails(
    String uid,
    String goalId, {
    required String name,
    required double targetAmount,
    required double currentAmount,
    DateTime? targetDate,
  }) {
    return _service.updateSavingsGoalDetails(
      uid,
      goalId,
      name: name,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
    );
  }

  Future<void> addToGoal(String uid, String goalId, double amount) {
    return _service.addToSavingsGoal(uid, goalId, amount);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
