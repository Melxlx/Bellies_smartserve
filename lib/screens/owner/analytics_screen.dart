import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/responsive_layout.dart';
import '../../core/web_helper.dart';
import '../../repositories/analytics_repository.dart';
import '../../widgets/state_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _repo = AnalyticsRepository();
  String _selectedPeriod = 'Monthly';
  final currencyFormat = NumberFormat.currency(symbol: '₱');
  
  Map<String, dynamic>? _performance;
  List<Map<String, dynamic>> _bestSellers = [];
  List<Map<String, dynamic>> _peakHours = [];
  List<Map<String, dynamic>> _inventoryUsage = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime start;
      switch (_selectedPeriod) {
        case 'Daily': start = DateTime(now.year, now.month, now.day); break;
        case 'Weekly': start = now.subtract(const Duration(days: 7)); break;
        default: start = now.subtract(const Duration(days: 30));
      }
      
      final results = await Future.wait([
        _repo.getPerformance(start, now),
        _repo.getBestSellers(),
        _repo.getPeakHours(),
        _repo.getInventoryUsage(),
      ]);

      setState(() {
        _performance = results[0] as Map<String, dynamic>;
        _bestSellers = results[1] as List<Map<String, dynamic>>;
        _peakHours = results[2] as List<Map<String, dynamic>>;
        _inventoryUsage = results[3] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showReportPreview() {
    if (_performance == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFC2416C), size: 22),
            ),
            const SizedBox(width: 12),
            Text("PDF Sales Report Preview", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B1A22),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Image.asset('assets/images/Bellieslogo.png', height: 42, errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant, color: Colors.white, size: 30)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Bellie's SmartServe", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            Text("Sales & Inventory Report ($_selectedPeriod)", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 2),
                            Text("Generated: ${DateFormat('MMMM d, yyyy · hh:mm a').format(DateTime.now())}", style: const TextStyle(color: Colors.white38, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("FINANCIAL SUMMARY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC2416C), letterSpacing: 0.8)),
                const SizedBox(height: 8),
                _reportRow("Total Revenue", currencyFormat.format(_performance!['revenue'])),
                _reportRow("Est. Expenses", currencyFormat.format(_performance!['expenses'])),
                _reportRow("Net Profit", currencyFormat.format(_performance!['profit'])),
                _reportRow("Total Orders", "${_performance!['order_count']} orders"),
                const Divider(height: 24),
                const Text("BEST SELLING PRODUCTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC2416C), letterSpacing: 0.8)),
                const SizedBox(height: 8),
                if (_bestSellers.isEmpty)
                  const Text("No sales recorded for this period.", style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ..._bestSellers.map((s) => _reportRow(s['product_name'] ?? 'Product', "${s['total_sold']} units sold")),
                const Divider(height: 24),
                const Text("INVENTORY CONSUMPTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFC2416C), letterSpacing: 0.8)),
                const SizedBox(height: 8),
                if (_inventoryUsage.isEmpty)
                  const Text("No inventory consumption recorded.", style: TextStyle(fontSize: 12, color: Colors.grey))
                else
                  ..._inventoryUsage.take(5).map((u) => _reportRow(u['ingredient_name'] ?? 'Ingredient', "${u['total_consumed']} ${u['unit']}")),
                const SizedBox(height: 20),
                const Center(child: Text("Official Bellie's SmartServe Executive Report", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 11))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (kIsWeb) {
                try {
                  printWebPage();
                } catch (_) {}
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("PDF Report generated for $_selectedPeriod! Choose 'Save as PDF' in the destination options."),
                  backgroundColor: const Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text("SAVE AS PDF / PRINT"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2416C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: LoadingState());

    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: Text("Sales & Inventory Analytics", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: ElevatedButton.icon(
              onPressed: _showReportPreview,
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: const Text("EXPORT AS PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2416C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilters(),
              const SizedBox(height: 20),
              _buildMetricsGrid(),
              const SizedBox(height: 28),
              _buildResponsiveCharts(),
              const SizedBox(height: 28),
              _buildInventoryConsumption(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFFC2416C)),
          const SizedBox(width: 8),
          const Text("Period:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _selectedPeriod,
            underline: const SizedBox.shrink(),
            items: ['Daily', 'Weekly', 'Monthly'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))).toList(),
            onChanged: (val) {
              setState(() => _selectedPeriod = val!);
              _loadAllData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    final revenue = (_performance?['revenue'] ?? 0).toDouble();
    final expenses = (_performance?['expenses'] ?? 0).toDouble();
    final profit = (_performance?['profit'] ?? 0).toDouble();
    final orders = _performance?['order_count'] ?? 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: ResponsiveLayout.isMobile(context) ? 2 : 4,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        _metricCard("Total Revenue", currencyFormat.format(revenue), Icons.payments_rounded, Colors.blue),
        _metricCard("Est. Expenses", currencyFormat.format(expenses), Icons.trending_down_rounded, Colors.orange),
        _metricCard("Est. Profit", currencyFormat.format(profit), Icons.trending_up_rounded, Colors.green),
        _metricCard("Total Orders", orders.toString(), Icons.receipt_long_rounded, Colors.purple),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(30), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveCharts() {
    return ResponsiveLayout(
      mobile: Column(
        children: [
          _buildBestSellers(),
          const SizedBox(height: 20),
          _buildBarChartSim("Peak Ordering Hours", _peakHours),
        ],
      ),
      desktop: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildBestSellers()),
          const SizedBox(width: 20),
          Expanded(child: _buildBarChartSim("Peak Ordering Hours", _peakHours)),
        ],
      ),
    );
  }

  Widget _buildBestSellers() {
    final maxSold = _bestSellers.fold<int>(
      1,
      (max, item) {
        final sold = (item['total_sold'] as num? ?? 0).toInt();
        return sold > max ? sold : max;
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Best Selling Products", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
            const SizedBox(height: 16),
            if (_bestSellers.isEmpty) const Text("No sales data recorded yet.", style: TextStyle(color: Colors.grey)),
            ..._bestSellers.map((item) {
              final sold = (item['total_sold'] as num? ?? 0).toInt();
              final ratio = (sold / maxSold).clamp(0.05, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['product_name'] ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text("$sold sold", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2416C), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Colors.grey[100],
                        color: const Color(0xFFC2416C),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartSim(String title, List<Map<String, dynamic>> data) {
    final maxOrders = data.fold<int>(
      1,
      (max, d) {
        final total = (d['total_orders'] as num? ?? 0).toInt();
        return total > max ? total : max;
      },
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
            const SizedBox(height: 24),
            if (data.isEmpty) const Text("No ordering activity detected.", style: TextStyle(color: Colors.grey)),
            SizedBox(
              height: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((d) {
                  final orders = (d['total_orders'] as num? ?? 0).toInt();
                  final height = ((orders / maxOrders) * 100).clamp(10.0, 100.0);
                  final hour = (d['order_hour'] as num? ?? 0).toInt();
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("$orders", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2416C))),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: height,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC2416C),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("${hour.toString().padLeft(2, '0')}:00", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryConsumption() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Inventory Consumption Status", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A))),
            const SizedBox(height: 16),
            if (_inventoryUsage.isEmpty)
              const Text("No inventory movement detected.", style: TextStyle(color: Colors.grey))
            else
              ..._inventoryUsage.take(5).map((u) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(u['ingredient_name'] ?? 'Ingredient', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${u['total_consumed']} ${u['unit']}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}
