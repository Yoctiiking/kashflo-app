import 'package:flutter/services.dart';

/// Formatte un champ de saisie de montant en ajoutant un espace comme
/// séparateur de milliers au fur et à mesure de la frappe
/// (ex: "1234567" -> "1 234 567").
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  const ThousandsSeparatorInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final cursorFromEnd = newValue.text.length - newValue.selection.end;

    // Normalise le séparateur décimal et ne garde qu'une seule virgule.
    var raw = newValue.text.replaceAll('.', ',');
    final firstComma = raw.indexOf(',');
    if (firstComma != -1) {
      raw =
          raw.substring(0, firstComma + 1) +
          raw.substring(firstComma + 1).replaceAll(',', '');
    }

    final commaIndex = raw.indexOf(',');
    final integerPart = (commaIndex == -1 ? raw : raw.substring(0, commaIndex))
        .replaceAll(RegExp(r'[^0-9]'), '');
    final decimalPart = commaIndex == -1
        ? null
        : raw.substring(commaIndex + 1).replaceAll(RegExp(r'[^0-9]'), '');

    final buffer = StringBuffer();
    for (var i = 0; i < integerPart.length; i++) {
      final remaining = integerPart.length - i;
      buffer.write(integerPart[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
    }
    if (decimalPart != null) {
      buffer.write(',');
      buffer.write(decimalPart);
    }

    final formatted = buffer.toString();
    final newCursor = (formatted.length - cursorFromEnd).clamp(
      0,
      formatted.length,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}

/// Parse un montant saisi via un champ utilisant
/// [ThousandsSeparatorInputFormatter] (espaces + virgule décimale).
double? parseAmountInput(String raw) {
  return double.tryParse(raw.replaceAll(' ', '').replaceAll(',', '.'));
}

/// Formatte un montant (ex: pour pré-remplir un champ en mode édition) avec
/// les mêmes conventions que [ThousandsSeparatorInputFormatter] (espaces des
/// milliers, virgule décimale).
String formatAmountInput(double value, {int decimalDigits = 2}) {
  final fixed = value.toStringAsFixed(decimalDigits);
  final dotIndex = fixed.indexOf('.');
  final integerPart = dotIndex == -1 ? fixed : fixed.substring(0, dotIndex);
  final decimalPart = dotIndex == -1 ? null : fixed.substring(dotIndex + 1);

  final buffer = StringBuffer();
  for (var i = 0; i < integerPart.length; i++) {
    final remaining = integerPart.length - i;
    buffer.write(integerPart[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(' ');
  }
  if (decimalPart != null) {
    buffer.write(',');
    buffer.write(decimalPart);
  }
  return buffer.toString();
}
