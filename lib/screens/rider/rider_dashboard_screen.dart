import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/system_notification_model.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/rider_dashboard_repository.dart';
import '../../core/responsive_layout.dart';
import '../../widgets/notifications_modal_sheet.dart';
import '../../widgets/state_widgets.dart';
import 'active_delivery_screen.dart';
import 'rider_history_screen.dart';
import 'rider_profile_screen.dart';

class RiderDashboardShell extends StatefulWidget {
  const RiderDashboardShell({super.key});

  @override
  State<RiderDashboardShell> createState() => _RiderDashboardShellState();
}

class _RiderDashboardShellState extends State<RiderDashboardShell> {
  int _selectedIndex = 0;
  final String _riderId = Supabase.instance.client.auth.currentUser!.id;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      RiderDashboardMain(riderId: _riderId),
      RiderHistoryScreen(riderId: _riderId),
      RiderProfileScreen(riderId: _riderId),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: const Color(0xFFC2416C),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
      desktop: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => _selectedIndex = index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: const IconThemeData(color: Color(0xFFC2416C)),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.history),
                  label: Text('History'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: _screens,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderDashboardMain extends StatefulWidget {
  final String riderId;
  const RiderDashboardMain({super.key, required this.riderId});

  @override
  State<RiderDashboardMain> createState() => _RiderDashboardMainState();
}

class _RiderDashboardMainState extends State<RiderDashboardMain> {
  final _repo = RiderDashboardRepository();
  bool _isOnline = true;
  static final Set<String> _startedNavigations = {};

  @override
  void initState() {
    super.initState();
    _loadOnlineStatus();
  }

  Future<void> _loadOnlineStatus() async {
    try {
      final profile = await _repo.getRiderProfile(widget.riderId);
      if (mounted) {
        setState(() {
          _isOnline = profile.isOnline;
        });
      }
    } catch (e) {
      debugPrint("Error loading rider online status: $e");
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    final previousValue = _isOnline;
    setState(() => _isOnline = value);
    try {
      await _repo.toggleOnlineStatus(widget.riderId, value);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isOnline = previousValue);
      await showErrorDialog(
        context,
        title: 'Unable to Change Availability',
        message: 'Your online status could not be updated: $error',
      );
    }
  }

  Future<void> _pickUpOrder(
    OrderModel order, {
    required bool hasActiveDelivery,
    String? activeOrderNumber,
  }) async {
    if (hasActiveDelivery) {
      await showErrorDialog(
        context,
        title: 'Active Delivery in Progress',
        message:
            'You currently have an ongoing delivery (#${activeOrderNumber ?? ''}). Please deliver and complete your active order before picking up a new one.',
      );
      return;
    }

    try {
      await _repo.updateDeliveryStatus(order.id, 'outForDelivery');
    } catch (error) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: 'Unable to Pick Up Order',
        message: 'Order #${order.queueNumber} could not be picked up: $error',
      );
    }
  }

  void _showNotificationsSheet() {
    NotificationsModalSheet.show(context, forRole: UserRole.rider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Image.asset('assets/images/Bellieslogo.png', height: 40),
        centerTitle: false,
        actions: [
          Row(
            children: [
              Text(
                _isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: _isOnline ? Colors.green : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: _isOnline,
                onChanged: _toggleOnlineStatus,
                activeThumbColor: Colors.green,
              ),
            ],
          ),
          StreamBuilder<List<SystemNotificationModel>>(
            stream: NotificationRepository().streamNotifications(forRole: UserRole.rider),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.where((n) => !n.isRead).length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: _showNotificationsSheet,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _repo.streamRiderDeliveries(widget.riderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }
          if (!snapshot.hasData) return const LoadingState();

          final orders = snapshot.data!;
          final pending = orders
              .where((o) => o.deliveryStatus == DeliveryStatus.readyForDelivery)
              .toList();
          final active = orders
              .where((o) => o.deliveryStatus == DeliveryStatus.outForDelivery)
              .toList();
          final completed = orders
              .where((o) => o.deliveryStatus == DeliveryStatus.delivered)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(
                  pending.length,
                  active.length,
                  completed.length,
                ),
                const SizedBox(height: 24),
                if (active.isNotEmpty) ...[
                  _sectionTitle("Active Delivery"),
                  const SizedBox(height: 12),
                  _buildActiveOrderCard(active.first),
                  const SizedBox(height: 24),
                ],
                _sectionTitle("Upcoming Pickups"),
                const SizedBox(height: 12),
                if (pending.isEmpty)
                  const EmptyState(message: "No orders ready for pickup.")
                else
                  ...pending.map((o) => _buildOrderCard(
                        o,
                        hasActiveDelivery: active.isNotEmpty,
                        activeOrderNumber:
                            active.isNotEmpty ? active.first.queueNumber : null,
                      )),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCards(int pending, int active, int completed) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isDesktop ? 2.5 : 1.5,
      children: [
        _summaryCard("Pending", pending.toString(), Colors.orange, Icons.timer),
        _summaryCard(
          "Active",
          active.toString(),
          Colors.blue,
          Icons.local_shipping,
        ),
        _summaryCard(
          "Done Today",
          completed.toString(),
          Colors.green,
          Icons.check_circle,
        ),
        _summaryCard(
          "Earnings",
          "₱0.00",
          const Color(0xFFD4AF37),
          Icons.payments,
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Card(
      elevation: 0,
      color: color.withAlpha((0.1 * 255).toInt()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: color.withAlpha((0.2 * 255).toInt())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderCard(OrderModel order) {
    final bool hasStarted = _startedNavigations.contains(order.id);
    final String buttonText = hasStarted ? "RESUME NAVIGATION" : "START NAVIGATION";

    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withAlpha((0.2 * 255).toInt()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.blue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.navigation, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerDetails?.name ?? "Customer",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        order.customerDetails?.address ?? "Address",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  "₱${order.totalAmount.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                setState(() => _startedNavigations.add(order.id));
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActiveDeliveryScreen(order: order),
                  ),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.navigation_outlined, size: 20),
              label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    OrderModel order, {
    required bool hasActiveDelivery,
    String? activeOrderNumber,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ORDER #${order.queueNumber}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                _statusBadge(order.deliveryStatus!),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              order.customerDetails?.name ?? "Customer",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              order.customerDetails?.address ?? "No Address",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActiveDeliveryScreen(order: order),
                      ),
                    ),
                    child: const Text("DETAILS"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickUpOrder(
                      order,
                      hasActiveDelivery: hasActiveDelivery,
                      activeOrderNumber: activeOrderNumber,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasActiveDelivery ? Colors.grey : const Color(0xFFC2416C),
                    ),
                    child: Text(hasActiveDelivery ? "LOCKED" : "PICK UP"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF333333),
      ),
    );
  }

  Widget _statusBadge(DeliveryStatus status) {
    Color color = Colors.orange;
    if (status == DeliveryStatus.readyForDelivery) color = Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
