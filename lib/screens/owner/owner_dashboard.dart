import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
  import '../../models/order_model.dart';
import '../../models/ingredient_model.dart';
import '../../models/user_model.dart';
import '../../models/system_notification_model.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/ingredient_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/dashboard_summary_card.dart';
import '../../widgets/notifications_modal_sheet.dart';
import '../../widgets/state_widgets.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _analyticsRepo = AnalyticsRepository();
  final _productRepo = ProductRepository();
  final _orderRepo = OrderRepository();

  Map<String, dynamic> _stats = {};
  List<dynamic> _lowStockItems = [];
  List<OrderModel> _pendingOnlineOrders = [];
  List<OrderModel> _activeDeliveries = [];
  List<double> _salesOverview = [];
  Map<String, int> _orderStatusSummary = {};
  List<Map<String, dynamic>> _recentActivity = [];
  int _pendingPayments = 0;
  bool _isLoading = true;
  bool _isSidebarExpanded = true;
  String? _ownerAvatarUrl;

  StreamSubscription? _onlineOrdersSub;
  StreamSubscription? _activeDeliveriesSub;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _onlineOrdersSub?.cancel();
    _activeDeliveriesSub?.cancel();
    super.dispose();
  }

  void _subscribeToRealtime() {
    _onlineOrdersSub = _orderRepo.getPendingOnlineOrdersStream().listen((orders) {
      if (mounted) {
        setState(() => _pendingOnlineOrders = orders);
        NotificationRepository().syncInventoryAndOrderAlerts(
          lowStockItems: _lowStockItems,
          pendingOrders: _pendingOnlineOrders,
        );
      }
    });
    _activeDeliveriesSub = _orderRepo.getActiveDeliveriesStream().listen((orders) {
      if (mounted) setState(() => _activeDeliveries = orders);
    });
  }

  Future<int> _loadPendingPayments(DateTime start, DateTime end) async {
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select('id')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .neq('payment_status', 'PAID');
      return (response as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> _loadRecentActivity() async {
    final client = Supabase.instance.client;
    final activities = <Map<String, dynamic>>[];

    try {
      // 1. Recent Orders
      final orders = await client
          .from('orders')
          .select('id, status, payment_status, created_at, completed_at, profiles(full_name)')
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in orders as List) {
        final status = row['status']?.toString().toLowerCase() ?? '';
        final paymentStatus = row['payment_status']?.toString().toUpperCase() ?? '';
        final userName = (row['profiles'] as Map?)?['full_name'] ?? 'Staff/Customer';

        String title = 'New order created';
        IconData icon = Icons.receipt_long;
        Color color = Colors.blue;

        if (status == 'completed') {
          title = 'Order completed';
          icon = Icons.check_circle;
          color = Colors.green;
        } else if (status == 'preparing') {
          title = 'Order prepared';
          icon = Icons.restaurant;
          color = Colors.orange;
        } else if (status == 'ready') {
          title = 'Order ready for dispatch';
          icon = Icons.check_circle_outline;
          color = Colors.purple;
        } else if (paymentStatus == 'PAID') {
          title = 'Payment received';
          icon = Icons.payments;
          color = Colors.teal;
        }

        activities.add({
          'title': title,
          'user': userName,
          'time': DateTime.tryParse(row['completed_at']?.toString() ?? '') ??
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
          'icon': icon,
          'color': color,
        });
      }

      // 2. Attendance log
      final attendance = await client
          .from('attendance')
          .select('check_in, check_out, profiles(full_name)')
          .order('check_in', ascending: false)
          .limit(5);

      for (final row in attendance as List) {
        final staffName = (row['profiles'] as Map?)?['full_name'] ?? 'Staff Member';
        activities.add({
          'title': row['check_out'] == null ? 'Employee timed in' : 'Employee timed out',
          'user': staffName,
          'time': DateTime.tryParse(
                (row['check_out'] ?? row['check_in']).toString(),
              ) ??
              DateTime.now(),
          'icon': Icons.badge,
          'color': Colors.deepPurple,
        });
      }

      // 3. Inventory movements / stock updates
      try {
        final movements = await client
            .from('inventory_movements')
            .select('created_at, movement_type, quantity_changed, ingredients(name), profiles(full_name)')
            .order('created_at', ascending: false)
            .limit(5);

        for (final row in movements as List) {
          final ingName = (row['ingredients'] as Map?)?['name'] ?? 'Ingredient';
          final staffName = (row['profiles'] as Map?)?['full_name'] ?? 'Inventory Manager';
          activities.add({
            'title': 'Stock updated ($ingName)',
            'user': staffName,
            'time': DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
            'icon': Icons.inventory_2,
            'color': Colors.amber.shade800,
          });
        }
      } catch (_) {}

      activities.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
      return activities.take(8).toList();
    } catch (_) {
      return activities;
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfWeek = startOfDay.subtract(const Duration(days: 6));

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profileRes = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('id', user.id)
            .maybeSingle();
        if (profileRes != null) {
          _ownerAvatarUrl = profileRes['avatar_url']?.toString();
        }
      }

      final results = await Future.wait([
        _analyticsRepo.getTodayPerformance(startOfDay, now.add(const Duration(days: 1))),
        _productRepo.getInventoryProducts(),
        _analyticsRepo.getSalesOverview(startOfWeek, now.add(const Duration(days: 1))),
        _analyticsRepo.getOrderStatusSummary(startOfDay, now.add(const Duration(days: 1))),
        _loadRecentActivity(),
        _loadPendingPayments(startOfDay, now.add(const Duration(days: 1))),
        IngredientRepository().getIngredients(activeOnly: true),
      ]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          final allIngredients = results[6] as List<IngredientModel>;
          _lowStockItems = allIngredients
              .where((ing) => ing.currentQuantity <= ing.reorderLevel)
              .toList();
          _salesOverview = results[2] as List<double>;
          _orderStatusSummary = results[3] as Map<String, int>;
          _recentActivity = results[4] as List<Map<String, dynamic>>;
          _pendingPayments = results[5] as int;
          _isLoading = false;
        });

        NotificationRepository().syncInventoryAndOrderAlerts(
          lowStockItems: _lowStockItems,
          pendingOrders: _pendingOnlineOrders,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await showErrorDialog(
          context,
          title: 'Dashboard Load Failed',
          message: 'Unable to load dashboard data: $e',
        );
      }
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Sign Out"),
          ],
        ),
        content: const Text("Are you sure you want to sign out of the Owner Portal?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("SIGN OUT"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.staffLogin);
    }
  }

  void _showNotifications() {
    NotificationsModalSheet.show(context, forRole: UserRole.owner);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: LoadingState());
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Owner Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: [
          StreamBuilder<List<SystemNotificationModel>>(
            stream: NotificationRepository().streamNotifications(forRole: UserRole.owner),
            builder: (context, snapshot) {
              final totalUnread = (snapshot.data ?? []).where((n) => !n.isRead).length;

              return IconButton(
                onPressed: _showNotifications,
                icon: totalUnread > 0
                    ? Badge(
                        label: Text(totalUnread > 99 ? '99+' : '$totalUnread'),
                        child: const Icon(Icons.notifications_outlined),
                      )
                    : const Icon(Icons.notifications_outlined),
              );
            },
          ),
          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, AppRoutes.ownerProfile);
              _loadDashboardData();
            },
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFFC2416C),
              backgroundImage: _ownerAvatarUrl != null && _ownerAvatarUrl!.isNotEmpty ? NetworkImage(_ownerAvatarUrl!) : null,
              child: _ownerAvatarUrl == null || _ownerAvatarUrl!.isEmpty
                  ? ClipOval(
                      child: Image.asset(
                        'assets/images/mami.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.person, size: 16, color: Colors.white),
                      ),
                    )
                  : null,
            ),
            tooltip: "Owner Profile",
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryGrid(crossAxisCount: 2),
              const SizedBox(height: 24),
              _buildDashboardContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Row(
        children: [
          _buildModernSidebar(),
          Expanded(
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 1,
                leading: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () {
                    setState(() {
                      _isSidebarExpanded = !_isSidebarExpanded;
                    });
                  },
                ),
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Bellie’s SmartServe",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Integrated Business Management System",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  StreamBuilder<List<SystemNotificationModel>>(
                    stream: NotificationRepository().streamNotifications(forRole: UserRole.owner),
                    builder: (context, snapshot) {
                      final totalUnread = (snapshot.data ?? []).where((n) => !n.isRead).length;

                      return IconButton(
                        onPressed: _showNotifications,
                        icon: totalUnread > 0
                            ? Badge(
                                label: Text(totalUnread > 99 ? '99+' : '$totalUnread'),
                                child: const Icon(Icons.notifications_outlined, color: Colors.black87),
                              )
                            : const Icon(Icons.notifications_outlined, color: Colors.black87),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.ownerProfile);
                      _loadDashboardData();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFFC2416C),
                      backgroundImage: _ownerAvatarUrl != null && _ownerAvatarUrl!.isNotEmpty ? NetworkImage(_ownerAvatarUrl!) : null,
                      child: _ownerAvatarUrl == null || _ownerAvatarUrl!.isEmpty
                          ? ClipOval(
                              child: Image.asset(
                                'assets/images/mami.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: Colors.white),
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryGrid(crossAxisCount: 4),
                    const SizedBox(height: 28),
                    _buildDashboardContent(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _isSidebarExpanded ? 250 : 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _isSidebarExpanded
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFD1DC)),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/Bellieslogo.png',
                          height: 38,
                          errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant, color: Color(0xFFC2416C), size: 32),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Bellie's",
                                style: TextStyle(
                                  color: Color(0xFF2B1A22),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                "OWNER PORTAL",
                                style: TextStyle(
                                  color: Color(0xFFC2416C),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 9,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Image.asset('assets/images/Bellieslogo.png', height: 38, errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant, color: Color(0xFFC2416C), size: 32)),
                ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sidebarItem(Icons.dashboard_rounded, "Home", active: true),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(color: Colors.grey.shade200, height: 1),
                  ),
                  _sidebarCategoryHeader("Operations"),
                  _sidebarItem(
                    Icons.shopping_bag_outlined,
                    "Online Orders",
                    badgeCount: _pendingOnlineOrders.length,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.onlineOrders),
                  ),
                  _sidebarItem(
                    Icons.restaurant_menu_rounded,
                    "Menu Hub",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.menuManagement),
                  ),
                  _sidebarItem(
                    Icons.inventory_2_outlined,
                    "Inventory Hub",
                    badgeCount: _lowStockItems.length,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.inventoryHub),
                  ),
                  _sidebarItem(
                    Icons.point_of_sale_rounded,
                    "Point of Sale",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.posOrders),
                  ),
                  _sidebarItem(
                    Icons.qr_code_2_rounded,
                    "Payment QRs",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.paymentQrs),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(color: Colors.grey.shade200, height: 1),
                  ),
                  _sidebarCategoryHeader("Staff & Attendance"),
                  _sidebarItem(
                    Icons.people_alt_outlined,
                    "Staff List",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.employees),
                  ),
                  _sidebarItem(
                    Icons.badge_outlined,
                    "Attendance",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.attendance),
                  ),
                  _sidebarItem(
                    Icons.payments_outlined,
                    "Payroll",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.payroll),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(color: Colors.grey.shade200, height: 1),
                  ),
                  _sidebarCategoryHeader("Logistics & Analytics"),
                  _sidebarItem(
                    Icons.local_shipping_outlined,
                    "Logistics",
                    badgeCount: _activeDeliveries.where((o) => o.riderId == null && o.status.toLowerCase() == 'ready').length,
                    badgeColor: Colors.orange,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryMgmt),
                  ),
                  _sidebarItem(
                    Icons.photo_library_rounded,
                    "Delivery Proofs",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.deliveryProofs),
                  ),
                  _sidebarItem(
                    Icons.star_outline_rounded,
                    "Customer Reviews",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.customerReviews),
                  ),
                  _sidebarItem(
                    Icons.bar_chart_rounded,
                    "Sales Analytics",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.analytics),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Divider(color: Colors.grey.shade200, height: 1),
                  ),
                  _sidebarCategoryHeader("System"),
                  _sidebarItem(
                    Icons.info_outline_rounded,
                    "System Info",
                    onTap: () => Navigator.pushNamed(context, AppRoutes.systemInfo),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey.shade200, height: 1),
          ),
          const SizedBox(height: 8),
          _sidebarItem(
            Icons.logout_rounded,
            "Sign Out",
            color: Colors.redAccent,
            onTap: _logout,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sidebarCategoryHeader(String title) {
    if (!_isSidebarExpanded) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.blueGrey.shade400,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _sidebarItem(
    IconData icon,
    String label, {
    bool active = false,
    Color? color,
    int? badgeCount,
    Color badgeColor = Colors.red,
    VoidCallback? onTap,
  }) {
    final activeColor = const Color(0xFFC2416C);
    final showBadge = badgeCount != null && badgeCount > 0;
    final badgeText = (badgeCount ?? 0) > 99 ? '99+' : '${badgeCount ?? 0}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFFFF0F5) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: active ? Border.all(color: const Color(0xFFFFD1DC)) : null,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      color: active ? activeColor : (color ?? const Color(0xFF64748B)),
                      size: 20,
                    ),
                    if (showBadge && !_isSidebarExpanded)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? activeColor : const Color(0xFF334155),
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showBadge) ...[
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryGrid({required int crossAxisCount}) {
    final todayRevenue = (_stats['revenue'] ?? 0.0) as double;
    final totalOrdersToday = (_stats['order_count'] ?? 0) as int;

    final cards = [
      DashboardSummaryCard(
        title: "Today's Sales",
        value: '₱${todayRevenue.toStringAsFixed(2)}',
        icon: Icons.payments,
        color: Colors.green,
      ),
      DashboardSummaryCard(
        title: 'Total Orders Today',
        value: '$totalOrdersToday',
        icon: Icons.receipt_long,
        color: Colors.blue,
      ),
      DashboardSummaryCard(
        title: 'Pending Online Orders',
        value: '${_pendingOnlineOrders.length}',
        icon: Icons.cloud_download,
        color: Colors.indigo,
        onTap: () => Navigator.pushNamed(context, AppRoutes.onlineOrders),
      ),
      DashboardSummaryCard(
        title: 'Low-Stock Products',
        value: '${_lowStockItems.length}',
        icon: Icons.inventory_2_outlined,
        color: Colors.orange,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 82,
      ),
      itemBuilder: (context, index) => cards[index],
    );
  }

  Widget _buildPendingOnlineOrdersPanel() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      color: const Color(0xFFF0F7FF),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_download_rounded, color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      "Pending Online Orders (${_pendingOnlineOrders.length})",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.onlineOrders),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text("View All"),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._pendingOnlineOrders.take(3).map((o) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFC2416C).withAlpha(30),
                    child: const Icon(Icons.person, color: Color(0xFFC2416C), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.customerDetails?.name ?? "Online Customer",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          "₱${o.totalAmount.toStringAsFixed(2)} • ${o.items.length} items • ${o.customerDetails?.fullAddress ?? 'No Address'}",
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.onlineOrders),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2416C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text("VERIFY"),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pendingOnlineOrders.isNotEmpty) ...[
          _buildPendingOnlineOrdersPanel(),
          const SizedBox(height: 28),
        ],
        // 1. Sales Overview
        _buildSectionTitle('Sales Overview'),
        const SizedBox(height: 12),
        _buildSalesChart(),
        const SizedBox(height: 28),

        // 2. Order Status Summary
        _buildSectionTitle('Order Status Summary'),
        const SizedBox(height: 12),
        _buildOrderStatusSummary(),
        const SizedBox(height: 28),

        // 3. Recent Activity & Important Alerts
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  _buildRecentActivity(),
                  const SizedBox(height: 24),
                  _buildAlerts(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRecentActivity()),
                const SizedBox(width: 24),
                Expanded(child: _buildAlerts()),
              ],
            );
          },
        ),

      ],
    );
  }

  Widget _buildSalesChart() {
    final totalWeeklySales = _salesOverview.fold<double>(0, (sum, val) => sum + val);
    final maxValue = _salesOverview.fold<double>(
      0,
      (max, value) => value > max ? value : max,
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '7-Day Sales Trend',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2416C).withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Total: ₱${totalWeeklySales.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC2416C),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: _salesOverview.isEmpty
                  ? const Center(child: Text('No sales data available for this period.', style: TextStyle(color: Colors.grey)))
                  : Column(
                      children: [
                        Expanded(
                          child: CustomPaint(
                            painter: _SalesChartPainter(
                              values: _salesOverview,
                              maxValue: maxValue,
                              color: const Color(0xFFC2416C),
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            _salesOverview.length,
                            (index) {
                              final date = DateTime.now().subtract(
                                Duration(days: _salesOverview.length - 1 - index),
                              );
                              return Text(
                                DateFormat('E').format(date),
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                              );
                            },
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

  Widget _buildOrderStatusSummary() {
    final statuses = [
      ('Pending', Icons.schedule_rounded, Colors.orange, 'pending'),
      ('Preparing', Icons.restaurant_rounded, Colors.blue, 'preparing'),
      ('Ready', Icons.check_circle_outline_rounded, Colors.purple, 'ready'),
      ('Completed', Icons.done_all_rounded, Colors.green, 'completed'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: statuses.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (context, index) {
        final item = statuses[index];
        final count = _orderStatusSummary[item.$4] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: item.$3.withAlpha(8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.$3.withAlpha(25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: item.$3.withAlpha(5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: item.$3.withAlpha(20),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(item.$2, color: item.$3, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: item.$3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return _dashboardPanel(
      title: 'Recent Activity',
      child: _recentActivity.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No recent system activity.', style: TextStyle(color: Colors.grey))),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentActivity.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final activity = _recentActivity[index];
                final color = activity['color'] as Color;
                final date = activity['time'] as DateTime;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withAlpha(38),
                    child: Icon(
                      activity['icon'] as IconData,
                      size: 16,
                      color: color,
                    ),
                  ),
                  title: Text(
                    activity['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${activity['user']} · ${DateFormat('MMM d, h:mm a').format(date)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildAlerts() {
    final alerts = <Map<String, dynamic>>[
      if (_lowStockItems.isNotEmpty)
        {
          'title': '${_lowStockItems.length} Low-Stock Product(s)',
          'subtitle': 'Review inventory stock levels immediately',
          'icon': Icons.inventory_2_outlined,
          'color': Colors.orange,
          'route': AppRoutes.inventoryHub,
        },
      if (_pendingOnlineOrders.isNotEmpty)
        {
          'title': '${_pendingOnlineOrders.length} Pending Online Order(s)',
          'subtitle': 'Payment verification or order confirmation required',
          'icon': Icons.cloud_download_outlined,
          'color': Colors.blue,
          'route': AppRoutes.onlineOrders,
        },
      if (_activeDeliveries.any(
        (order) =>
            order.deliveryStatus != DeliveryStatus.delivered &&
            DateTime.now().difference(order.timestamp).inMinutes > 45,
      ))
        {
          'title': 'Delayed Deliveries',
          'subtitle': 'One or more orders in transit for over 45 minutes',
          'icon': Icons.local_shipping_outlined,
          'color': Colors.deepOrange,
          'route': AppRoutes.deliveryMgmt,
        },
      if (_pendingPayments > 0)
        {
          'title': '$_pendingPayments Pending / Unverified Payment(s)',
          'subtitle': 'Orders waiting for payment confirmation',
          'icon': Icons.report_problem_outlined,
          'color': Colors.red,
          'route': AppRoutes.onlineOrders,
        },
    ];

    return _dashboardPanel(
      title: 'Important Alerts',
      child: alerts.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('No critical alerts at this time.', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final color = alert['color'] as Color;

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: color.withAlpha(38),
                    child: Icon(alert['icon'] as IconData, color: color, size: 18),
                  ),
                  title: Text(
                    alert['title'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    alert['subtitle'] as String,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: alert['route'] != null
                      ? () => Navigator.pushNamed(context, alert['route'] as String)
                      : null,
                );
              },
            ),
    );
  }

  Widget _dashboardPanel({required String title, required Widget child}) {
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFC2416C),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFFFF0F5)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/Bellieslogo.png', height: 48, errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant, color: Color(0xFFC2416C), size: 40)),
                const SizedBox(height: 10),
                const Text(
                  "Bellie's SmartServe",
                  style: TextStyle(
                    color: Color(0xFF2B1A22),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Text(
                  "Owner Management Portal",
                  style: TextStyle(
                    color: Color(0xFF7A6670),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard_rounded, color: Color(0xFFC2416C)),
                  title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(height: 1),
                _drawerHeaderCategory("Operations"),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_outlined),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Online Orders"),
                      if (_pendingOnlineOrders.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _pendingOnlineOrders.length > 99 ? '99+' : '${_pendingOnlineOrders.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.onlineOrders);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restaurant_menu_rounded),
                  title: const Text("Menu Hub"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.menuManagement);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text("Inventory Hub"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.inventoryHub);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.point_of_sale_rounded),
                  title: const Text("Point of Sale"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.posOrders);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const Text("Payment QRs"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.paymentQrs);
                  },
                ),
                const Divider(height: 1),
                _drawerHeaderCategory("Staff & Attendance"),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text("Staff List"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.employees);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: Colors.blue),
                  title: const Text("RFID Attendance"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.attendance);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined, color: Colors.green),
                  title: const Text("Daily Wage Payroll"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.payroll);
                  },
                ),
                const Divider(height: 1),
                _drawerHeaderCategory("Logistics & Analytics"),
                ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Logistics"),
                      if (_activeDeliveries.any((o) => o.riderId == null && o.status.toLowerCase() == 'ready'))
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_activeDeliveries.where((o) => o.riderId == null && o.status.toLowerCase() == 'ready').length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.deliveryMgmt);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text("Delivery Proofs"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.deliveryProofs);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart_rounded),
                  title: const Text("Sales Analytics"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.analytics);
                  },
                ),
                const Divider(height: 1),
                _drawerHeaderCategory("System"),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text("System Info"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.systemInfo);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                label: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerHeaderCategory(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SalesChartPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color color;

  const _SalesChartPainter({
    required this.values,
    required this.maxValue,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.withAlpha(38)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withAlpha(90), color.withAlpha(0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    // Draw grid horizontal lines
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
      // Leave top padding for point circles
      final y = size.height - (size.height * 0.85 * ratio) - 8;
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = color;
    final dotBorderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 5, dotBorderPaint);
      canvas.drawCircle(point, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.color != color;
  }
}
