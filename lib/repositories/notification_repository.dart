import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_routes.dart';
import '../models/system_notification_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class NotificationRepository {
  final SupabaseClient _supabase;

  NotificationRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static final List<SystemNotificationModel> _localNotifications = [];
  static List<SystemNotificationModel> _cachedLatestNotifs = [];
  static final StreamController<List<SystemNotificationModel>> _realtimeController =
      StreamController<List<SystemNotificationModel>>.broadcast();
  static RealtimeChannel? _realtimeChannel;
  static bool _realtimeSubscribed = false;
  static final Set<String> _syncedAlertKeys = {};
  static final Set<String> _dismissedNotificationIds = {};

  void _ensureRealtimeSubscribed() {
    if (_realtimeSubscribed) return;
    _realtimeSubscribed = true;

    try {
      _realtimeChannel = _supabase
          .channel('public:system_notifications:repo')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'system_notifications',
            callback: (payload) async {
              try {
                final latest = await getNotifications();
                _cachedLatestNotifs = latest;
                _notifyListeners();
              } catch (e) {
                debugPrint("Error in realtime notification callback: $e");
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error initializing realtime notification subscription: $e");
    }
  }

  static void dispose() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _realtimeSubscribed = false;
  }

  static void _notifyListeners() {
    if (!_realtimeController.isClosed) {
      _realtimeController.add(List.unmodifiable(_cachedLatestNotifs));
    }
  }

  Stream<List<SystemNotificationModel>> streamNotifications({UserRole? forRole}) {
    late StreamController<List<SystemNotificationModel>> controller;
    StreamSubscription<List<SystemNotificationModel>>? realtimeSub;

    List<SystemNotificationModel> filterForRole(List<SystemNotificationModel> list) {
      final filtered = list.where((n) => !_dismissedNotificationIds.contains(n.id)).toList();
      final currentUserId = _supabase.auth.currentUser?.id;
  
      // Customer notifications filtering:
      if (forRole == UserRole.customer) {
        // 1. Unauthenticated / Guest Customer -> NO notifications displayed
        if (currentUserId == null || currentUserId.isEmpty) {
          return [];
        }
        // 2. Logged-in Customer -> Show ONLY notifications matching this customer's user ID (or general PROMOS/BROADCAST)
        return filtered.where((n) {
          if (!n.isForRole(UserRole.customer)) return false;

          // Strictly block internal staff categories from customer view
          final cat = n.category.toUpperCase();
          if (cat == 'INVENTORY' ||
              cat == 'LOW_STOCK' ||
              cat == 'PREPARATION_TIME' ||
              cat == 'SYSTEM' ||
              cat == 'ATTENDANCE' ||
              cat == 'PAYROLL' ||
              cat == 'FINANCE' ||
              cat == 'ONLINE_ORDERS') {
            return false;
          }
          
          // If the notification has a specific userId, it MUST match the logged-in user
          if (n.userId != null && n.userId!.isNotEmpty) {
            return n.userId == currentUserId;
          }

          // If no userId is specified, only general broadcast categories (PROMOS, BROADCAST) are visible
          return cat == 'PROMOS' || cat == 'BROADCAST';
        }).toList();
      }

      if (forRole == null) return filtered;
      return filtered.where((n) => n.isForRole(forRole)).toList();
    }

    controller = StreamController<List<SystemNotificationModel>>.broadcast(
      onListen: () async {
        _ensureRealtimeSubscribed();

        // 1. Emit current cached/local notifications immediately
        if (_cachedLatestNotifs.isNotEmpty) {
          controller.add(List.unmodifiable(filterForRole(_cachedLatestNotifs)));
        } else if (_localNotifications.isNotEmpty) {
          controller.add(List.unmodifiable(filterForRole(_localNotifications)));
        }

        // 2. Fetch fresh list from Supabase DB and emit
        try {
          final latest = await getNotifications();
          _cachedLatestNotifs = latest;
          if (!controller.isClosed) {
            controller.add(List.unmodifiable(filterForRole(_cachedLatestNotifs)));
          }
        } catch (e) {
          debugPrint("Error fetching DB notifications in streamNotifications: $e");
          if (!controller.isClosed) {
            if (_cachedLatestNotifs.isNotEmpty) {
              controller.add(List.unmodifiable(filterForRole(_cachedLatestNotifs)));
            } else {
              controller.add(List.unmodifiable(filterForRole(_localNotifications)));
            }
          }
        }

        // 3. Keep listening to real-time updates
        realtimeSub = _realtimeController.stream.listen((list) {
          if (!controller.isClosed) {
            controller.add(List.unmodifiable(filterForRole(list)));
          }
        });
      },
      onCancel: () {
        realtimeSub?.cancel();
      },
    );

    return controller.stream;
  }

  Future<List<SystemNotificationModel>> getNotifications() async {
    try {
      final response = await _supabase
          .from('system_notifications')
          .select()
          .order('created_at', ascending: false);

      final List list = response as List;
      final remoteList = list.map((json) => SystemNotificationModel.fromJson(json)).toList();

      final Map<String, SystemNotificationModel> map = {};
      for (var item in remoteList) {
        map[item.id] = item;
      }
      for (var item in _localNotifications) {
        if (!map.containsKey(item.id)) {
          map[item.id] = item;
        }
      }

      final combined = map.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _cachedLatestNotifs = combined;
      return combined;
    } catch (e) {
      debugPrint("Error fetching system notifications: $e");
      return _cachedLatestNotifs.isNotEmpty ? _cachedLatestNotifs : _localNotifications;
    }
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String category,
    String? route,
    String? targetRole,
    String? userId,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'message': message,
      'category': category,
      'route': route,
      if (targetRole != null && targetRole.isNotEmpty) 'target_role': targetRole,
      if (userId != null && userId.isNotEmpty) 'user_id': userId,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final res = await _supabase
          .from('system_notifications')
          .insert(payload)
          .select()
          .single();

      final model = SystemNotificationModel.fromJson(res);
      _localNotifications.insert(0, model);
      _cachedLatestNotifs.insert(0, model);
    } catch (e) {
      debugPrint("Error adding system notification to database: $e");
      final model = SystemNotificationModel(
        id: 'NOTIF-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        message: message,
        category: category,
        route: route,
        targetRole: targetRole,
        userId: userId,
        isRead: false,
        createdAt: DateTime.now(),
      );
      _localNotifications.insert(0, model);
      _cachedLatestNotifs.insert(0, model);

      NotificationService().showNotification(
        title: title,
        message: message,
        payload: route,
      );
    }

    _notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .from('system_notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
    } finally {
      final idx = _cachedLatestNotifs.indexWhere((n) => n.id == id);
      if (idx >= 0) {
        _cachedLatestNotifs[idx] = _cachedLatestNotifs[idx].copyWith(isRead: true);
      }
      final localIdx = _localNotifications.indexWhere((n) => n.id == id);
      if (localIdx >= 0) {
        _localNotifications[localIdx] = _localNotifications[localIdx].copyWith(isRead: true);
      }
      _notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _supabase
          .from('system_notifications')
          .update({'is_read': true})
          .eq('is_read', false);
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
    } finally {
      for (var i = 0; i < _cachedLatestNotifs.length; i++) {
        _cachedLatestNotifs[i] = _cachedLatestNotifs[i].copyWith(isRead: true);
      }
      for (var i = 0; i < _localNotifications.length; i++) {
        _localNotifications[i] = _localNotifications[i].copyWith(isRead: true);
      }
      _notifyListeners();
    }
  }

  Future<void> deleteNotification(String id) async {
    _dismissedNotificationIds.add(id);
    _cachedLatestNotifs.removeWhere((n) => n.id == id);
    _localNotifications.removeWhere((n) => n.id == id);
    _notifyListeners();
  }

  Future<void> clearAllNotifications() async {
    for (var n in _cachedLatestNotifs) {
      _dismissedNotificationIds.add(n.id);
    }
    _cachedLatestNotifs.clear();
    _localNotifications.clear();
    _syncedAlertKeys.clear();
    _notifyListeners();
  }

  Future<void> syncInventoryAndOrderAlerts({
    required List<dynamic> lowStockItems,
    required List<dynamic> pendingOrders,
  }) async {
    for (var item in lowStockItems) {
      final name = (item.name ?? 'Ingredient').toString();
      final num qtyNum = (item.inventoryQuantity ?? item.currentQuantity ?? 0);
      final double qty = qtyNum.toDouble();

      if (qty <= 0) {
        final title = "Ingredient Out of Stock";
        final msg = "$name: This ingredient is out of stock.";
        final key = "${title}_${name}_$qty";

        if (!_syncedAlertKeys.contains(key)) {
          _syncedAlertKeys.add(key);
          await addNotification(
            title: title,
            message: msg,
            category: 'OUT_OF_STOCK',
            route: '/staff/inventory',
            targetRole: 'KITCHEN,OWNER',
          );
        }
      } else {
        final title = "Low Ingredient Stock";
        final msg = "$name: Stock level is running low.";
        final key = "${title}_${name}_$qty";

        if (!_syncedAlertKeys.contains(key)) {
          _syncedAlertKeys.add(key);
          await addNotification(
            title: title,
            message: msg,
            category: 'LOW_STOCK',
            route: '/staff/inventory',
            targetRole: 'KITCHEN,OWNER',
          );
        }
      }
    }

    for (var order in pendingOrders) {
      final queueNo = (order.queueNumber ?? order.queueNo ?? '').toString();
      final title = "New Order Received";
      final msg = "Order #$queueNo: A confirmed order is ready for preparation.";
      final key = "${title}_$queueNo";

      if (!_syncedAlertKeys.contains(key)) {
        _syncedAlertKeys.add(key);
        await addNotification(
          title: title,
          message: msg,
          category: 'ORDERS',
          route: AppRoutes.kitchenQueue,
          targetRole: 'CASHIER,KITCHEN,OWNER',
        );
      }
    }
  }
}
