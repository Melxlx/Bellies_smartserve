import 'dart:convert';

import 'package:flutter/services.dart';

/// Client configuration is bundled with the app and is not a secret store.
/// Keep the local source file out of version control; restrict API use in the
/// Geoapify dashboard for the deployed application.
class AppConfig {
  AppConfig._();

  static String _paymongoSecretKey = '';
  static String get paymongoSecretKey => _paymongoSecretKey;

  static Future<void> load({AssetBundle? bundle}) async {
    try {
      final values = jsonDecode(
        await (bundle ?? rootBundle).loadString('config/local.json'),
      ) as Map<String, dynamic>;
      _paymongoSecretKey = (values['PAYMONGO_SECRET_KEY'] as String? ?? '').trim();
    } catch (_) {
      _paymongoSecretKey = '';
    }
  }
}
