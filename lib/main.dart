import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/app_routes.dart';
import 'core/web_url_observer.dart';
import 'services/notification_service.dart';

Future<void> _initializeApp() async {
  try {
    await AppConfig.load();
  } catch (e) {
    debugPrint("AppConfig load error: $e");
  }

  try {
    await Supabase.initialize(
      url: 'https://ijnbdmmnvjbhmjfgdqcw.supabase.co',
      publishableKey: 'sb_publishable_C3A3Da5wQNkIAAzht0EdZA_QDDjkcTb',
    );
  } catch (e) {
    debugPrint("Supabase init error: $e");
  }

  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint("NotificationService init error: $e");
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await _initializeApp();
  runApp(const BelliesSmartServeApp());
}

class BelliesSmartServeApp extends StatelessWidget {
  const BelliesSmartServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Bellie's SmartServe",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      navigatorObservers: [WebUrlNavigatorObserver()],
    );
  }
}
