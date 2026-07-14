import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';
import '../services/firestore_service.dart';

class UserProfileProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  StreamSubscription<UserProfileModel?>? _subscription;
  String? _uid;
  UserProfileModel? _profile;
  bool _isLoading = true;

  UserProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;

  /// Appelé quand l'utilisateur connecté change (login/logout)
  void updateUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;

    _subscription?.cancel();

    if (uid == null) {
      _profile = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _subscription = _service.watchUserProfile(uid).listen((profile) {
      _profile = profile;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> updateDisplayName(String uid, String displayName) {
    return _service.updateDisplayName(uid, displayName);
  }

  Future<void> updateCurrency(String uid, String currency) {
    return _service.updateUserCurrency(uid, currency);
  }

  Future<void> updateCategories(
    String uid,
    String type,
    List<String> categories,
  ) {
    return _service.updateUserCategories(uid, type, categories);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
