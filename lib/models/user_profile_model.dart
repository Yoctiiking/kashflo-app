import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileModel {
  final String displayName;
  final String email;
  final String? photoURL;
  final String currency;
  final DateTime createdAt;
  final int onboardingVersion;

  UserProfileModel({
    required this.displayName,
    required this.email,
    this.photoURL,
    required this.currency,
    required this.createdAt,
    required this.onboardingVersion,
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
    );
  }
}