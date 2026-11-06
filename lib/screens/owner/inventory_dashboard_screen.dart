import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final movement = _history[index];
        final isStockIn = movement.movementType == MovementType.stockIn;
        final color = isStockIn
            ? Colors.green[700]!
            : (movement.rawMovementType == 'ORDER_DEDUCTION'
                ? const Color(0xFFE91E63)
                : Colors.orange[800]!);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: color.withAlpha(25),
              child: Icon(
                isStockIn ? Icons.add_rounded : Icons.remove_rounded,
                color: color,
              ),
            ),
            title: Text(
              '${movement.productCode.isNotEmpty ? "${movement.productCode} - " : ""}${movement.productName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${movement.formattedMovementType} • ${movement.reason ?? "No reason"}\n'
              '${movement.userName ?? "System"} • '
              '${DateFormat("MMM dd, yyyy hh:mm a").format(movement.createdAt)}',
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
            isThreeLine: true,
            trailing: Text(
              '${isStockIn ? "+" : "-"}${movement.quantity.toStringAsFixed(0)}\n'
              '${movement.previousQuantity.toStringAsFixed(0)} → ${movement.updatedQuantity.toStringAsFixed(0)}',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
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
