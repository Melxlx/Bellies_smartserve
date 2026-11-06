import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../core/app_routes.dart';
import 'notification_repository.dart';

class RiderDashboardRepository {
  final _supabase = Supabase.instance.client;

  Stream<List<OrderModel>> streamRiderDeliveries(String riderId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('rider_id', riderId)
        .order('created_at', ascending: false)
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

  Future<String?> uploadDeliveryProof(String orderId, XFile imageFile) async {
    final name = imageFile.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : '';
    final allowedExts = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'];

    if (ext.isNotEmpty && !allowedExts.contains(ext)) {
      throw StateError('Invalid file format ($ext). Only image files (JPG, PNG, WEBP) are allowed.');
    }

    try {
      final bytes = await imageFile.readAsBytes();
      final path = 'proof_${orderId}_${DateTime.now().millisecondsSinceEpoch}.${ext.isNotEmpty ? ext : "jpg"}';

      await _supabase.storage.from('delivery_proofs').uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );

      final publicUrl = _supabase.storage.from('delivery_proofs').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      debugPrint("Storage upload error, converting to data URL: $e");
      final bytes = await imageFile.readAsBytes();
      final base64Str = base64Encode(bytes);
      return 'data:image/jpeg;base64,$base64Str';
    }
  }

  Future<void> updateDeliveryStatus(
    String orderId,
    String deliveryStatus, {
    String? status,
    String? proofUrl,
    String? notes,
  }) async {
    final Map<String, dynamic> updates = {
      'delivery_status': deliveryStatus,
    };
    if (status != null) updates['status'] = status;
    if (proofUrl != null && proofUrl.isNotEmpty) {
      updates['delivery_proof_url'] = proofUrl;
    }
    if (deliveryStatus == 'delivered') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }
    
    await _supabase.from('orders').update(updates).eq('id', orderId);

    try {
      final orderData = await _supabase
          .from('orders')
          .select('queue_no')
          .eq('id', orderId)
          .maybeSingle();
      final queueNo = (orderData?['queue_no'] ?? '').toString().padLeft(3, '0');

      String title = 'Delivery Status Updated';
      String message = 'Order #$queueNo status changed to $deliveryStatus.';
      if (deliveryStatus == 'outForDelivery') {
        title = 'Order Out for Delivery';
        message = 'Rider picked up Order #$queueNo and is en route!';
      } else if (deliveryStatus == 'delivered') {
        title = 'Order Delivered';
        message = 'Order #$queueNo has been successfully delivered!';
      }

      await NotificationRepository().addNotification(
        title: title,
        message: message,
        category: 'DELIVERY',
        route: AppRoutes.tracking,
        targetRole: 'CUSTOMER,CASHIER,OWNER,RIDER',
      );
    } catch (e) {
      debugPrint("Error creating delivery notification: $e");
    }
  }

  Future<void> toggleOnlineStatus(String riderId, bool isOnline) async {
    await _supabase.from('profiles').update({
      'is_online': isOnline,
    }).eq('id', riderId);
  }

  Future<void> updateRiderLocation(String riderId, double lat, double lng) async {
    await _supabase.from('profiles').update({
      'last_lat': lat,
      'last_lng': lng,
      'last_location_update': DateTime.now().toIso8601String(),
    }).eq('id', riderId);
  }

  Future<UserModel> getRiderProfile(String riderId) async {
    final response = await _supabase.from('profiles').select('*, employee_details(*)').eq('id', riderId).single();
    return UserModel.fromJson(response);
  }
}
