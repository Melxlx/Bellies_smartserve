import 'package:flutter/material.dart';
import 'user_model.dart';

class SystemNotificationModel {
  final String id;
  final String title;
  final String message;
  final String category;
  final String? route;
  final String? targetRole;
  final String? userId;
  final bool isRead;
  final DateTime createdAt;

  SystemNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.route,
    this.targetRole,
    this.userId,
    this.isRead = false,
    required this.createdAt,
  });

  factory SystemNotificationModel.fromJson(Map<String, dynamic> json) {
    return SystemNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'System Notification',
      message: json['message']?.toString() ?? '',
      category: json['category']?.toString() ?? 'SYSTEM',
      route: json['route']?.toString(),
      targetRole: json['target_role']?.toString(),
      userId: json['user_id']?.toString(),
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'title': title,
      'message': message,
      'category': category,
      if (route != null) 'route': route,
      if (targetRole != null) 'target_role': targetRole,
      if (userId != null) 'user_id': userId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SystemNotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    String? category,
    String? route,
    String? targetRole,
    String? userId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return SystemNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      route: route ?? this.route,
      targetRole: targetRole ?? this.targetRole,
      userId: userId ?? this.userId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool isForRole(UserRole role) {
    // Customer-only notifications (e.g., targetRole == 'CUSTOMER' or category == 'CUSTOMER_ALERTS')
    // should NOT appear in staff/owner notifications!
    if (targetRole != null && targetRole!.isNotEmpty) {
      final upperTarget = targetRole!.toUpperCase();
      if (upperTarget == 'ALL') return true;
      if (upperTarget == 'CUSTOMER' && role != UserRole.customer) {
        return false;
      }
      final roleName = role.name.toUpperCase();
      if (upperTarget.contains(roleName)) return true;
      if (role == UserRole.owner && !upperTarget.contains('CUSTOMER')) return true;
      return false;
    }

    // Role-specific fallback based on notification category when targetRole is null/empty
    final cat = category.toUpperCase();

    // Customer personal alerts should strictly go to Customer only
    if (cat == 'CUSTOMER_ALERTS' || cat == 'PROMOS' || cat == 'MY_ORDERS') {
      return role == UserRole.customer;
    }

    // Owner sees all non-customer operational notifications
    if (role == UserRole.owner) {
      return true;
    }

    // Kitchen strictly sees ONLY the 4 allowed kitchen notification types
    if (role == UserRole.kitchen) {
      return isKitchenNotification;
    }

    switch (role) {
      case UserRole.customer:
        return cat == 'CUSTOMER' || cat == 'CUSTOMER_ALERTS' || cat == 'PROMOS' || cat == 'MY_ORDERS';

      case UserRole.rider:
        return cat == 'DELIVERY' || cat == 'RIDER';

      case UserRole.cashier:
        return cat == 'ORDERS' || cat == 'ONLINE_ORDERS' || cat == 'PAYMENTS' || cat == 'DELIVERY';

      default:
        return false;
    }
  }

  bool get isKitchenNotification {
    final cat = category.toUpperCase();
    final titleUpper = title.toUpperCase();
    final msgUpper = message.toUpperCase();

    final isNewOrder = (cat == 'ORDERS' || cat == 'ONLINE_ORDERS' || cat == 'KITCHEN') &&
        (titleUpper.contains('NEW ORDER') ||
         titleUpper.contains('ORDER RECEIVED') ||
         titleUpper.contains('CONFIRMED ORDER') ||
         msgUpper.contains('MAY CONFIRMED ORDER') ||
         msgUpper.contains('CONFIRMED ORDER'));

    final isPrepAlert = cat == 'PREPARATION_TIME' ||
        titleUpper.contains('PREPARATION TIME') ||
        titleUpper.contains('PREP TIME') ||
        msgUpper.contains('EXCEEDED') ||
        msgUpper.contains('PREPARATION TIME');

    final isLowStock = cat == 'LOW_STOCK' ||
        titleUpper.contains('LOW INGREDIENT STOCK') ||
        titleUpper.contains('LOW STOCK') ||
        msgUpper.contains('RUNNING LOW');

    final isOutOfStock = cat == 'OUT_OF_STOCK' ||
        titleUpper.contains('INGREDIENT OUT OF STOCK') ||
        titleUpper.contains('OUT OF STOCK') ||
        msgUpper.contains('OUT OF STOCK');

    return isNewOrder || isPrepAlert || isLowStock || isOutOfStock;
  }

  String get dateGroupHeader {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(createdAt.year, createdAt.month, createdAt.day);

    if (notificationDate == today) {
      return 'Today';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return 'Earlier';
    }
  }

  String get formattedTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData get icon {
    switch (category.toUpperCase()) {
      case 'ORDERS':
      case 'ONLINE_ORDERS':
        return Icons.shopping_bag_outlined;
      case 'PREPARATION_TIME':
        return Icons.timer_outlined;
      case 'INVENTORY':
      case 'LOW_STOCK':
      case 'OUT_OF_STOCK':
        return Icons.inventory_2_outlined;
      case 'PAYMENTS':
        return Icons.payments_outlined;
      case 'ATTENDANCE':
        return Icons.badge_outlined;
      case 'DELIVERY':
      case 'RIDER':
        return Icons.local_shipping_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  Color get color {
    switch (category.toUpperCase()) {
      case 'ORDERS':
      case 'ONLINE_ORDERS':
        return const Color(0xFFE91E63);
      case 'PREPARATION_TIME':
        return Colors.redAccent;
      case 'INVENTORY':
      case 'LOW_STOCK':
        return Colors.orange;
      case 'OUT_OF_STOCK':
        return Colors.red;
      case 'PAYMENTS':
        return Colors.green;
      case 'ATTENDANCE':
        return Colors.purple;
      case 'DELIVERY':
      case 'RIDER':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
