import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final _supabase = Supabase.instance.client;

  Future<List<AttendanceModel>> getDailyAttendance(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day).toIso8601String();
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final response = await _supabase
        .from('attendance')
        .select('*, profiles(full_name, position, avatar_url, employee_details(daily_rate))')
        .gte('check_in', start)
        .lte('check_in', end)
        .order('check_in', ascending: false);

    return (response as List).map((json) {
      final profiles = json['profiles'] as Map<String, dynamic>?;
      final fullName = profiles?['full_name'] ?? 'Staff';
      final position = profiles?['position'] ?? 'Staff';
      final avatarUrl = profiles?['avatar_url']?.toString();

      double dailyRate = 500.0;
      final empDetails = profiles?['employee_details'];
      if (empDetails is List && empDetails.isNotEmpty) {
        dailyRate = (empDetails[0]['daily_rate'] as num? ?? 500.0).toDouble();
      } else if (empDetails is Map) {
        dailyRate = (empDetails['daily_rate'] as num? ?? 500.0).toDouble();
      }

      return AttendanceModel(
        userId: json['user_id'],
        employeeName: fullName,
        position: position,
        avatarUrl: avatarUrl,
        checkIn: DateTime.parse(json['check_in']).toLocal(),
        checkOut: json['check_out'] != null ? DateTime.parse(json['check_out']).toLocal() : null,
        status: AttendanceStatus.values.firstWhere(
          (e) => e.name.toUpperCase() == (json['status'] as String).toUpperCase(),
          orElse: () => AttendanceStatus.present,
        ),
        dailyRate: dailyRate,
      );
    }).toList();
  }

  Future<void> recordTap(String userId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).toIso8601String();
    final end = DateTime(today.year, today.month, today.day, 23, 59, 59).toIso8601String();

    // Check if already timed in
    final existing = await _supabase
        .from('attendance')
        .select()
        .eq('user_id', userId)
        .gte('check_in', start)
        .lte('check_in', end)
        .maybeSingle();

    if (existing == null) {
      // Time-In
      final status = today.hour >= 9 ? 'LATE' : 'PRESENT';
      await _supabase.from('attendance').insert({
        'user_id': userId,
        'check_in': today.toIso8601String(),
        'status': status,
      });
    } else if (existing['check_out'] == null) {
      // Time-Out
      await _supabase.from('attendance').update({
        'check_out': today.toIso8601String(),
      }).eq('id', existing['id']);
    } else {
      throw Exception("Already Timed-Out for today.");
    }
  }
}
