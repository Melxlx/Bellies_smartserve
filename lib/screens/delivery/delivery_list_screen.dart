import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/app_routes.dart';
import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/state_widgets.dart';
import 'delivery_details_screen.dart';

class DeliveryListScreen extends StatefulWidget {
  final bool showAppBar;
  const DeliveryListScreen({super.key, this.showAppBar = true});

  @override
  State<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends State<DeliveryListScreen> with SingleTickerProviderStateMixin {
  final _orderRepo = OrderRepository();
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.ownerDashboard);
                  }
                },
              ),
              title: Text(
                "Logistics & Deliveries",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF0F172A),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(54),
                child: _buildTabBar(),
              ),
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(54),
              child: _buildTabBar(),
            ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _orderRepo.getAllDeliveryOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) return const LoadingState();

          var allOrders = snapshot.data!;

          // Search Filter (queue #, customer name, address, rider)
          if (_searchQuery.trim().isNotEmpty) {
            final rawQ = _searchQuery.toLowerCase().trim();
            final cleanQ = rawQ.replaceAll('#', '').trim();
            allOrders = allOrders.where((o) {
              final name = (o.customerDetails?.name ?? '').toLowerCase();
              final addr = (o.customerDetails?.address ?? '').toLowerCase();
              final queue = o.queueNumber.toLowerCase();
              final rider = (o.riderName ?? '').toLowerCase();
              final queueNoInt = int.tryParse(queue) ?? -1;
              final searchInt = int.tryParse(cleanQ) ?? -2;

              return name.contains(rawQ) ||
                  name.contains(cleanQ) ||
                  addr.contains(cleanQ) ||
                  queue.contains(cleanQ) ||
                  rider.contains(cleanQ) ||
                  (searchInt > 0 && queueNoInt == searchInt);
            }).toList();
          }

          final unassigned = allOrders
              .where((o) => o.riderId == null && o.status.toLowerCase() == 'ready')
              .toList();

          final inProgress = allOrders
              .where((o) =>
                  o.riderId != null &&
                  o.deliveryStatus != DeliveryStatus.delivered &&
                  o.status.toLowerCase() != 'completed')
              .toList();

          final finishedToday = allOrders
              .where((o) =>
                  o.deliveryStatus == DeliveryStatus.delivered ||
                  o.status.toLowerCase() == 'completed')
              .toList();

          return Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search queue #, customer name, address, or rider...",
                    hintStyle: const TextStyle(fontSize: 12.5),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFFE91E63)),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // TabBar Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderList(
                      unassigned,
                      title: "No Unassigned Deliveries",
                      emptyMsg: "No orders are ready for pickup yet. Wait for the Kitchen to mark them ready.",
                      icon: Icons.person_add_disabled_outlined,
                    ),
                    _buildOrderList(
                      inProgress,
                      title: "No Deliveries In Transit",
                      emptyMsg: "No active rider deliveries currently in progress.",
                      icon: Icons.local_shipping_outlined,
                    ),
                    _buildOrderList(
                      finishedToday,
                      title: "No Completed Deliveries",
                      emptyMsg: "No delivery orders completed yet today.",
                      icon: Icons.task_alt_rounded,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
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
                Icon(Icons.person_add_disabled_outlined, size: 18),
                SizedBox(width: 8),
                Text("Unassigned"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 18),
                SizedBox(width: 8),
                Text("In Progress"),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.task_alt_rounded, size: 18),
                SizedBox(width: 8),
                Text("Finished Today"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(
    List<OrderModel> orders, {
    required String title,
    required String emptyMsg,
    required IconData icon,
  }) {
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
                child: Icon(icon, size: 48, color: const Color(0xFFE91E63)),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyMsg,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildDeliveryCard(orders[index]),
    );
  }

  Widget _buildDeliveryCard(OrderModel order) {
    final bool needsRider = order.riderId == null;
    final formattedTime = DateFormat('MMM dd, yyyy • hh:mm a').format(order.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeliveryDetailsScreen(order: order)),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "ORDER #${order.queueNumber}",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE91E63),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formattedTime,
                        style: TextStyle(color: Colors.grey[500], fontSize: 11.5),
                      ),
                    ],
                  ),
                  _statusChip(order),
                ],
              ),
              const SizedBox(height: 14),

              // Customer Name & Address
              Text(
                order.customerDetails?.name ?? "Guest Customer",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFE91E63)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.customerDetails?.address ?? "No Address Provided",
                      style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Rider & Action Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ASSIGNED RIDER",
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            needsRider ? Icons.person_off_rounded : Icons.two_wheeler_rounded,
                            size: 16,
                            color: needsRider ? Colors.orange[800] : const Color(0xFF059669),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            order.riderName ?? (needsRider ? "WAITING DISPATCH..." : "Assigned Rider"),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: needsRider ? Colors.orange[800] : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        "₱${order.totalAmount.toStringAsFixed(2)}",
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DeliveryDetailsScreen(order: order)),
                        ),
                        icon: Icon(needsRider ? Icons.person_add_rounded : Icons.visibility_rounded, size: 16),
                        label: Text(
                          needsRider ? "ASSIGN RIDER" : "DETAILS",
                          style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: needsRider ? const Color(0xFFE91E63) : const Color(0xFF008080),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(OrderModel order) {
    Color color = Colors.orange;
    String label = order.status.toUpperCase();

    if (order.deliveryStatus == DeliveryStatus.outForDelivery) {
      color = const Color(0xFF0284C7);
      label = "ON THE WAY";
    } else if (order.deliveryStatus == DeliveryStatus.delivered) {
      color = const Color(0xFF059669);
      label = "DELIVERED";
    } else if (order.status.toLowerCase() == 'ready') {
      color = const Color(0xFFE91E63);
      label = "READY FOR PICKUP";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
