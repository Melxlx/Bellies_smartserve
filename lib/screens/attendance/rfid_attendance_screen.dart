import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/responsive_layout.dart';
import '../../models/attendance_model.dart';
import '../../repositories/attendance_repository.dart';
import '../../widgets/state_widgets.dart';

class RFIDAttendanceScreen extends StatefulWidget {
  const RFIDAttendanceScreen({super.key});

  @override
  State<RFIDAttendanceScreen> createState() => _RFIDAttendanceScreenState();
}

class _RFIDAttendanceScreenState extends State<RFIDAttendanceScreen> {
  final _attendanceRepo = AttendanceRepository();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _employees = [];
  List<AttendanceModel> _attendanceList = [];
  bool _isLoading = true;

  StreamSubscription? _attendanceStreamSub;
  StreamSubscription? _recentScansStreamSub;

  @override
  void initState() {
    super.initState();
    _loadData(showLoading: true);
    _subscribeToAttendance();
  }

  void _subscribeToAttendance() {
    _attendanceStreamSub = _supabase
        .from('attendance')
        .stream(primaryKey: ['id'])
        .listen((_) {
          if (mounted) {
            _loadData(showLoading: false);
          }
        });

    _recentScansStreamSub = _supabase
        .from('recent_scans')
        .stream(primaryKey: ['id'])
        .listen((_) {
          if (mounted) {
            _loadData(showLoading: false);
          }
        });
  }

