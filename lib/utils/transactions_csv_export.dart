import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction_model.dart';
import '../providers/currency_provider.dart';

String _csvField(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

/// Génère un CSV des transactions données et ouvre la feuille de partage
/// native (enregistrer, envoyer par mail, etc.).
Future<void> exportTransactionsToCsv({
  required List<TransactionModel> transactions,
  required DateTime month,
  required CurrencyProvider currency,
  Rect? sharePositionOrigin,
}) async {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final buffer = StringBuffer()
    ..writeln('Date,Type,Catégorie,Description,Montant,Devise');

  for (final tx in transactions) {
    final amount = currency.fromBase(tx.amount).toStringAsFixed(2);
    buffer.writeln(
      [
        dateFormat.format(tx.date),
        tx.type == 'expense' ? 'Dépense' : 'Revenu',
        _csvField(tx.category),
        _csvField(tx.label),
        amount,
        currency.currency,
      ].join(','),
    );
  }

  final monthSlug = DateFormat('yyyy-MM').format(month);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/transactions_$monthSlug.csv');
  await file.writeAsString(buffer.toString());

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      subject: 'Transactions $monthSlug',
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}
