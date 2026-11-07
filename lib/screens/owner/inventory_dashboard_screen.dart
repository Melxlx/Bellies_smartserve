import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/inventory_movement_model.dart';
import '../../models/product_model.dart';
import '../../repositories/inventory_repository.dart';
import '../../repositories/product_repository.dart';
import '../../widgets/state_widgets.dart';

class InventoryDashboardScreen extends StatefulWidget {
  final bool showHistoryOnly;
  final bool showSummaryOnly;

  const InventoryDashboardScreen({
    super.key,
    this.showHistoryOnly = false,
    this.showSummaryOnly = false,
  });

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  final _productRepo = ProductRepository();
  final _inventoryRepo = InventoryRepository();

  bool _isLoading = true;
  String? _error;
  List<ProductModel> _products = [];
  List<InventoryMovementModel> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _productRepo.getInventoryProducts(),
        _inventoryRepo.getMovementHistory(),
      ]);
      if (mounted) {
        setState(() {
          _products = results[0] as List<ProductModel>;
          _history = results[1] as List<InventoryMovementModel>;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingState();
    if (_error != null) return ErrorState(error: _error!, onRetry: _loadData);
    if (widget.showHistoryOnly) return _buildHistory();

    final lowStock = _products
        .where((product) => product.inventoryStatus == InventoryStatus.lowStock)
        .length;
    final outOfStock = _products
        .where(
          (product) => product.inventoryStatus == InventoryStatus.outOfStock,
        )
        .length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              _summaryCard(
                'Products',
                _products.length.toString(),
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _summaryCard('Low Stock', lowStock.toString(), Colors.orange),
              const SizedBox(width: 12),
              _summaryCard('Out of Stock', outOfStock.toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.blue,
              ),
              title: const Text('Tracked Quantity'),
              subtitle: Text(
                '${_products.fold<double>(0, (total, product) => total + product.inventoryQuantity)} total units',
              ),
              trailing: Text('${_history.length} movements'),
            ),
          ),
          if (!widget.showSummaryOnly) ...[
            const SizedBox(height: 20),
            _buildAlerts(),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color) {
    return Expanded(
      child: Card(
        color: color.withAlpha(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(label, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlerts() {
    final alerts = _products
        .where((product) => product.inventoryStatus != InventoryStatus.inStock)
        .toList();
    if (alerts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('All stock levels are healthy.')),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text('Low-stock alerts'),
          ),
          ...alerts.map(
            (product) => ListTile(
              title: Text('${product.productCode} - ${product.name}'),
              subtitle: Text(
                '${product.inventoryQuantity} ${product.inventoryUnit} remaining',
              ),
              trailing: Text(_statusLabel(product.inventoryStatus)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const EmptyState(message: 'No inventory movements recorded.');
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final movement = _history[index];
        final isStockIn = movement.movementType == MovementType.stockIn;
        final isOrderDeduction = movement.rawMovementType == 'ORDER_DEDUCTION';

        final Color themeColor = isStockIn
            ? const Color(0xFF34C759) // iOS Emerald Green
            : (isOrderDeduction
                ? const Color(0xFFD6336C) // Bellie's Rose Pink
                : const Color(0xFFFF9500)); // iOS Amber Orange

        final Color bgTint = isStockIn
            ? (isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F9ED))
            : (isOrderDeduction
                ? (isDark ? const Color(0xFF3B1E29) : const Color(0xFFFFEBF0))
                : (isDark ? const Color(0xFF3A2D1A) : const Color(0xFFFFF8E7)));

        final IconData movementIcon = isStockIn
            ? Icons.arrow_downward_rounded
            : (isOrderDeduction
                ? Icons.shopping_bag_outlined
                : Icons.arrow_upward_rounded);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // iOS Squircle Icon Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bgTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(movementIcon, color: themeColor, size: 24),
                ),
                const SizedBox(width: 14),

                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${movement.productCode.isNotEmpty ? "${movement.productCode} - " : ""}${movement.productName}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              movement.formattedMovementType,
                              style: GoogleFonts.poppins(
                                color: themeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (movement.reason != null && movement.reason!.isNotEmpty)
                            Text(
                              '• ${movement.reason}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${movement.displayUserName} • ${DateFormat("MMM dd, yyyy  hh:mm a").format(movement.createdAt)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Trailing Quantity Pill & Transition
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${isStockIn ? "+" : "-"}${_formatQty(movement.quantity)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatQty(movement.previousQuantity)} → ${_formatQty(movement.updatedQuantity)}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }

  String _statusLabel(InventoryStatus status) {
    switch (status) {
      case InventoryStatus.inStock:
        return 'In Stock';
      case InventoryStatus.lowStock:
        return 'Low Stock';
      case InventoryStatus.outOfStock:
        return 'Out of Stock';
    }
  }
}
