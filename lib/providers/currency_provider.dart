import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/currency_service.dart';

const _currencySymbols = {
  'CAD': '\$ CA',
  'USD': '\$ US',
  'EUR': '€',
  'GBP': '£',
  'CHF': 'CHF',
  'XOF': 'FCFA',
};

String getCurrencySymbol(String currency) => _currencySymbols[currency] ?? currency;

class CurrencyProvider extends ChangeNotifier {
  final CurrencyService _service = CurrencyService();

  String _currency = 'CAD';
  double _rate = 1;
  bool _ready = false;

  String get currency => _currency;
  bool get ready => _ready;
  String get symbol => getCurrencySymbol(_currency);

  /// Appelé quand la devise du profil utilisateur change (ou au chargement)
  Future<void> updateCurrency(String? currency) async {
    if (currency == null) {
      _currency = 'CAD';
      _rate = 1;
      _ready = false;
      notifyListeners();
      return;
    }

    if (currency == _currency && _ready) return;

    _currency = currency;
    _ready = false;
    notifyListeners();

    if (currency == 'CAD') {
      _rate = 1;
    } else {
      try {
        _rate = await _service.convertFromBase(1, currency);
      } catch (_) {
        _rate = 1;
      }
    }

    _ready = true;
    notifyListeners();
  }

  /// Montant saisi dans la devise affichée → CAD à stocker
  double toBase(double amount) => amount / _rate;

  /// CAD stocké → montant dans la devise affichée (pré-remplissage formulaire)
  double fromBase(double amount) => amount * _rate;

  /// Formatte un montant stocké en CAD, converti et affiché dans la devise courante
  String formatCurrency(double amountInBase) {
    final converted = amountInBase * _rate;
    final isCompact = converted.abs() >= 1000000;

    final numberFormat = isCompact
        ? NumberFormat.compact(locale: 'fr_CA')
        : NumberFormat('#,##0.00', 'fr_CA');

    return '${numberFormat.format(converted)} $symbol';
  }
}