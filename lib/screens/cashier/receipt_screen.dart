import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
import '../../models/order_model.dart';

class ReceiptScreen extends StatefulWidget {
  final OrderModel order;
  final bool customerOrder;

  const ReceiptScreen({
    super.key,
    required this.order,
    this.customerOrder = false,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String? _customerName;
  String? _cashierName;

  @override
  void initState() {
    super.initState();
    _resolveNames();
  }

  Future<void> _resolveNames() async {
    String customer = widget.order.customerDetails?.name ?? '';
    String cashier = widget.order.cashierName ?? '';

    try {
      final client = Supabase.instance.client;

      // 1. Resolve Customer Name if missing
      if (customer.trim().isEmpty) {
        if (widget.order.createdBy != null && widget.order.createdBy!.isNotEmpty) {
          try {
            final profile = await client
                .from('profiles')
                .select('full_name, role')
                .eq('id', widget.order.createdBy!)
                .maybeSingle();
            if (profile != null && profile['full_name'] != null && profile['full_name'].toString().trim().isNotEmpty) {
              customer = profile['full_name'].toString().trim();
            }
          } catch (_) {}
        }
      }

      // 2. Resolve Cashier / Owner Name if missing
      if (cashier.trim().isEmpty) {
        if (widget.order.createdBy != null && widget.order.createdBy!.isNotEmpty) {
          try {
            final profile = await client
                .from('profiles')
                .select('full_name, role, position')
                .eq('id', widget.order.createdBy!)
                .maybeSingle();
            if (profile != null && profile['full_name'] != null) {
              final role = profile['role']?.toString().toUpperCase() ?? '';
              final pos = profile['position']?.toString() ?? '';
              final name = profile['full_name'].toString().trim();
              if (role != 'CUSTOMER' && name.isNotEmpty) {
                if (role == 'OWNER' || pos.toLowerCase().contains('owner')) {
                  cashier = "$name (Owner)";
                } else {
                  cashier = name;
                }
              }
            }
          } catch (_) {}
        }

        if (cashier.trim().isEmpty && widget.order.id.isNotEmpty && widget.order.id != 'TEMP') {
          try {
            final payment = await client
                .from('payments')
                .select('processed_by, profiles!payments_processed_by_fkey(full_name, role, position)')
                .eq('order_id', widget.order.id)
                .maybeSingle();
            if (payment != null && payment['profiles'] != null && payment['profiles']['full_name'] != null) {
              final name = payment['profiles']['full_name'].toString().trim();
              final role = payment['profiles']['role']?.toString().toUpperCase() ?? '';
              final pos = payment['profiles']['position']?.toString() ?? '';
              if (role == 'OWNER' || pos.toLowerCase().contains('owner')) {
                cashier = "$name (Owner)";
              } else {
                cashier = name;
              }
            }
          } catch (_) {}
        }

        if (cashier.trim().isEmpty) {
          try {
            final currentUser = client.auth.currentUser;
            if (currentUser != null) {
              final profile = await client
                  .from('profiles')
                  .select('full_name, role, position')
                  .eq('id', currentUser.id)
                  .maybeSingle();
              if (profile != null && profile['full_name'] != null) {
                final role = profile['role']?.toString().toUpperCase() ?? '';
                final pos = profile['position']?.toString() ?? '';
                final name = profile['full_name'].toString().trim();
                if (role != 'CUSTOMER' && name.isNotEmpty) {
                  if (role == 'OWNER' || pos.toLowerCase().contains('owner')) {
                    cashier = "$name (Owner)";
                  } else {
                    cashier = name;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (customer.trim().isEmpty) {
      customer = widget.order.serviceType == ServiceType.delivery ? "Online Customer" : "Walk-in Customer";
    }
    if (cashier.trim().isEmpty) {
      cashier = widget.customerOrder ? "Bellie's Kitchen System" : "Cashier / Staff";
    }

    if (mounted) {
      setState(() {
        _customerName = customer;
        _cashierName = cashier;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Digital Receipt"),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Center(
          child: ResponsiveLayout(
            mobile: _buildReceipt(context, maxWidth: double.infinity),
            desktop: _buildReceipt(context, maxWidth: 480),
          ),
        ),
      ),
    );
  }

  Widget _buildReceipt(BuildContext context, {required double maxWidth}) {
    final dateFormat = DateFormat('MMM dd, yyyy hh:mm a');
    final isCustomer = widget.customerOrder;
    final bool canPop = Navigator.canPop(context);
    final order = widget.order;

    final displayCustomerName = _customerName ?? (order.customerDetails?.name.isNotEmpty == true ? order.customerDetails!.name : "Walk-in Customer");
    final displayCashierName = _cashierName ?? (order.cashierName?.isNotEmpty == true ? order.cashierName! : "Cashier / Staff");

    return Column(
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Image.asset(
                    'assets/images/Bellieslogo.png',
                    height: 75,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.restaurant,
                      size: 50,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Bellie's Kitchen",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCustomer ? "Order Confirmation" : "SmartServe POS Receipt",
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (order.trackingNumber.isNotEmpty)
                    _row("Tracking No:", order.trackingNumber, isBold: true),
                  if (order.id.isNotEmpty)
                    _row("Order ID:", order.id.length > 8 ? order.id.substring(0, 8) : order.id),
                  _row("Queue No:", order.queueNumber, isBold: true),
                  _row("Date:", dateFormat.format(order.timestamp)),
                  _row("Service:", order.serviceType.name.toUpperCase()),
                  _row("Customer:", displayCustomerName, isBold: true),
                  _row("Cashier / Staff:", displayCashierName, isBold: true),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${item.product.name} x ${item.quantity}",
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            "₱${item.total.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _row("Subtotal:", "₱${order.subtotal.toStringAsFixed(2)}"),
                  if (order.deliveryFee > 0)
                    _row(
                      "Delivery Fee:",
                      "₱${order.deliveryFee.toStringAsFixed(2)}",
                    ),
                  _row(
                    "Total Amount:",
                    "₱${order.totalAmount.toStringAsFixed(2)}",
                    isBold: true,
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  _row(
                    "Payment Method:",
                    order.paymentMethod?.name.toUpperCase() ?? 'GCASH',
                  ),
                  _row(
                    "Payment Status:",
                    order.paymentStatus.toUpperCase() == 'PAID'
                        ? 'PAID'
                        : 'PENDING VERIFICATION',
                    isBold: true,
                    color: order.paymentStatus.toUpperCase() == 'PAID'
                        ? Colors.green
                        : Colors.orange.shade800,
                  ),
                  if (order.paymentMethod == PaymentMethod.cash) ...[
                    if (order.amountTendered != null)
                      _row(
                        "Amount Tendered:",
                        "₱${order.amountTendered?.toStringAsFixed(2)}",
                      ),
                    if (order.change != null)
                      _row("Change:", "₱${order.change?.toStringAsFixed(2)}"),
                  ],
                  if (order.referenceNumber != null && order.referenceNumber!.isNotEmpty)
                    _row("Ref No:", order.referenceNumber!),
                  if (order.deliveryProofUrl != null && order.deliveryProofUrl!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildProofOfDeliverySection(context, order),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    "Thank you for dining with Bellie's Kitchen!",
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: maxWidth,
          child: Column(
            children: [
              if (canPop) ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text("CLOSE RECEIPT"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (isCustomer) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.customerMenu,
                          (route) => false,
                        );
                      } else {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.cashierPos,
                          (route) => route.isFirst,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isCustomer ? "ORDER MORE" : "NEW TRANSACTION"),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isCustomer) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.cashierDashboard,
                        (route) => false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("BACK TO DASHBOARD"),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        isCustomer ? AppRoutes.tracking : AppRoutes.kitchenQueue,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      isCustomer ? "TRACK MY ORDER" : "VIEW KITCHEN QUEUE",
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String proofUrl) {
    final isDataUrl = proofUrl.startsWith('data:image');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: isDataUrl
                  ? Image.memory(
                      base64Decode(proofUrl.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      proofUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("Unable to load full photo", style: TextStyle(color: Colors.white)),
                      ),
                    ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofOfDeliverySection(BuildContext context, OrderModel order) {
    if (order.deliveryProofUrl == null || order.deliveryProofUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final proofUrl = order.deliveryProofUrl!;
    final isDataUrl = proofUrl.startsWith('data:image');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 18),
                SizedBox(width: 6),
                Text(
                  "Proof of Delivery Photo",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () => _showFullScreenImage(context, proofUrl),
              icon: const Icon(Icons.zoom_in, size: 14, color: Colors.green),
              label: const Text("VIEW FULL", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _showFullScreenImage(context, proofUrl),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 320, minHeight: 160),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isDataUrl
                  ? Image.memory(
                      base64Decode(proofUrl.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      proofUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => Container(
                        height: 100,
                        color: Colors.grey[100],
                        child: const Center(child: Text("Unable to load proof photo", style: TextStyle(fontSize: 11, color: Colors.grey))),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 15 : 14,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
