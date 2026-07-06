import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  final String id;
  final String category;
  final double limit; // en CAD
  final String period; // 'day', 'week', 'month'
  final DateTime createdAt;

  BudgetModel({
    required this.id,
    required this.category,
    required this.limit,
    required this.period,
    required this.createdAt,
  });

  factory BudgetModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetModel(
      id: doc.id,
      category: data['category'] ?? '',
      limit: (data['limit'] as num).toDouble(),
      period: data['period'] ?? 'month',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'category': category,
      'limit': limit,
      'period': period,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}