import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/default_categories.dart';

class UserProfileModel {
  final String displayName;
  final String email;
  final String? photoURL;
  final String currency;
  final DateTime createdAt;
  final int onboardingVersion;
  final List<String> expenseCategories;
  final List<String> incomeCategories;

  UserProfileModel({
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.currency,
    required this.createdAt,
    required this.onboardingVersion,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfileModel(
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      photoURL: data['photoURL'],
      currency: data['currency'] ?? 'CAD',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      onboardingVersion: data['onboardingVersion'] ?? 0,
      expenseCategories: data['expenseCategories'] != null
          ? List<String>.from(data['expenseCategories'])
          : kDefaultExpenseCategories,
      incomeCategories: data['incomeCategories'] != null
          ? List<String>.from(data['incomeCategories'])
          : kDefaultIncomeCategories,
    );
  }

  /// Renvoie la liste des catégories pour le type donné ('expense'/'income').
  List<String> categoriesFor(String type) =>
      type == 'expense' ? expenseCategories : incomeCategories;
}
