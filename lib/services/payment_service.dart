import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

class PaymentService {
  String get _paymongoKey => AppConfig.paymongoSecretKey;

  Future<String?> createPaymentLink({
    required double amount,
    required String description,
  }) async {
    if (_paymongoKey.isEmpty || _paymongoKey == 'YOUR_PAYMONGO_SECRET_KEY') {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.paymongo.com/v1/links'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_paymongoKey:'))}',
        },
        body: jsonEncode({
          'data': {
            'attributes': {
              'amount': (amount * 100).toInt(),
              'description': description,
              'remarks': 'SmartServe Order',
            }
          }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['data']['attributes']['checkout_url'];
      } else {
        debugPrint('PayMongo response status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('PayMongo API call failed/skipped: $e');
      return null;
    }
  }
}
