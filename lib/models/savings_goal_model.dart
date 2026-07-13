import 'package:cloud_firestore/cloud_firestore.dart';

class SavingsGoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final DateTime createdAt;

  SavingsGoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.createdAt,
  });

  factory SavingsGoalModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavingsGoalModel(
      id: doc.id,
      name: data['name'] ?? '',
      targetAmount: (data['targetAmount'] as num).toDouble(),
      currentAmount: (data['currentAmount'] as num?)?.toDouble() ?? 0,
      targetDate: data['targetDate'] != null
          ? (data['targetDate'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      if (targetDate != null) 'targetDate': Timestamp.fromDate(targetDate!),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
