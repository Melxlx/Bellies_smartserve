import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';

class EmployeeRepository {
  final _supabase = Supabase.instance.client;

  Future<List<UserModel>> getAllEmployees() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*, employee_details(*)')
          .order('full_name', ascending: true);

      final list = (response as List).map((json) => UserModel.fromJson(json)).toList();
      return list.where((u) => u.role == UserRole.cashier || u.role == UserRole.kitchen || u.role == UserRole.rider).toList();
    } catch (_) {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('full_name', ascending: true);

      final list = (response as List).map((json) => UserModel.fromJson(json)).toList();
      return list.where((u) => u.role == UserRole.cashier || u.role == UserRole.kitchen || u.role == UserRole.rider).toList();
    }
  }

  /// Fetches all registered customer profiles from profiles table
  Future<List<UserModel>> getAllCustomers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('full_name', ascending: true);

      final list = (response as List).map((json) => UserModel.fromJson(json)).toList();
      return list.where((u) => u.role == UserRole.customer || u.role == UserRole.guest).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetches customer trust data along with completed order count and total spent
  Future<List<Map<String, dynamic>>> getCustomerTrustData() async {
    try {
      final response = await _supabase
          .from('view_customer_order_stats')
          .select()
          .order('completed_orders', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint("Error fetching view_customer_order_stats: $e");
      final customers = await getAllCustomers();
      final stats = await getCustomerOrderStats();

      return customers.map((c) {
        final stat = stats[c.id] ?? {'completed_orders': 0, 'total_spent': 0.0};
        return {
          'user_id': c.id,
          'id': c.id,
          'full_name': c.fullName,
          'email': c.email,
          'is_trusted_customer': c.isTrustedCustomer,
          'owner_notes': c.ownerNotes,
          'completed_orders': stat['completed_orders'],
          'total_spent': stat['total_spent'],
        };
      }).toList();
    }
  }

  Future<Map<String, Map<String, dynamic>>> getCustomerOrderStats() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('created_by, total_amount, status, delivery_status');

      final List list = response as List;
      final Map<String, Map<String, dynamic>> stats = {};

      for (var row in list) {
        final userId = row['created_by']?.toString();
        final status = (row['status'] ?? '').toString().toLowerCase();
        final deliveryStatus = (row['delivery_status'] ?? '').toString().toLowerCase();

        if (userId != null && userId.isNotEmpty && (status == 'completed' || deliveryStatus == 'delivered')) {
          final amount = (row['total_amount'] as num? ?? 0).toDouble();

          if (!stats.containsKey(userId)) {
            stats[userId] = {'completed_orders': 0, 'total_spent': 0.0};
          }

          stats[userId]!['completed_orders'] = (stats[userId]!['completed_orders'] as int) + 1;
          stats[userId]!['total_spent'] = (stats[userId]!['total_spent'] as double) + amount;
        }
      }

      return stats;
    } catch (e) {
      debugPrint("Error fetching customer order stats: $e");
      return {};
    }
  }

  /// Updates customer trust status, account status, and private owner notes
  Future<void> updateCustomerTrustStatus(
    String id, {
    bool? isTrusted,
    String? accountStatus,
    String? ownerNotes,
  }) async {
    final Map<String, dynamic> updates = {};
    if (isTrusted != null) updates['is_trusted_customer'] = isTrusted;
    if (accountStatus != null) updates['account_status'] = accountStatus;
    if (ownerNotes != null) updates['owner_notes'] = ownerNotes;

    if (updates.isNotEmpty) {
      await _supabase.from('profiles').update(updates).eq('id', id);
    }
  }

  /// Creates a confirmed employee account
  Future<void> createEmployee({
    required String email,
    required String password,
    required String fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    required UserRole role,
    required String position,
    required double dailyRate,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-employee',
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'first_name': firstName,
          'middle_name': middleName,
          'last_name': lastName,
          'role': role.name.toUpperCase(),
          'position': position,
          'daily_rate': dailyRate,
        },
      );

      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
      return;
    } catch (_) {}

    final secondaryClient = SupabaseClient(
      'https://ijnbdmmnvjbhmjfgdqcw.supabase.co',
      'sb_publishable_C3A3Da5wQNkIAAzht0EdZA_QDDjkcTb',
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );

    try {
      final cleanEmail = email.trim().toLowerCase();
      final res = await secondaryClient.auth.signUp(
        email: cleanEmail,
        password: password.trim(),
        data: {
          'full_name': fullName.trim(),
          'first_name': firstName?.trim(),
          'middle_name': middleName?.trim(),
          'last_name': lastName?.trim(),
          'role': role.name.toUpperCase(),
          'position': position.trim(),
        },
      );

      final newUserId = res.user?.id;
      if (newUserId != null) {
        await _supabase.from('profiles').upsert({
          'id': newUserId,
          'email': cleanEmail,
          'full_name': fullName.trim(),
          'first_name': firstName?.trim(),
          'middle_name': middleName?.trim(),
          'last_name': lastName?.trim(),
          'position': position.trim(),
          'role': role.name.toUpperCase(),
          'account_status': 'ACTIVE',
        });

        try {
          await _supabase.from('employee_details').upsert({
            'user_id': newUserId,
            'position': position.trim(),
            'daily_rate': dailyRate,
          });
        } catch (_) {}
      }
    } catch (e) {
      throw Exception('Failed to create employee: ${e.toString().replaceAll("Exception: ", "")}');
    } finally {
      secondaryClient.dispose();
    }
  }

  Future<void> updateEmployee(String id, Map<String, dynamic> updates) async {
    final profileUpdates = Map<String, dynamic>.from(updates);
    final rate = profileUpdates['daily_rate'];

    try {
      await _supabase.from('profiles').update(profileUpdates).eq('id', id);
    } catch (e) {
      debugPrint("profiles update error: $e");
      try {
        final cleanUpdates = Map<String, dynamic>.from(profileUpdates)..remove('daily_rate');
        await _supabase.from('profiles').update(cleanUpdates).eq('id', id);
      } catch (_) {}
    }

    if (rate != null) {
      try {
        await _supabase.from('employee_details').upsert({
          'user_id': id,
          'daily_rate': rate,
          if (profileUpdates.containsKey('position')) 'position': profileUpdates['position'],
        });
      } catch (e) {
        debugPrint("employee_details upsert error: $e");
      }
    }
  }

  Future<void> deleteEmployeeProfile(String id) async {
    await _supabase
        .from('profiles')
        .update({'account_status': 'ARCHIVED'})
        .eq('id', id);
  }

  Future<void> restoreEmployeeProfile(String id) async {
    await _supabase
        .from('profiles')
        .update({'account_status': 'ACTIVE'})
        .eq('id', id);
  }

  Future<void> permanentlyDeleteProfile(String id) async {
    try {
      await _supabase.from('employee_details').delete().eq('user_id', id);
    } catch (_) {}
    await _supabase.from('profiles').delete().eq('id', id);
  }
}
