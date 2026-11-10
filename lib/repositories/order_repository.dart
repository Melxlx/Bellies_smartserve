import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../core/app_routes.dart';
import 'recipe_repository.dart';
import 'notification_repository.dart';

class OrderRepository {
  OrderRepository({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static String databaseServiceType(ServiceType serviceType) {
    switch (serviceType) {
      case ServiceType.dineIn:
        return 'DINE_IN';
      case ServiceType.takeout:
        return 'TAKEOUT';
      case ServiceType.delivery:
        return 'DELIVERY';
    }
  }

  static String normalizeOrderPaymentStatus(String? value, {PaymentMethod? paymentMethod}) {
    final normalized = (value ?? '').trim().toUpperCase();
    if (normalized == 'PAID' || normalized == 'UNPAID' || normalized == 'PENDING') {
      return normalized;
    }
    if (paymentMethod == PaymentMethod.cash) {
      return 'PAID';
    }
    return 'PENDING';
  }

  Future<int> _getNextDailyQueueNumber() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day).toIso8601String();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999).toIso8601String();

      final response = await _supabase
          .from('orders')
          .select('queue_no')
          .gte('created_at', startOfToday)
          .lte('created_at', endOfToday)
          .order('queue_no', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['queue_no'] != null) {
        final lastQueueNo = (response['queue_no'] as num).toInt();
        return lastQueueNo + 1;
      }
    } catch (e) {
      debugPrint("Warning: Error fetching daily queue number ($e). Defaulting to 1.");
    }
    return 1;
  }

  /// The database transaction saves the address snapshot, items and payment
  /// together. Never fall back to an unauthenticated or partial delivery write.
  Future<OrderModel> createCustomerDeliveryOrder(OrderModel order) async {
    if (order.serviceType != ServiceType.delivery ||
        order.customerDetails?.hasRequiredDeliveryDetails != true) {
      throw StateError('Confirm the delivery location and recipient details first.');
    }
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthException('Please sign in or register to complete your checkout.');
    }
    final response = await _supabase.rpc(
      'create_customer_delivery_order',
      params: {
        'p_order': {
          'tracking_number': order.trackingNumber,
          'payment_method': order.paymentMethod?.name ?? 'gcash',
          'payment_status': normalizeOrderPaymentStatus(
            order.paymentStatus,
            paymentMethod: order.paymentMethod,
          ),
          'subtotal': order.subtotal,
          'delivery_fee': order.deliveryFee,
          'delivery_distance_km': order.deliveryDistanceKm ?? order.customerDetails?.deliveryDistanceKm ?? 0.0,
          'total_amount': order.totalAmount,
          'reference_number': order.referenceNumber,
          'customer_details': order.customerDetails!.toJson(),
          'created_by': _supabase.auth.currentUser?.id,
        },
        'p_items': order.items.map((item) => {
          'product_id': item.product.id,
          'product_name_snapshot': item.product.name,
          'quantity': item.quantity,
          'unit_price': item.product.sellingPrice,
          'unit_cost': item.product.estimatedCost,
          'item_instructions': item.instructions,
          'line_total': item.total,
        }).toList(),
      },
    );
    final row = Map<String, dynamic>.from(response as Map);
    final savedOrder = order.copyWith(
      id: row['id'] as String,
      queueNumber: (row['queue_no'] ?? row['queue_number'])
          .toString()
          .padLeft(3, '0'),
      status: row['status'] as String?,
      paymentStatus: row['payment_status'] as String?,
    );

    // Deduct ingredients for customer order
    await RecipeRepository().deductIngredientsForOrder(savedOrder.id);

    NotificationRepository().addNotification(
      title: 'New Order Received',
      message: 'Order #${savedOrder.queueNumber}: A confirmed order is ready for preparation.',
      category: 'ONLINE_ORDERS',
      route: AppRoutes.kitchenQueue,
      targetRole: 'CASHIER,KITCHEN,OWNER',
    );

    return savedOrder;
  }

  Future<OrderModel> createOrder(OrderModel order) async {
    final normalizedPaymentStatus = normalizeOrderPaymentStatus(
      order.paymentStatus,
      paymentMethod: order.paymentMethod,
    );
    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      throw StateError('Please sign in before processing a payment.');
    }
    final profile = await _supabase
        .from('profiles')
        .select('id, full_name, role, position')
        .eq('id', authUser.id)
        .maybeSingle();
    final processedBy = profile?['id'] as String?;
    if (processedBy == null) {
      throw StateError('Your account has no employee profile for payment processing.');
    }

    String? cashierName = order.cashierName;
    if (cashierName == null || cashierName.isEmpty) {
      if (profile?['full_name'] != null) {
        final name = profile!['full_name'].toString();
        final role = profile['role']?.toString().toUpperCase() ?? '';
        final pos = profile['position']?.toString() ?? '';
        if (role == 'OWNER' || pos.toLowerCase().contains('owner')) {
          cashierName = "$name (Owner)";
        } else {
          cashierName = name;
        }
      }
    }

    int nextQueueNo = int.tryParse(order.queueNumber) ?? 0;
    if (nextQueueNo <= 0) {
      nextQueueNo = await _getNextDailyQueueNumber();
    }

    // 1. Insert Order
    final orderResponse = await _supabase.from('orders').insert({
      'service_type': databaseServiceType(order.serviceType),
      'queue_no': nextQueueNo,
      'status': 'received',
      'payment_method': order.paymentMethod?.name ?? 'cash',
      'payment_status': normalizedPaymentStatus,
      'subtotal': order.subtotal,
      'delivery_fee': order.deliveryFee,
      'delivery_distance_km': order.deliveryDistanceKm ?? 0.0,
      'total_amount': order.totalAmount,
      'tracking_number': order.trackingNumber,
      'customer_details': order.customerDetails?.toJson(),
      'reference_number': order.referenceNumber,
      'created_by': _supabase.auth.currentUser?.id,
    }).select().single();

    final orderId = orderResponse['id'];
    final queueNumber = (orderResponse['queue_no'] ?? orderResponse['queue_number'])
        .toString()
        .padLeft(3, '0');

    // 2. Insert Order Items
    final List<Map<String, dynamic>> itemsPayload = order.items.map((item) => {
      'order_id': orderId,
      'product_id': item.product.id,
      'product_name_snapshot': item.product.name,
      'quantity': item.quantity,
      'unit_price': item.product.sellingPrice,
      'unit_cost': item.product.estimatedCost,
      'item_instructions': item.instructions,
      'line_total': item.total,
    }).toList();

    await _supabase.from('order_items').insert(itemsPayload);

    // 3. Insert Payment record (Initial state)
    // Cash is paid immediately; GCash stays unpaid until verification.
    final paymentStatus = (order.paymentMethod == PaymentMethod.cash) ? 'PAID' : 'UNPAID';
    final paymentMethodStr = (order.paymentMethod ?? PaymentMethod.cash).name.toUpperCase();

    try {
      await _supabase.from('payments').insert({
        'payment_no': 'PAY-${DateTime.now().microsecondsSinceEpoch}',
        'order_id': orderId,
        'payment_method': paymentMethodStr,
        'amount_due': order.totalAmount,
        'payment_status': paymentStatus,
        'amount_tendered': order.amountTendered ?? order.totalAmount,
        'change_amount': order.change ?? 0.0,
        'processed_by': processedBy,
        'gcash_reference_no': order.referenceNumber,
        'paid_at': paymentStatus == 'PAID' ? DateTime.now().toIso8601String() : null,
      });
    } catch (e) {
      debugPrint("Warning: Initial payment insert failed ($e). Retrying with lowercase values...");
      try {
        await _supabase.from('payments').insert({
          'payment_no': 'PAY-${DateTime.now().microsecondsSinceEpoch}',
          'order_id': orderId,
          'payment_method': paymentMethodStr.toLowerCase(),
          'amount_due': order.totalAmount,
          'payment_status': paymentStatus.toLowerCase(),
          'amount_tendered': order.amountTendered ?? order.totalAmount,
          'change_amount': order.change ?? 0.0,
          'processed_by': processedBy,
          'gcash_reference_no': order.referenceNumber,
          'paid_at': paymentStatus == 'PAID' ? DateTime.now().toIso8601String() : null,
        });
      } catch (retryError) {
        debugPrint("Warning: Could not create payment record due to database check constraint: $retryError");
      }
    }

    // Auto deduct ingredients for order upon creation/receive
    try {
      await RecipeRepository().deductIngredientsForOrder(orderId);
    } catch (e) {
      debugPrint("Warning: Automated inventory deduction skipped due to DB schema: $e");
    }

    if (paymentStatus == 'PAID') {
      NotificationRepository().addNotification(
        title: 'New Order Received',
        message: 'Order #$queueNumber: A confirmed order is ready for preparation.',
        category: 'ORDERS',
        route: AppRoutes.kitchenQueue,
        targetRole: 'CASHIER,KITCHEN,OWNER',
      );
    }

    // Return the updated model with real ID and Queue Number
    return order.copyWith(
      id: orderId,
      queueNumber: queueNumber,
      cashierName: cashierName,
    );
  }

  Stream<List<OrderModel>> getKitchenOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .neq('status', 'completed')
        .neq('status', 'cancelled')
        .eq('payment_status', 'PAID')
        .order('created_at', ascending: true)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            final itemsResponse = await _supabase
                .from('order_items')
                .select('*, products(*)')
                .eq('order_id', row['id']);
            
            row['order_items'] = itemsResponse;
            orders.add(OrderModel.fromJson(row));
          }
          return orders;
        });
  }

  Stream<List<OrderModel>> getReadyOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'ready')
        .eq('payment_status', 'PAID')
        .order('created_at', ascending: true)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            final itemsResponse = await _supabase
                .from('order_items')
                .select('*, products(*)')
                .eq('order_id', row['id']);
            
            row['order_items'] = itemsResponse;
            orders.add(OrderModel.fromJson(row));
          }
          return orders;
        });
  }

  Stream<List<OrderModel>> getCompletedOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            final status = (row['status'] ?? '').toString().toLowerCase();
            if (status == 'completed' ||
                status == 'served' ||
                status == 'delivered' ||
                status == 'cancelled') {
              try {
                final itemsResponse = await _supabase
                    .from('order_items')
                    .select('*, products(*)')
                    .eq('order_id', row['id']);
                row['order_items'] = itemsResponse;
              } catch (_) {
                row['order_items'] = [];
              }

              if (row['created_by'] != null) {
                try {
                  final creatorProfile = await _supabase
                      .from('profiles')
                      .select('full_name, role, position')
                      .eq('id', row['created_by'])
                      .maybeSingle();
                  if (creatorProfile != null) {
                    row['created_by_profile'] = creatorProfile;
                  }
                } catch (_) {}
              }

              orders.add(OrderModel.fromJson(row));
            }
          }
          return orders;
        });
  }

  Stream<List<OrderModel>> getPendingOnlineOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            final serviceType = (row['service_type'] ?? row['order_type'] ?? '').toString().toUpperCase();
            final paymentStatus = (row['payment_status'] ?? '').toString().toUpperCase();
            final status = (row['status'] ?? '').toString().toLowerCase();

            if (serviceType == 'DELIVERY' &&
                (paymentStatus == 'PENDING' || paymentStatus == 'UNPAID') &&
                status != 'cancelled' &&
                status != 'completed') {
              try {
                final itemsResponse = await _supabase
                    .from('order_items')
                    .select('*, products(*)')
                    .eq('order_id', row['id']);
                row['order_items'] = itemsResponse;
              } catch (_) {
                row['order_items'] = [];
              }
              orders.add(OrderModel.fromJson(row));
            }
          }
          return orders;
        });
  }

  Stream<List<OrderModel>> getActiveDeliveriesStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('service_type', 'DELIVERY')
        .neq('status', 'completed')
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            final itemsResponse = await _supabase
                .from('order_items')
                .select('*, products(*)')
                .eq('order_id', row['id']);
            
            row['order_items'] = itemsResponse;
            
            // Also fetch rider info if available
            if (row['rider_id'] != null) {
              final riderResponse = await _supabase
                  .from('profiles')
                  .select('full_name')
                  .eq('id', row['rider_id'])
                  .maybeSingle();
              row['profiles'] = riderResponse;
            }
            
            orders.add(OrderModel.fromJson(row));
          }
          return orders;
        });
  }

  Stream<List<OrderModel>> getAllDeliveryOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('service_type', 'DELIVERY')
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            try {
              final itemsResponse = await _supabase
                  .from('order_items')
                  .select('*, products(*)')
                  .eq('order_id', row['id']);
              row['order_items'] = itemsResponse;
            } catch (_) {
              row['order_items'] = [];
            }
            
            if (row['rider_id'] != null) {
              try {
                final riderResponse = await _supabase
                    .from('profiles')
                    .select('full_name')
                    .eq('id', row['rider_id'])
                    .maybeSingle();
                row['profiles'] = riderResponse;
              } catch (_) {}
            }
            
            orders.add(OrderModel.fromJson(row));
          }
          return orders;
        });
  }

  Future<void> confirmPayment(String orderId) async {
    final row = await _supabase.from('orders').update({
      'payment_status': 'PAID',
      'status': 'preparing'
    }).eq('id', orderId).select('id, queue_no, created_by').single();

    final queueNo = (row['queue_no'] ?? row['queue_number'] ?? (orderId.length >= 8 ? orderId.substring(0, 8) : orderId)).toString().padLeft(3, '0');
    final createdBy = row['created_by']?.toString();
    
    try {
      await _supabase.from('payments').update({
        'payment_status': 'PAID',
        'paid_at': DateTime.now().toIso8601String()
      }).eq('order_id', orderId);
    } catch (_) {}

    try {
      // Auto deduct ingredients when payment is confirmed and status becomes preparing
      await RecipeRepository().deductIngredientsForOrder(orderId);
    } catch (_) {}

    try {
      await NotificationRepository().addNotification(
        title: 'Payment Verified! 🍜',
        message: 'Order #$queueNo: Your GCash payment is verified! The kitchen is now cooking your order.',
        category: 'ORDERS',
        route: AppRoutes.tracking,
        targetRole: 'CUSTOMER,CASHIER,KITCHEN,OWNER',
        userId: createdBy,
      );
    } catch (_) {}
  }

  Future<void> rejectPayment(String orderId, {String? reason}) async {
    String? createdBy;
    try {
      final res = await _supabase.from('orders').update({
        'payment_status': 'REJECTED',
        'status': 'cancelled',
      }).eq('id', orderId).select('id, created_by').maybeSingle();
      if (res != null) {
        createdBy = res['created_by']?.toString();
      }
      debugPrint("✅ Payment rejected successfully for order: $orderId");
    } catch (e) {
      debugPrint("❌ Error rejecting payment in Supabase: $e");
      rethrow;
    }

    try {
      await NotificationRepository().addNotification(
        title: 'Payment Unverified / Rejected ❌',
        message: 'Order Payment Rejected: ${reason ?? "Invalid GCash Reference Number"}. Please re-check your payment.',
        category: 'CUSTOMER_ALERTS',
        route: AppRoutes.customerMenu,
        targetRole: 'CUSTOMER',
        userId: createdBy,
      );
    } catch (_) {}
  }

  Stream<List<OrderModel>> getAllOnlineOrdersStream() {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final List<OrderModel> orders = [];
          for (var row in data) {
            final serviceType = (row['service_type'] ?? row['order_type'] ?? '').toString().toUpperCase();
            if (serviceType == 'DELIVERY') {
              try {
                final itemsResponse = await _supabase
                    .from('order_items')
                    .select('*, products(*)')
                    .eq('order_id', row['id']);
                row['order_items'] = itemsResponse;
              } catch (_) {
                row['order_items'] = [];
              }
              orders.add(OrderModel.fromJson(row));
            }
          }
          return orders;
        });
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final res = await _supabase
        .from('orders')
        .update({'status': status})
        .eq('id', orderId)
        .select('id, queue_no, created_by')
        .maybeSingle();

    final queueNo = res != null ? (res['queue_no'] ?? '').toString().padLeft(3, '0') : '';
    final customerUserId = res?['created_by']?.toString();

    if (status.toLowerCase() == 'received' ||
        status.toLowerCase() == 'preparing' ||
        status.toLowerCase() == 'ready' ||
        status.toLowerCase() == 'completed' ||
        status.toLowerCase() == 'served') {
      try {
        await RecipeRepository().deductIngredientsForOrder(orderId);
      } catch (e) {
        debugPrint("Error auto-deducting ingredients on status update ($status): $e");
      }
    }

    if (customerUserId != null && customerUserId.isNotEmpty) {
      try {
        String title = 'Order Status Updated';
        String message = 'Order #$queueNo status is now ${status.toUpperCase()}.';
        final statusLower = status.toLowerCase();
        if (statusLower == 'preparing') {
          title = 'Kitchen is Preparing your Order! 🍳';
          message = 'Order #$queueNo is now being prepared in the kitchen.';
        } else if (statusLower == 'ready') {
          title = 'Order Ready! 🍽️';
          message = 'Order #$queueNo is ready!';
        } else if (statusLower == 'completed' || statusLower == 'served') {
          title = 'Order Completed! ✅';
          message = 'Order #$queueNo has been completed. Thank you!';
        }

        await NotificationRepository().addNotification(
          title: title,
          message: message,
          category: 'MY_ORDERS',
          route: AppRoutes.tracking,
          targetRole: 'CUSTOMER',
          userId: customerUserId,
        );
      } catch (e) {
        debugPrint("Error sending customer status notification: $e");
      }
    }
  }
}
