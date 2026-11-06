import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

class TrackingRepository {
  final _supabase = Supabase.instance.client;

  // 1. Hanapin ang order gamit ang tracking number
  Future<OrderModel?> getOrderByTracking(String trackingNumber) async {
    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('tracking_number', trackingNumber.trim().toUpperCase())
          .maybeSingle();

      if (response == null) return null;
      return OrderModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // 2. Real-time subscription para sa status updates
  Stream<OrderModel?> trackOrderLive(String orderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .asyncMap((data) async {
          if (data.isEmpty) return null;
          
          final fullOrder = await _supabase
              .from('orders')
              .select('*, order_items(*, products(*)), profiles!rider_id(full_name, last_lat, last_lng)')
              .eq('id', data.first['id'])
              .maybeSingle();
              
          if (fullOrder == null) return null;
          return OrderModel.fromJson(fullOrder);
        });
  }

  // 3. Stream specifically for the rider's latest coordinates
  Stream<Map<String, double>?> streamRiderLocation(String riderId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', riderId)
        .map((data) {
          if (data.isEmpty) return null;
          final row = data.first;
          if (row['last_lat'] == null || row['last_lng'] == null) return null;
          return {
            'lat': (row['last_lat'] as num).toDouble(),
            'lng': (row['last_lng'] as num).toDouble(),
          };
        });
  }

  // 4. Hanapin ang lahat ng orders ng kasalukuyang naka-log in na customer
  Future<List<OrderModel>> getCustomerOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final List<OrderModel> orders = [];
      final Set<String> orderIds = {};

      // Search by created_by == user.id
      final resByUserId = await _supabase
          .from('orders')
          .select('*, order_items(*, products(*))')
          .eq('created_by', user.id)
          .order('created_at', ascending: false);

      for (var json in (resByUserId as List)) {
        final model = OrderModel.fromJson(json);
        if (orderIds.add(model.id)) {
          orders.add(model);
        }
      }

      // Search by email in customer_details if email is available
      final userEmail = user.email;
      if (userEmail != null && userEmail.isNotEmpty) {
        final resByEmail = await _supabase
            .from('orders')
            .select('*, order_items(*, products(*))')
            .filter('customer_details->>email', 'eq', userEmail)
            .order('created_at', ascending: false);

        for (var json in (resByEmail as List)) {
          final model = OrderModel.fromJson(json);
          if (orderIds.add(model.id)) {
            orders.add(model);
          }
        }
      }

      orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return orders;
    } catch (e) {
      return [];
    }
  }
}
