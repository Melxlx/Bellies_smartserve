import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../repositories/payroll_repository.dart';
import '../../widgets/state_widgets.dart';

class PayrollManagementScreen extends StatefulWidget {
  const PayrollManagementScreen({super.key});

  @override
  State<PayrollManagementScreen> createState() => _PayrollManagementScreenState();
}

class _PayrollManagementScreenState extends State<PayrollManagementScreen> with SingleTickerProviderStateMixin {
  final _payrollRepo = PayrollRepository();
  final _currencyFormat = NumberFormat.currency(symbol: '₱');

  late final TabController _tabController;
  List<Map<String, dynamic>> _payrollData = [];
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  bool _isLoadingHistory = false;
  DateTime _selectedHistoryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _historyData.isEmpty) {
        _loadHistory();
      }
    });
    _loadPayroll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPayroll() async {
    setState(() => _isLoading = true);
    try {
      final data = await _payrollRepo.getPendingPayroll();
      setState(() {
        _payrollData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final data = await _payrollRepo.getPayrollHistory(_selectedHistoryDate);
      setState(() {
        _historyData = data;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading history: $e")));
      }
    }
  }

  Future<void> _pickHistoryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFC2416C)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedHistoryDate = picked);
      _loadHistory();
    }
  }

  String _generateCsvString() {
    final buffer = StringBuffer();
    buffer.writeln("Staff Name,Role,Days Present,Total Hours,Daily Rate,Total Payout");
    for (final p in _payrollData) {
      final name = '"${p['full_name'] ?? 'Staff'}"';
      final role = '"${p['role'] ?? 'Staff'}"';
      final daysPresent = p['days_present'] ?? 0;
      final hours = p['hours_worked'] ?? 0;
      final rate = p['daily_rate'] ?? 0;
      final payout = p['estimated_earnings'] ?? 0;
      buffer.writeln('$name,$role,$daysPresent,$hours,$rate,$payout');
    }
    return buffer.toString();
  }

  Future<void> _processPayout(Map<String, dynamic> staff) async {
    final String name = staff['full_name'] ?? 'Staff Member';
    final double rate = (staff['estimated_earnings'] as num? ?? staff['daily_rate'] as num? ?? 0).toDouble();
    final double hoursWorked = (staff['hours_worked'] as num? ?? 8.0).toDouble();
    final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    final checkInStr = staff['check_in'] != null
        ? DateFormat('hh:mm a').format(DateTime.parse(staff['check_in']))
        : 'Checked In Today';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payments_outlined, color: Color(0xFFC2416C)),
            SizedBox(width: 10),
            Text("Confirm Daily Payout"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Process daily wage payout for $name for today ($todayStr)?", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD1DC)),
              ),
              child: Column(
                children: [
                  _dialogRow("Date", DateFormat('MMM d, yyyy').format(DateTime.now())),
                  _dialogRow("Shift Period", "${hoursWorked.toStringAsFixed(1)} Hours Worked ($checkInStr)"),
                  const Divider(height: 16),
                  _dialogRow("Calculated Wage", _currencyFormat.format(rate), isBold: true),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2416C),
              foregroundColor: Colors.white,
            ),
            child: const Text("PAY DAILY WAGE"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _payrollRepo.processPayment(staff);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Today's daily wage for $name (${_currencyFormat.format(rate)}) paid successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          _loadPayroll();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error processing payment: $e")));
        }
      }
    }
  }

  Widget _dialogRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          Text(
            val,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? const Color(0xFFC2416C) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayFormatted = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: const Text("Daily Wage Payroll"),
        backgroundColor: const Color(0xFFC2416C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: "Today", icon: Icon(Icons.today_rounded, size: 16)),
            Tab(text: "History", icon: Icon(Icons.history_rounded, size: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: "Export Payroll CSV",
            onPressed: () {
              if (_payrollData.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No payroll records to export.")));
                return;
              }
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text("Payroll CSV Export"),
                  content: SizedBox(
                    width: 450,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _generateCsvString(),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _loadPayroll();
              } else {
                _loadHistory();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Today's Payouts
          _isLoading
              ? const LoadingState()
              : _payrollData.isEmpty
                  ? const EmptyState(message: "No staff attendance recorded for today.\n\nPayroll entries will appear automatically once staff members scan their RFID for today's shift.")
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          color: const Color(0xFFFFF0F5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFC2416C)),
                                  const SizedBox(width: 8),
                                  Text("Today: $todayFormatted", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2B1A22))),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC2416C).withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text("DAILY PAYOUT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2416C))),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _payrollData.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final staff = _payrollData[index];
                              final double rate = (staff['estimated_earnings'] as num? ?? staff['daily_rate'] as num? ?? 0).toDouble();
                              final double hoursWorked = (staff['hours_worked'] as num? ?? 8.0).toDouble();
                              final bool isPaidToday = staff['is_paid_today'] == true;
                              final checkInFormatted = staff['check_in'] != null
                                  ? DateFormat('hh:mm a').format(DateTime.parse(staff['check_in']))
                                  : null;
                              final attStatus = staff['attendance_status'] ?? 'PRESENT';

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: isPaidToday ? Colors.green.shade200 : const Color(0xFFFFD1DC),
                                    width: isPaidToday ? 1 : 1.5,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18.0),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: isPaidToday ? Colors.green.shade100 : const Color(0xFFC2416C).withAlpha(30),
                                            child: Icon(
                                              isPaidToday ? Icons.check_circle_rounded : Icons.person_outline,
                                              color: isPaidToday ? Colors.green : const Color(0xFFC2416C),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(staff['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: isPaidToday ? Colors.green.shade100 : Colors.orange.shade100,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        isPaidToday ? "✓ PAID TODAY" : "UNPAID TODAY",
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.bold,
                                                          color: isPaidToday ? Colors.green.shade800 : Colors.orange.shade900,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "${staff['position']}${checkInFormatted != null ? ' • Check-In: $checkInFormatted • ${hoursWorked.toStringAsFixed(1)} hrs ($attStatus)' : ''}",
                                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              const Text("Calculated Wage", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                              Text(_currencyFormat.format(rate), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPaidToday ? Colors.green : const Color(0xFFC2416C))),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: Icon(isPaidToday ? Icons.check_circle_rounded : Icons.payments_outlined, size: 18),
                                          label: Text(isPaidToday ? "PAID FOR TODAY (${_currencyFormat.format(rate)})" : "PAY DAILY WAGE (${_currencyFormat.format(rate)})"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isPaidToday ? Colors.grey.shade300 : const Color(0xFFC2416C),
                                            foregroundColor: isPaidToday ? Colors.grey.shade700 : Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            elevation: isPaidToday ? 0 : 2,
                                          ),
                                          onPressed: isPaidToday ? null : () => _processPayout(staff),
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
                    ),

          // Tab 1: Payroll History
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                color: const Color(0xFFFFF0F5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 16, color: Color(0xFFC2416C)),
                        const SizedBox(width: 8),
                        Text("History Date: ${DateFormat('MMMM d, yyyy').format(_selectedHistoryDate)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2B1A22))),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC2416C),
                        side: const BorderSide(color: Color(0xFFC2416C)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _pickHistoryDate,
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: const Text("SELECT DATE"),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingHistory
                    ? const LoadingState()
                    : _historyData.isEmpty
                        ? const EmptyState(message: "No payroll payout history found for this date.")
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _historyData.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _historyData[index];
                              final profile = item['profiles'] as Map<String, dynamic>?;
                              final name = profile?['full_name']?.toString() ?? 'Staff Member';
                              final position = profile?['position']?.toString() ?? 'Staff';
                              final netPay = (item['net_pay'] as num? ?? 0).toDouble();
                              final paidAtStr = item['paid_at'] != null
                                  ? DateFormat('hh:mm a').format(DateTime.parse(item['paid_at']).toLocal())
                                  : '';

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE8F5E9),
                                    child: Icon(Icons.check_circle, color: Colors.green),
                                  ),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Text("$position • Paid at $paidAtStr", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text("Paid Net Pay", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                      Text(_currencyFormat.format(netPay), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