  @override
  void dispose() {
    _attendanceStreamSub?.cancel();
    _recentScansStreamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      // Fetch profiles with employee_details join (excluding owner/admin)
      final profilesResponse = await _supabase
          .from('profiles')
          .select('*, employee_details(rfid_uid, position)')
          .inFilter('role', ['CASHIER', 'KITCHEN', 'RIDER', 'STAFF']);
      
      final employees = List<Map<String, dynamic>>.from(profilesResponse);
      final employeeIds = employees.map((employee) => employee['id']).toSet();
      
      final attendance = (await _attendanceRepo.getDailyAttendance(
        DateTime.now(),
      )).where((record) => employeeIds.contains(record.userId)).toList();

      if (mounted) {
        setState(() {
          _employees = employees;
          _attendanceList = attendance;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading attendance data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignRfid(Map<String, dynamic> employee, {String? existingUid}) async {
    final hasExisting = existingUid != null && existingUid.isNotEmpty;
    final controller = TextEditingController(text: existingUid ?? '');
    bool isListening = true;
    StreamSubscription? scanSubscription;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final dialogOpenTime = DateTime.now();

    // 1. I-set ang mode sa Supabase papuntang REGISTER sa background
    _supabase.from('system_settings').upsert({'key': 'rfid_mode', 'value': 'REGISTER'}).catchError((_) {});

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          scanSubscription ??= _supabase
              .from('recent_scans')
              .stream(primaryKey: ['id'])
              .order('scanned_at', ascending: false)
              .limit(1)
              .listen((data) {
                if (data.isNotEmpty && isListening) {
                  final scan = data.first;
                  final scannedUid = scan['uid']?.toString();
                  final scannedAtStr = scan['scanned_at']?.toString();
                  
                  if (scannedUid != null && scannedUid.isNotEmpty && scannedAtStr != null) {
                    final scannedAt = DateTime.parse(scannedAtStr).toUtc();
                    final openTimeUtc = dialogOpenTime.toUtc().subtract(const Duration(seconds: 10));
                    if (scannedAt.isAfter(openTimeUtc)) {
                      setDialogState(() {
                        controller.text = scannedUid;
                      });
                    }
                  }
                }
              });

          return AlertDialog(
            title: Text(hasExisting ? "Edit RFID Card for ${employee['full_name']}" : "Assign RFID Card to ${employee['full_name']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(hasExisting
                    ? "Tap a new RFID card on the ESP32 reader to replace current UID, or type below:"
                    : "Tap a new RFID card on the ESP32 reader to auto-detect, or type it below:"),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Expanded(child: Text("Listening for RFID tap on reader...", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  enabled: !isListening,
                  decoration: const InputDecoration(
                    labelText: "RFID UID",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  isListening = false;
                  scanSubscription?.cancel();
                  Navigator.pop(dialogContext);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  isListening = false;
                  scanSubscription?.cancel();
                  final newUid = controller.text.trim().toUpperCase();
                  Navigator.pop(dialogContext);
                  try {
                    await _supabase.from('employee_details').upsert({
                      'user_id': employee['id'],
                      'rfid_uid': newUid.isEmpty ? null : newUid,
                    });
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text(hasExisting ? "RFID UID updated successfully!" : "RFID UID assigned successfully!")),
                    );
                    _loadData();
                  } catch (e) {
                    if (!mounted) return;
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text("Error updating RFID: $e"), backgroundColor: Colors.red),
                    );
                  }
                },
                child: Text(hasExisting ? "UPDATE CARD" : "ASSIGN CARD"),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() async {
      scanSubscription?.cancel();
      if (!mounted) return;
      try {
        await _supabase.from('system_settings').upsert({'key': 'rfid_mode', 'value': 'ATTENDANCE'});
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live RFID Attendance & Staff Cards"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Refresh Data",
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(height: 400, child: _buildEmployeeRfidPanel()),
          const Divider(thickness: 2),
          SizedBox(height: 500, child: _buildAttendanceList()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 2, child: _buildEmployeeRfidPanel()),
        const VerticalDivider(width: 1),
        Expanded(flex: 3, child: _buildAttendanceList()),
      ],
    );
  }

  Widget _buildEmployeeRfidPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          color: Theme.of(context).primaryColor.withAlpha((0.1 * 255).toInt()),
          child: Row(
            children: const [
              Icon(Icons.badge, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Staff RFID Card Registry",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const LoadingState()
              : _employees.isEmpty
                  ? const Center(child: Text("No staff members found."))
                  : ListView.builder(
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final emp = _employees[index];
                        final empDetails = emp['employee_details'];
                        String? rfidUid;
                        if (empDetails is List && empDetails.isNotEmpty) {
                          rfidUid = empDetails[0]['rfid_uid'];
                        } else if (empDetails is Map) {
                          rfidUid = empDetails['rfid_uid'];
                        }

                        final avatarUrl = emp['avatar_url']?.toString();
                        final hasRfid = rfidUid != null && rfidUid.isNotEmpty;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: hasRfid ? Colors.green.shade100 : Colors.grey.shade200,
                            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Text(
                                    (emp['full_name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                                    style: TextStyle(color: hasRfid ? Colors.green.shade800 : Colors.grey.shade700, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Row(
                            children: [
                              Text(emp['full_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasRfid ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: hasRfid ? const Color(0xFFA7F3D0) : const Color(0xFFFFE0B2)),
                                ),
                                child: Text(
                                  hasRfid ? "✓ REGISTERED" : "UNLINKED",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: hasRfid ? const Color(0xFF059669) : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            "UID: ${rfidUid ?? 'Not Assigned'}",
                            style: TextStyle(fontSize: 12, color: hasRfid ? Colors.black87 : Colors.grey),
                          ),
                          trailing: IconButton(
                            icon: Icon(hasRfid ? Icons.edit_outlined : Icons.add_card_rounded, color: const Color(0xFFC2416C)),
                            onPressed: () => _assignRfid(emp, existingUid: rfidUid),
                            tooltip: hasRfid ? "Edit RFID Card ($rfidUid)" : "Assign RFID Card",
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_isLoading) return const LoadingState();

    return Column(
      children: [
        _buildSummaryCards(),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Live Daily Attendance Log",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC2416C).withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${_attendanceList.length} Active Today",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2416C)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _attendanceList.isEmpty
              ? const Center(child: Text("No attendance records for today yet. Tap your RFID card on the ESP32!"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _attendanceList.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceList[index];
                    final isShiftActive = record.isOnShift;

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isShiftActive ? const Color(0xFFA7F3D0) : Colors.grey.shade200,
                          width: isShiftActive ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: _getStatusColor(record.status).withAlpha(30),
                                      backgroundImage: record.avatarUrl != null && record.avatarUrl!.isNotEmpty ? NetworkImage(record.avatarUrl!) : null,
                                      child: record.avatarUrl == null || record.avatarUrl!.isEmpty
                                          ? Icon(Icons.person, color: _getStatusColor(record.status), size: 20)
                                          : null,
                                    ),
                                    if (isShiftActive)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        record.employeeName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "${record.position} • ${DateFormat('MMM dd, yyyy').format(record.checkIn)}",
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(record.status).withAlpha(30),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        record.status.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(record.status),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isShiftActive ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isShiftActive ? "🟢 ON SHIFT" : "✓ COMPLETED",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isShiftActive ? const Color(0xFF059669) : Colors.blueGrey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF2563EB)),
                                      const SizedBox(width: 6),
                                      Text(
                                        "In: ${DateFormat('hh:mm a').format(record.checkIn)}",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        record.checkOut != null
                                            ? "Out: ${DateFormat('hh:mm a').format(record.checkOut!)}"
                                            : "Out: Active Now",
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: record.checkOut != null ? const Color(0xFF059669) : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Duration: ${record.formattedDuration}",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                      ),
                                      Text(
                                        "Est. Pay: ₱${record.estimatedPay.toStringAsFixed(2)}",
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards() {
    final present = _attendanceList
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final lates = _attendanceList
        .where((a) => a.status == AttendanceStatus.late)
        .length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _summaryCard("Present", present.toString(), Colors.green),
          const SizedBox(width: 8),
          _summaryCard("Late", lates.toString(), Colors.orange),
          const SizedBox(width: 8),
          _summaryCard(
            "Absent",
            (_employees.length - present - lates).toString(),
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha((0.1 * 255).toInt()),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.absent:
        return Colors.red;
    }
  }
}
