import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/inventory_repository.dart';
import '../../widgets/state_widgets.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final _inventoryRepo = InventoryRepository();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final movements = await _inventoryRepo.getMovementHistory();

      // Fetch completed orders
      final ordersResponse = await _supabase
          .from('orders')
          .select()
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(20);

      // Fetch attendance
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, profiles(full_name)')
          .order('check_in', ascending: false)
          .limit(20);

      final List<Map<String, dynamic>> combined = [];

      for (var m in movements) {
        combined.add({
          'title': 'Stock Update',
          'desc': '${m.productCode} - ${m.productName}: ${m.reason}',
          'time': m.createdAt,
          'icon': Icons.inventory,
          'color': Colors.blue,
        });
      }

      for (var o in ordersResponse as List) {
        combined.add({
          'title': 'Order Completed',
          'desc':
              'Order #${o['id'].toString().substring(0, 8)} served (${o['service_type'] ?? o['order_type']})',
          'time': DateTime.parse(o['completed_at'] ?? o['created_at']),
          'icon': Icons.check_circle,
          'color': Colors.green,
        });
      }

      for (var a in attendanceResponse as List) {
        combined.add({
          'title':
              'Attendance: ${a['check_out'] == null ? "Time-In" : "Time-Out"}',
          'desc': '${a['profiles']['full_name']}',
          'time': DateTime.parse(a['check_out'] ?? a['check_in']),
          'icon': Icons.badge,
          'color': Colors.purple,
        });
      }

      combined.sort(
        (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
      );

      setState(() {
        _logs = combined;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: LoadingState());

    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: const Text("System Activity Logs"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _logs.isEmpty
          ? const EmptyState(message: "No activity recorded yet.")
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final log = _logs[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (log['color'] as Color).withAlpha(
                      (0.1 * 255).toInt(),
                    ),
                    child: Icon(
                      log['icon'] as IconData,
                      color: log['color'] as Color,
                    ),
                  ),
                  title: Text(
                    log['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(log['desc'] as String),
                  trailing: Text(
                    DateFormat('hh:mm a').format(log['time'] as DateTime),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              },
            ),
    );
  }
}
