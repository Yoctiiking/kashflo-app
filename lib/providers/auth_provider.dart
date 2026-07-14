import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/default_categories.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  User? get user => _user;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    _auth.authStateChanges().listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null; // succès
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<String?> register(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _db.collection('users').doc(cred.user!.uid).set({
        'displayName': displayName,
        'email': email,
        'currency': 'CAD',
        'expenseCategories': kDefaultExpenseCategories,
        'incomeCategories': kDefaultIncomeCategories,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  Future<void> logout() => _auth.signOut();

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      case 'user-not-found':
        return 'Email ou mot de passe incorrect';
      default:
        return 'Une erreur est survenue';
    }
  }
}
