import 'package:cloud_firestore/cloud_firestore.dart';

class SharedExpenseModel {
  final String id;
  final double amount;
  final String label;
  final DateTime date;
  final String addedBy;
  final String addedByName;
  final DateTime createdAt;

  SharedExpenseModel({
    required this.id,
    required this.amount,
    required this.label,
    required this.date,
    required this.addedBy,
    required this.addedByName,
    required this.createdAt,
  });

  factory SharedExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SharedExpenseModel(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      label: data['label'] ?? '',
      date: data['date'] != null
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      addedBy: data['addedBy'] ?? '',
      addedByName: data['addedByName'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'amount': amount,
      'label': label,
      'date': Timestamp.fromDate(date),
      'addedBy': addedBy,
      'addedByName': addedByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}