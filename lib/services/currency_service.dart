import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const _cacheDurationMs = 24 * 60 * 60 * 1000; // 24h
  static const _baseCurrency = 'CAD';

  final _db = FirebaseFirestore.instance;

  Future<Map<String, double>> _getRatesFromFirestore() async {
    final ref = _db.collection('system').doc('exchangeRates');
    final snap = await ref.get();

    if (snap.exists) {
      final data = snap.data()!;
      final updatedAt = data['updatedAt'] as int;
      final isExpired =
          DateTime.now().millisecondsSinceEpoch - updatedAt > _cacheDurationMs;
      if (!isExpired) {
        return _parseRates(data['rates']);
      }
    }

    // Taux absents ou expirés — on rafraîchit depuis l'API
    try {
      final response = await http.get(
        Uri.parse('https://open.er-api.com/v6/latest/$_baseCurrency'),
      );
      final apiData = jsonDecode(response.body) as Map<String, dynamic>;

      if (apiData['result'] != 'success') {
        if (snap.exists) return _parseRates(snap.data()!['rates']);
        throw Exception('Impossible de récupérer les taux de change');
      }

      final rates = _parseRates(apiData['rates']);

      await ref.set({
        'rates': rates,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      return rates;
    } catch (e) {
      // Si l'API échoue mais qu'on a un cache périmé, on le garde plutôt que de planter
      if (snap.exists) return _parseRates(snap.data()!['rates']);
      rethrow;
    }
  }

  Map<String, double> _parseRates(dynamic raw) {
    return Map<String, double>.from(
      (raw as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    );
  }

  Future<double> convertFromBase(double amount, String to) async {
    if (to == _baseCurrency) return amount;
    final rates = await _getRatesFromFirestore();
    final rate = rates[to];
    if (rate == null) return amount; // fallback silencieux, comme le web
    return amount * rate;
  }
}