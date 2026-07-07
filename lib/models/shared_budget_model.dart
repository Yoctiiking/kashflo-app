import 'package:cloud_firestore/cloud_firestore.dart';

class SharedBudgetModel {
  final String id;
  final String name;
  final double limit;
  final String period; // 'day', 'week', 'month'
  final String category;
  final String createdBy;
  final List<String> members;
  final DateTime createdAt;

  SharedBudgetModel({
    required this.id,
    required this.name,
    required this.limit,
    required this.period,
    required this.category,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  factory SharedBudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedBudgetModel(
      id: doc.id,
      name: data['name'] ?? '',
      limit: (data['limit'] as num).toDouble(),
      period: data['period'] ?? 'monthly',
      category: data['category'] ?? '',
      createdBy: data['createdBy'] ?? '',
      members: List<String>.from(data['members'] ?? []),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'limit': limit,
      'period': period,
      'category': category,
      'createdBy': createdBy,
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}