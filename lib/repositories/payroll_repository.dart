import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PayrollRepository {
  final _supabase = Supabase.instance.client;

  /// Calculates today's daily wage payout for staff who scanned attendance today (1 Day × Daily Rate)
  Future<List<Map<String, dynamic>>> getPendingPayroll() async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final endOfToday = startOfToday.add(const Duration(days: 1));

      // 1. Fetch only today's attendance check-ins
      final attendanceRes = await _supabase
          .from('attendance')
          .select('*, profiles(*, employee_details(*))')
          .gte('check_in', startOfToday.toIso8601String())
          .lt('check_in', endOfToday.toIso8601String())
          .order('check_in', ascending: false);

      final attendanceList = List<Map<String, dynamic>>.from(attendanceRes as List);

      // 2. Fetch today's paid payrolls
      List<dynamic> todayPayrolls = [];
      try {
        final paidRes = await _supabase
            .from('payrolls')
            .select('user_id, net_pay, paid_at')
            .gte('paid_at', startOfToday.toIso8601String())
            .lt('paid_at', endOfToday.toIso8601String());
        todayPayrolls = paidRes as List;
      } catch (e) {
        debugPrint("Today payrolls query error: $e");
      }

      final paidUserIds = todayPayrolls.map((p) => p['user_id']?.toString()).toSet();
      final List<Map<String, dynamic>> payrollItems = [];
      final Set<String> processedUserIds = {};

      for (var att in attendanceList) {
        final userId = (att['user_id'] ?? '').toString();
        if (userId.isEmpty || processedUserIds.contains(userId)) continue;
        processedUserIds.add(userId);

        final profile = att['profiles'] as Map<String, dynamic>?;
        if (profile == null) continue;

        // Skip non-staff roles
        final role = (profile['role'] ?? '').toString().toUpperCase();
        if (role == 'CUSTOMER' || role == 'GUEST' || role == 'OWNER') continue;

        final fullName = (profile['full_name'] ?? 'Staff Member').toString();

        Map<String, dynamic>? empDetails;
        if (profile['employee_details'] is List && (profile['employee_details'] as List).isNotEmpty) {
          empDetails = (profile['employee_details'] as List).first as Map<String, dynamic>?;
        } else if (profile['employee_details'] is Map) {
          empDetails = profile['employee_details'] as Map<String, dynamic>?;
        }

        final position = empDetails?['position']?.toString() ?? profile['position']?.toString() ?? 'Staff Member';
        final dailyRate = (empDetails?['daily_rate'] as num? ?? profile['daily_rate'] as num? ?? 500).toDouble();

        final checkInStr = att['check_in']?.toString();
        final checkOutStr = att['check_out']?.toString();
        final localCheckIn = checkInStr != null ? DateTime.parse(checkInStr).toLocal().toIso8601String() : null;
        final localCheckOut = checkOutStr != null ? DateTime.parse(checkOutStr).toLocal().toIso8601String() : null;
        final attStatus = att['status']?.toString() ?? 'PRESENT';

        // Calculate pro-rated earnings based on hours worked (Standard 8-hour shift)
        double calculatedEarnings = dailyRate;
        double hoursWorked = 8.0;

        if (localCheckIn != null) {
          final checkInTime = DateTime.parse(localCheckIn);
          final checkOutTime = localCheckOut != null ? DateTime.parse(localCheckOut) : DateTime.now();

          final duration = checkOutTime.difference(checkInTime);
          hoursWorked = duration.inMinutes / 60.0;
          if (hoursWorked < 0) hoursWorked = 0;

          final hourlyRate = dailyRate / 8.0;
          calculatedEarnings = hoursWorked * hourlyRate;

          // Cap at full daily rate if checked out and worked 8+ hours
          if (localCheckOut != null && calculatedEarnings > dailyRate) {
            calculatedEarnings = dailyRate;
          }
        }

        final isPaidToday = paidUserIds.contains(userId);

        payrollItems.add({
          'user_id': userId,
          'full_name': fullName,
          'position': position,
          'daily_rate': dailyRate,
          'hours_worked': hoursWorked,
          'days_present': hoursWorked >= 4 ? 1 : 0,
          'check_in': localCheckIn,
          'check_out': localCheckOut,
          'attendance_status': attStatus,
          'estimated_earnings': calculatedEarnings,
          'is_paid_today': isPaidToday,
        });
      }

      return payrollItems;
    } catch (e) {
      debugPrint("Error fetching daily payroll: $e");
      return [];
    }
  }

  /// Records today's daily wage payout in 'payrolls' table with fallback protection
  Future<void> processPayment(Map<String, dynamic> data) async {
    final rate = (data['estimated_earnings'] as num? ?? data['daily_rate'] as num? ?? 0).toDouble();
    final hoursWorked = (data['hours_worked'] as num? ?? 8.0).toDouble();
    final dailyRate = (data['daily_rate'] as num? ?? 0).toDouble();
    final userId = data['user_id'];
    final nowStr = DateTime.now().toIso8601String();

    final payload = <String, dynamic>{
      'user_id': userId,
      'days_present': hoursWorked >= 4 ? 1 : 0,
      'daily_rate': dailyRate,
      'gross_pay': rate,
      'net_pay': rate,
      'status': 'PAID',
      'period_start': nowStr,
      'period_end': nowStr,
      'paid_at': nowStr,
    };

    try {
      await _supabase.from('payrolls').insert(payload);
    } catch (e) {
      debugPrint("Primary payroll insert failed ($e), executing schema fallback...");
      await _supabase.from('payrolls').insert({
        'user_id': userId,
        'days_present': hoursWorked >= 4 ? 1 : 0,
        'gross_pay': rate,
        'net_pay': rate,
        'status': 'PAID',
        'period_start': nowStr,
        'period_end': nowStr,
        'paid_at': nowStr,
      });
    }
  }

  /// Fetches historical payroll payout records for a specific calendar date
  Future<List<Map<String, dynamic>>> getPayrollHistory(DateTime date) async {
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final response = await _supabase
          .from('payrolls')
          .select('*, profiles(full_name, position)')
          .gte('paid_at', start.toIso8601String())
          .lt('paid_at', end.toIso8601String())
          .order('paid_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint("Error fetching payroll history: $e");
      return [];
    }
  }
}
