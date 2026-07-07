import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/recurrence_model.dart';
import '../models/transaction_model.dart';
import '../services/firestore_service.dart';

class RecurrenceProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  StreamSubscription<List<RecurrenceModel>>? _subscription;
  String? _uid;
  List<RecurrenceModel> _recurrences = [];
  bool _isLoading = true;

  List<RecurrenceModel> get recurrences => _recurrences;
  bool get isLoading => _isLoading;

  /// Récurrences actives dont la prochaine occurrence est passée ou aujourd'hui
  List<RecurrenceModel> get dueRecurrences {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _recurrences
        .where((r) => r.isActive && !r.nextOccurrence.isAfter(today))
        .toList();
  }

  void updateUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;

    _subscription?.cancel();

    if (uid == null) {
      _recurrences = [];
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _service.watchRecurrences(uid).listen((list) {
      _recurrences = list;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addRecurrence(String uid, RecurrenceModel recurrence) {
    return _service.addRecurrence(uid, recurrence);
  }

  Future<void> deleteRecurrence(String uid, String id) {
    return _service.deleteRecurrence(uid, id);
  }

  Future<void> toggleRecurrence(String uid, RecurrenceModel recurrence) {
    return _service.updateRecurrence(uid, recurrence.id, {
      'isActive': !recurrence.isActive,
    });
  }

  /// Génère les transactions en retard pour toutes les récurrences dues.
  /// Retourne le nombre de transactions créées.
  Future<int> generateDueTransactions(String uid) async {
    int count = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final recurrence in _recurrences.where((r) => r.isActive)) {
      var next = recurrence.nextOccurrence;

      // Génère toutes les occurrences en retard, pas seulement une
      while (!next.isAfter(today)) {
        await _service.addTransaction(
          uid,
          TransactionModel.fromRecurrence(recurrence, next, uid),
        );
        count++;
        next = recurrence.computeNextOccurrence(next);
      }

      if (count > 0) {
        await _service.updateRecurrenceNextOccurrence(uid, recurrence.id, next);
      }
    }

    return count;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}