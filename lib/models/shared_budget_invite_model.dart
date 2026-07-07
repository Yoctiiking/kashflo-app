import 'package:cloud_firestore/cloud_firestore.dart';

class SharedBudgetInviteModel {
  final String code;
  final String createdBy;
  final DateTime expiresAt;
  final bool multipleUse;
  final int usedCount;
  final String budgetName;

  SharedBudgetInviteModel({
    required this.code,
    required this.createdBy,
    required this.expiresAt,
    required this.multipleUse,
    required this.usedCount,
    required this.budgetName,
  });

  factory SharedBudgetInviteModel.fromFirestore(String code, Map<String, dynamic> data) {
    return SharedBudgetInviteModel(
      code: code,
      createdBy: data['createdBy'] ?? '',
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      multipleUse: data['multipleUse'] ?? false,
      usedCount: data['usedCount'] ?? 0,
      budgetName: data['budgetName'] ?? 'Budget partagé',
    );
  }

  bool get isExpired => expiresAt.isBefore(DateTime.now());
}