import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../repositories/rider_dashboard_repository.dart';
import '../../widgets/state_widgets.dart';

class RiderHistoryScreen extends StatefulWidget {
  final String riderId;
  const RiderHistoryScreen({super.key, required this.riderId});

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  final _repo = RiderDashboardRepository();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // All, Delivered

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDeliveryDetails(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Order #${order.queueNumber} Details", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Chip(
                    label: Text("DELIVERED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    backgroundColor: Color(0xFFC2416C),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text("Delivered on ${DateFormat('MMMM d, yyyy • hh:mm a').format(order.timestamp)}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Divider(height: 24),
              const Text("Customer Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC2416C))),
              const SizedBox(height: 8),
              Text("Name: ${order.customerDetails?.name ?? 'N/A'}"),
              Text("Phone: ${order.customerDetails?.contact ?? 'N/A'}"),
              Text("Address: ${order.customerDetails?.address ?? 'N/A'}"),
              const SizedBox(height: 16),
              const Text("Product Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC2416C))),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${item.quantity}x ${item.product.name}"),
                    Text("₱${(item.product.sellingPrice * item.quantity).toStringAsFixed(2)}"),
                  ],
                ),
              )),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("₱${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFC2416C))),
                ],
              ),
              if (order.deliveryProofUrl != null && order.deliveryProofUrl!.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text("Proof of Delivery Photo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFC2416C))),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    order.deliveryProofUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => const Text("Could not load delivery proof image."),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delivery History"),
        backgroundColor: const Color(0xFFC2416C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFC2416C).withAlpha(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search by Order # or Customer Name...",
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFC2416C)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ['All', 'Delivered'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          selectedColor: const Color(0xFFC2416C),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<OrderModel>>(
              stream: _repo.streamRiderDeliveries(widget.riderId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return ErrorState(error: snapshot.error.toString(), onRetry: () {});
                if (!snapshot.hasData) return const LoadingState();

                var history = snapshot.data!.where((o) => o.deliveryStatus == DeliveryStatus.delivered).toList();

                // Apply search
                if (_searchQuery.isNotEmpty) {
                  history = history.where((o) => o.queueNumber.toString().toLowerCase().contains(_searchQuery) || (o.customerDetails?.name ?? '').toLowerCase().contains(_searchQuery)).toList();
                }

                if (history.isEmpty) return const EmptyState(message: "No delivery history found.");

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final order = history[index];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showDeliveryDetails(context, order),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Order #${order.queueNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "DELIVERED",
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(order.customerDetails?.name ?? "Customer", style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.fastfood_outlined, size: 16, color: Color(0xFFC2416C)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      order.itemsSummary,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    "${DateFormat('MMM d, yyyy • hh:mm a').format(order.timestamp)}${order.relativeTime.isNotEmpty ? ' (${order.relativeTime})' : ''}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${order.items.length} item(s)", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                  Text("₱${order.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC2416C))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
