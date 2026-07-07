import 'package:cloud_firestore/cloud_firestore.dart';

class RecurrenceModel {
  final String id;
  final String type; // 'expense' ou 'income'
  final String category;
  final double amount;
  final String label; // aligné sur le champ "label" du web
  final String frequency; // 'daily', 'weekly', 'monthly', 'yearly', 'custom'
  final int? customDays; // requis si frequency == 'custom'
  final DateTime nextOccurrence; // aligné sur le champ "nextOccurrence" du web
  final bool isActive;
  final DateTime createdAt;

  RecurrenceModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.label,
    required this.frequency,
    this.customDays,
    required this.nextOccurrence,
    required this.isActive,
    required this.createdAt,
  });

  factory RecurrenceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecurrenceModel(
      id: doc.id,
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      label: data['label'] ?? '',
      frequency: data['frequency'] ?? 'monthly',
      customDays: data['customDays'],
      nextOccurrence: (data['nextOccurrence'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'category': category,
      'amount': amount,
      'label': label,
      'frequency': frequency,
      if (customDays != null) 'customDays': customDays,
      'nextOccurrence': Timestamp.fromDate(nextOccurrence),
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Calcule la prochaine occurrence à partir d'une date donnée,
  /// selon la fréquence de cette récurrence.
  DateTime computeNextOccurrence(DateTime from) {
    switch (frequency) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(from.year, from.month + 1, from.day);
      case 'yearly':
        return DateTime(from.year + 1, from.month, from.day);
      case 'custom':
        return from.add(Duration(days: customDays ?? 30));
      default:
        return DateTime(from.year, from.month + 1, from.day);
    }
  }
}