import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/safe_button.dart';

class OnlineOrdersScreen extends StatefulWidget {
  final bool showAppBar;

  const OnlineOrdersScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<OnlineOrdersScreen> createState() => _OnlineOrdersScreenState();
}

class _OnlineOrdersScreenState extends State<OnlineOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _orderRepo = OrderRepository();
  late TabController _tabController;
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _verifyOrder(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFFE91E63), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Verify Order #${order.queueNumber}",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Details Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerDetails?.name ?? 'Customer',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFFE91E63)),
                          const SizedBox(width: 6),
                          Text(order.customerDetails?.contact ?? 'N/A', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFE91E63)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.customerDetails?.fullAddress ?? 'N/A',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      if (order.customerDetails?.deliveryInstructions.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(
                          "Instructions: ${order.customerDetails!.deliveryInstructions}",
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  "Order Items",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    children: order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${item.quantity}x ${item.product.name}",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            "₱${item.total.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // GCash Reference & Amount Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "GCash Reference Number",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue.shade900, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            order.referenceNumber?.isNotEmpty == true
                                ? order.referenceNumber!
                                : (order.customerDetails?.notes.isNotEmpty == true
                                    ? order.customerDetails!.notes
                                    : "No Ref Provided"),
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "₱${order.totalAmount.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE91E63),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // GCash Payment Receipt Proof Image
                if (order.paymentProofUrl?.isNotEmpty == true || order.deliveryProofUrl?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    "GCash Payment Receipt Proof:",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue.shade900),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {
                      final url = order.paymentProofUrl ?? order.deliveryProofUrl!;
                      showDialog(
                        context: context,
                        builder: (ctx) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  child: Center(child: _buildProofImage(url)),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                                    onPressed: () => Navigator.pop(ctx),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildProofImage(order.paymentProofUrl ?? order.deliveryProofUrl!),
                            Container(
                              color: Colors.black26,
                              child: const Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 6),
                                    Text("Tap to view full receipt", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  "Please verify if the GCash payment has been received in your account before confirming.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL"),
              ),
              Row(
                children: [
                  SafeAsyncButton(
                    isOutlined: true,
                    isIcon: true,
                    icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await _orderRepo.rejectPayment(order.id, reason: 'Invalid GCash Reference Number');
                      if (!navigator.mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Payment Rejected. Order cancelled and moved to History."),
                          backgroundColor: Colors.red,
                        ),
                      );
                    },
                    child: const Text("REJECT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  SafeAsyncButton(
                    isIcon: true,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.of(context);
                      await _orderRepo.confirmPayment(order.id);
                      if (!navigator.mounted) return;
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Order Verified! Sent to Kitchen for cooking."),
                          backgroundColor: Color(0xFF059669),
                        ),
                      );
                    },
                    child: const Text("CONFIRM", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderRepo.getPendingOnlineOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            error: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) return const LoadingState();

        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.verified_user_rounded, size: 48, color: Color(0xFFE91E63)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "All Online Payments Verified!",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "No pending online orders requiring GCash verification right now.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        final totalPages = (orders.length / _itemsPerPage).ceil();
        if (_currentPage > totalPages && totalPages > 0) {
          _currentPage = totalPages;
        }
        final start = (_currentPage - 1) * _itemsPerPage;
        final end = start + _itemsPerPage;
        final paginatedOrders = orders.sublist(start, end > orders.length ? orders.length : end);

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: paginatedOrders.length,
                itemBuilder: (context, index) {
                  final order = paginatedOrders[index];
                  final formattedTime = DateFormat('MMM dd, yyyy • hh:mm a').format(order.timestamp);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: const Color(0xFFFFF0F5),
                            child: const Icon(Icons.delivery_dining_rounded, color: Color(0xFFE91E63), size: 22),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      order.customerDetails?.name ?? "Online Customer",
                                      style: GoogleFonts.poppins(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0F5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "#${order.queueNumber}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFE91E63),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      "₱${order.totalAmount.toStringAsFixed(2)}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "• ${order.items.length} item(s) • $formattedTime",
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFFE91E63)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        order.customerDetails?.fullAddress ?? "Sta. Cruz, Laguna",
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (order.referenceNumber?.isNotEmpty == true) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SelectableText(
                                      "GCash Ref: ${order.referenceNumber}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _verifyOrder(order),
                            icon: const Icon(Icons.verified_user_rounded, size: 16),
                            label: Text(
                              "VERIFY",
                              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: PaginationBar(
                currentPage: _currentPage,
                totalPages: totalPages,
                totalItems: orders.length,
                itemsPerPage: _itemsPerPage,
                onPageChanged: (page) => setState(() => _currentPage = page),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderRepo.getAllOnlineOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            error: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) return const LoadingState();

        final allOrders = snapshot.data!;
        if (allOrders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, size: 48, color: Color(0xFFE91E63)),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "No GCash Transactions Yet",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Verified or rejected online GCash orders will be recorded here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }

        final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: allOrders.length,
          itemBuilder: (context, index) {
            final order = allOrders[index];
            final isPaid = order.paymentStatus.toUpperCase() == 'PAID';
            final isRejected = order.paymentStatus.toUpperCase() == 'REJECTED' || order.status.toLowerCase() == 'cancelled';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaid ? const Color(0xFFA7F3D0) : (isRejected ? const Color(0xFFFECDD3) : Colors.grey.shade200),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: isPaid ? const Color(0xFFE8F5E9) : (isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1)),
                  child: Icon(
                    isPaid ? Icons.check_circle_rounded : (isRejected ? Icons.cancel_rounded : Icons.schedule_rounded),
                    color: isPaid ? const Color(0xFF059669) : (isRejected ? Colors.red : Colors.amber.shade800),
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.customerDetails?.name ?? "Customer",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14.5, color: const Color(0xFF0F172A)),
                    ),
                    Text(
                      "₱${order.totalAmount.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: SelectableText(
                            "GCash Ref: ${order.referenceNumber ?? 'None'}",
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPaid ? const Color(0xFFE8F5E9) : (isRejected ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            order.paymentStatus.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPaid ? const Color(0xFF059669) : (isRejected ? Colors.red : Colors.amber.shade800),
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(order.timestamp),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProofImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final base64Str = url.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return const Icon(Icons.broken_image, color: Colors.grey);
      }
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFFE91E63),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFFE91E63),
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pending_actions_rounded, size: 16),
                    SizedBox(width: 6),
                    Text("Pending"),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 16),
                    SizedBox(width: 6),
                    Text("History"),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingList(),
              _buildHistoryList(),
            ],
          ),
        ),
      ],
    );

    if (!widget.showAppBar) {
      return bodyContent;
    }

    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: Text(
          "Online Orders & GCash Verification",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: bodyContent,
    );
  }
}
