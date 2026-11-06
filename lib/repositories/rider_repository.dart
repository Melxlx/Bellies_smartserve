import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../core/app_routes.dart';
import 'notification_repository.dart';

class RiderRepository {
  final _supabase = Supabase.instance.client;

  Future<List<UserModel>> getAvailableRiders() async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('role', 'RIDER')
        .eq('account_status', 'ACTIVE')
        .eq('is_online', true)
        .order('full_name');
    
    return (response as List).map((json) => UserModel.fromJson(json)).toList();
  }

  Future<void> assignRider(String orderId, String riderId) async {
    final response = await _supabase
        .from('orders')
        .update({
          'rider_id': riderId,
          'delivery_status': 'readyForDelivery',
        })
        .eq('id', orderId)
        .select('id, queue_no, rider_id, delivery_status')
        .maybeSingle();

    if (response == null || response['rider_id']?.toString() != riderId) {
      throw StateError(
        'The order was not updated. Please check staff permissions for assigning riders.',
      );
    }

    final queueNo = (response['queue_no'] ?? '').toString().padLeft(3, '0');
    await NotificationRepository().addNotification(
      title: 'New Delivery Assigned',
      message: 'Order #$queueNo has been assigned for delivery pickup!',
      category: 'DELIVERY',
      route: AppRoutes.riderDashboard,
      targetRole: 'RIDER,CASHIER,OWNER',
    );
  }
}
