import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/system_notification_model.dart';
import '../models/user_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  RealtimeChannel? _realtimeChannel;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint("Notification tapped with payload: ${details.payload}");
      },
    );

    // Request Android 13+ permission
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      
      // Create high importance notification channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'bellies_smartserve_channel',
        'Bellies SmartServe Alerts',
        description: 'Notifications for orders, deliveries, and system alerts',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation.createNotificationChannel(channel);
    }

    _initialized = true;
    initRealtimeListener();
  }

  Future<void> showNotification({
    required String title,
    required String message,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'bellies_smartserve_channel',
      'Bellies SmartServe Alerts',
      channelDescription: 'Notifications for orders, deliveries, and system alerts',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _notificationsPlugin.show(id, title, message, platformDetails, payload: payload);
  }

  void initRealtimeListener() {
    try {
      final client = Supabase.instance.client;
      
      _realtimeChannel?.unsubscribe();
      _realtimeChannel = client
          .channel('public:system_notifications')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'system_notifications',
            callback: (payload) async {
              final newRecord = payload.newRecord;
              final notif = SystemNotificationModel.fromJson(newRecord);

              UserRole currentUserRole = UserRole.owner;
              final user = client.auth.currentUser;
              if (user != null) {
                try {
                  final profile = await client
                      .from('profiles')
                      .select('role')
                      .eq('id', user.id)
                      .maybeSingle();
                  if (profile != null && profile['role'] != null) {
                    final roleStr = profile['role'].toString().toLowerCase();
                    currentUserRole = UserRole.values.firstWhere(
                      (r) => r.name.toLowerCase() == roleStr,
                      orElse: () => UserRole.owner,
                    );
                  }
                } catch (_) {}
              }

              if (notif.isForRole(currentUserRole)) {
                showNotification(
                  title: notif.title,
                  message: notif.message,
                  payload: notif.route,
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error starting realtime notification listener: $e");
    }
  }

  void dispose() {
    _realtimeChannel?.unsubscribe();
  }
}
