import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kashflo_mobile/models/recurrence_model.dart';

class TransactionModel {
  final String id;
  final String type; // 'expense' ou 'income'
  final String category;
  final double amount; // stocké en CAD (devise pivot), comme sur le web
  final String label; // aligné sur le champ "label" du web (anciennement "description")
  final DateTime date;
  final String addedBy; // uid de l'utilisateur, requis côté web
  final String? recurrenceId; // lien vers la récurrence source, si applicable
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.label,
    required this.date,
    required this.addedBy,
    this.recurrenceId,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      type: data['type'] ?? 'expense',
      category: data['category'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      label: data['label'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      addedBy: data['addedBy'] ?? '',
      recurrenceId: data['recurrenceId'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory TransactionModel.fromRecurrence(
      RecurrenceModel recurrence,
      DateTime date,
      String addedBy,
      ) {
    return TransactionModel(
      id: '',
      type: recurrence.type,
      category: recurrence.category,
      amount: recurrence.amount,
      label: recurrence.label,
      date: date,
      addedBy: addedBy,
      recurrenceId: recurrence.id,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'category': category,
      'amount': amount,
      'label': label,
      'date': Timestamp.fromDate(date),
      'addedBy': addedBy,
      'recurrenceId': recurrenceId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}