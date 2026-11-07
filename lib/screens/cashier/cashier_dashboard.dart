import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/web_url_observer.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../repositories/analytics_repository.dart';
import '../../repositories/order_repository.dart';
import '../../widgets/dashboard_summary_card.dart';
import '../../widgets/notifications_modal_sheet.dart';
import '../../widgets/state_widgets.dart';
import '../delivery/delivery_list_screen.dart';
import '../owner/online_orders_screen.dart';
import '../auth/staff_profile_screen.dart';
import 'pos_screen.dart';

enum CashierSection {
  dashboard,
  pos,
  onlineOrders,
  delivery,
  orderHistory,
  receipts,
  notifications,
  profile,
}

void _retryCashierPage(BuildContext context) {
  context.findAncestorStateOfType<_CashierDashboardState>()?.retryPage();
}

void _selectCashierSection(BuildContext context, CashierSection section) {
  context.findAncestorStateOfType<_CashierDashboardState>()?._selectSection(section);
}

class CashierDashboard extends StatefulWidget {
  final CashierSection initialSection;

  const CashierDashboard({
    super.key,
    this.initialSection = CashierSection.dashboard,
  });

  @override
  State<CashierDashboard> createState() => _CashierDashboardState();
}

class _CashierDashboardState extends State<CashierDashboard> {
  late CashierSection _selectedSection;
  bool _sidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
  }

  void retryPage() {
    if (mounted) setState(() {});
  }

  CashierNavigationItem get _currentItem => cashierNavigationItems.firstWhere(
    (item) => item.section == _selectedSection,
    orElse: () => cashierNavigationItems.first,
  );

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'Your cashier session will be signed out on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.staffLogin,
      (route) => false,
    );
  }

  String? _routeForSection(CashierSection section) {
    switch (section) {
      case CashierSection.dashboard:
        return AppRoutes.cashierDashboard;
      case CashierSection.pos:
        return AppRoutes.staffPos;
      case CashierSection.onlineOrders:
        return AppRoutes.staffOnlineOrders;
      case CashierSection.delivery:
        return AppRoutes.staffDeliveries;
      case CashierSection.orderHistory:
        return AppRoutes.posOrders;
      case CashierSection.receipts:
        return '/staff/receipts';
      case CashierSection.notifications:
        return '/staff/notifications';
      case CashierSection.profile:
        return AppRoutes.staffProfile;
    }
  }

  void _selectSection(CashierSection section) {
    setState(() => _selectedSection = section);
    final routeName = _routeForSection(section);
    if (routeName != null) {
      updateBrowserUrl(routeName);
    }
    if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case CashierSection.dashboard:
        return const _CashierHomePage();
      case CashierSection.pos:
        return const PosScreen(showAppBar: false);
      case CashierSection.onlineOrders:
        return const OnlineOrdersScreen(showAppBar: false);
      case CashierSection.delivery:
        return const DeliveryListScreen(showAppBar: false);
      case CashierSection.orderHistory:
        return const _CashierOrderListPage(
          title: 'Order History',
          subtitle: 'Recently completed orders',
        );
      case CashierSection.receipts:
        return const _CashierOrderListPage(
          title: 'Receipts',
          subtitle: 'Open a completed order to view its receipt',
          showReceiptAction: true,
        );
      case CashierSection.notifications:
        return const _CashierNotificationsPage();
      case CashierSection.profile:
        return const StaffProfileScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _currentItem.label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0xFFF1F5F9),
            height: 1,
          ),
        ),
        leading: isDesktop
            ? IconButton(
                tooltip: _sidebarCollapsed ? 'Expand menu' : 'Collapse menu',
                onPressed: () =>
                    setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                icon: Icon(
                  _sidebarCollapsed ? Icons.menu : Icons.menu_open,
                  color: const Color(0xFFE91E63),
                ),
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFFE91E63)),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        actions: [
          StreamBuilder<List<OrderModel>>(
            stream: OrderRepository().getPendingOnlineOrdersStream(),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () =>
                        _selectSection(CashierSection.notifications),
                    icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF334155)),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            tooltip: 'My Profile',
            onPressed: () => _selectSection(CashierSection.profile),
            icon: const Icon(Icons.account_circle_outlined, color: Color(0xFF334155)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              child: SafeArea(
                child: _CashierSidebar(
                  selected: _selectedSection,
                  collapsed: false,
                  onSelected: _selectSection,
                  onLogout: _confirmLogout,
                ),
              ),
            ),
      body: Row(
        children: [
          if (isDesktop)
            _CashierSidebar(
              selected: _selectedSection,
              collapsed: _sidebarCollapsed,
              onSelected: _selectSection,
              onLogout: _confirmLogout,
            ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }
}

class CashierNavigationItem {
  final CashierSection section;
  final String label;
  final IconData icon;

  const CashierNavigationItem(this.section, this.label, this.icon);
}

const cashierNavigationItems = [
  CashierNavigationItem(
    CashierSection.dashboard,
    'Dashboard',
    Icons.dashboard_outlined,
  ),
  CashierNavigationItem(
    CashierSection.pos,
    'POS',
    Icons.point_of_sale_outlined,
  ),
  CashierNavigationItem(
    CashierSection.onlineOrders,
    'Online Orders',
    Icons.shopping_bag_outlined,
  ),
  CashierNavigationItem(
    CashierSection.delivery,
    'Logistics & Riders',
    Icons.local_shipping_outlined,
  ),
  CashierNavigationItem(
    CashierSection.orderHistory,
    'Order History',
    Icons.history_outlined,
  ),
  CashierNavigationItem(
    CashierSection.receipts,
    'Receipts',
    Icons.receipt_long_outlined,
  ),
];

class _CashierSidebar extends StatelessWidget {
  final CashierSection selected;
  final bool collapsed;
  final ValueChanged<CashierSection> onSelected;
  final VoidCallback onLogout;

  const _CashierSidebar({
    required this.selected,
    required this.collapsed,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: SizedBox(
        width: collapsed ? 84 : 250,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: collapsed
                  ? Image.asset('assets/images/Bellieslogo.png', height: 42)
                  : Row(
                      children: [
                        Image.asset(
                          'assets/images/Bellieslogo.png',
                          height: 46,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Bellie's\nSmartServe",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                children: [
                  for (final item in cashierNavigationItems)
                    _SidebarItem(
                      item: item,
                      selected: selected == item.section,
                      collapsed: collapsed,
                      onTap: () => onSelected(item.section),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _CashierProfilePreview(collapsed: collapsed),
            _SidebarItem(
              item: const CashierNavigationItem(
                CashierSection.dashboard,
                'Logout',
                Icons.logout,
              ),
              selected: false,
              collapsed: collapsed,
              onTap: onLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final CashierNavigationItem item;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: collapsed ? item.label : '',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 12 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFFFF0F5) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: const Color(0xFFE91E63).withAlpha(80), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                if (selected && !collapsed)
                  Container(
                    width: 3.5,
                    height: 18,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: selected ? const Color(0xFFE91E63) : const Color(0xFF64748B),
                    ),
                    if (collapsed &&
                        (item.section == CashierSection.onlineOrders ||
                            item.section == CashierSection.notifications))
                      const Positioned(
                        right: -6,
                        top: -6,
                        child: _OnlineOrderBadge(mini: true),
                      ),
                    if (collapsed && item.section == CashierSection.delivery)
                      const Positioned(
                        right: -6,
                        top: -6,
                        child: _DeliveryBadge(mini: true),
                      ),
                  ],
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        color: selected ? const Color(0xFFE91E63) : const Color(0xFF334155),
                      ),
                    ),
                  ),
                  if (item.section == CashierSection.onlineOrders ||
                      item.section == CashierSection.notifications)
                    const _OnlineOrderBadge(),
                  if (item.section == CashierSection.delivery)
                    const _DeliveryBadge(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineOrderBadge extends StatelessWidget {
  final bool mini;
  const _OnlineOrderBadge({this.mini = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: OrderRepository().getPendingOnlineOrdersStream(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        final badgeText = count > 99 ? '99+' : '$count';

        if (mini) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.red,
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
          );
        }

        return Container(
          constraints: const BoxConstraints(minWidth: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badgeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

class _DeliveryBadge extends StatelessWidget {
  final bool mini;
  const _DeliveryBadge({this.mini = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: OrderRepository().getActiveDeliveriesStream(),
      builder: (context, snapshot) {
        final count = (snapshot.data ?? [])
            .where((o) => o.riderId == null && o.status.toLowerCase() == 'ready')
            .length;
        if (count == 0) return const SizedBox.shrink();
        final badgeText = count > 99 ? '99+' : '$count';

        if (mini) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange,
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
          );
        }

        return Container(
          constraints: const BoxConstraints(minWidth: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            badgeText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

Future<UserModel?> _fetchCurrentCashierProfile() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || user.isAnonymous) return null;
  try {
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (data != null) {
      return UserModel.fromJson(data);
    }

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      fullName: user.userMetadata?['full_name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          user.email?.split('@').first ??
          'Cashier',
      position: 'Cashier Staff',
      role: UserRole.cashier,
      accountStatus: AccountStatus.active,
    );
  } catch (_) {
    return null;
  }
}

class _CashierProfilePreview extends StatelessWidget {
  final bool collapsed;

  const _CashierProfilePreview({required this.collapsed});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final bool hasSession = user != null && !user.isAnonymous;

    return FutureBuilder<UserModel?>(
      future: _fetchCurrentCashierProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final email = profile?.email.isNotEmpty == true
            ? profile!.email
            : (user?.email ?? '');

        final name = profile?.fullName ??
            user?.userMetadata?['full_name']?.toString() ??
            (email.isNotEmpty ? email.split('@').first : 'Cashier Staff');

        final sub = hasSession
            ? (email.isNotEmpty ? email : 'CASHIER STAFF')
            : 'Please log in again';

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: hasSession ? const Color(0xFFE91E63) : Colors.grey,
                backgroundImage: profile?.avatarUrl == null
                    ? null
                    : NetworkImage(profile!.avatarUrl!),
                child: profile?.avatarUrl == null
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasSession ? Colors.grey[600] : Colors.red,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CashierHomePage extends StatelessWidget {
  const _CashierHomePage();

  DateTime get _startOfToday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final end = _startOfToday.add(const Duration(days: 1));
    final orderRepo = OrderRepository();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient Welcome Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE91E63),
                  Color(0xFFC2185B),
                  Color(0xFF880E4F),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withAlpha(80),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<UserModel?>(
                        future: _fetchCurrentCashierProfile(),
                        builder: (context, snapshot) {
                          final fullName = snapshot.data?.fullName.trim() ?? '';
                          final firstName = fullName.isNotEmpty
                              ? fullName.split(' ').first
                              : 'Cashier';
                          return Text(
                            'Good day, $firstName 👋',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Live Cashier Terminal & Real-Time Order Operations',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withAlpha(220),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectCashierSection(context, CashierSection.pos),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: Text(
                    "OPEN POS SALE",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      fontSize: 12,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, dynamic>>(
            future: AnalyticsRepository().getTodayPerformance(
              _startOfToday,
              end,
            ),
            builder: (context, snapshot) {
              final data = snapshot.data;
              final revenue = data?['revenue'] as num?;
              final orders = data?['order_count'] as num?;
              return StreamBuilder<List<OrderModel>>(
                stream: orderRepo.getReadyOrdersStream(),
                builder: (context, readySnapshot) {
                  return StreamBuilder<List<OrderModel>>(
                    stream: orderRepo.getPendingOnlineOrdersStream(),
                    builder: (context, onlineSnapshot) {
                      final cards = [
                        DashboardSummaryCard(
                          title: "Today's Sales",
                          value: revenue == null
                              ? 'Unavailable'
                              : '₱${revenue.toStringAsFixed(2)}',
                          icon: Icons.payments_outlined,
                          color: AppColors.primary,
                        ),
                        DashboardSummaryCard(
                          title: 'Orders Today',
                          value: orders?.toString() ?? 'Unavailable',
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.info,
                        ),
                        DashboardSummaryCard(
                          title: 'Ready to Serve',
                          value: readySnapshot.hasData
                              ? readySnapshot.data!.length.toString()
                              : 'Unavailable',
                          icon: Icons.room_service_outlined,
                          color: AppColors.success,
                        ),
                        DashboardSummaryCard(
                          title: 'Online Orders',
                          value: onlineSnapshot.hasData
                              ? onlineSnapshot.data!.length.toString()
                              : 'Unavailable',
                          icon: Icons.shopping_bag_outlined,
                          color: AppColors.warning,
                          onTap: () => _selectCashierSection(context, CashierSection.onlineOrders),
                        ),
                      ];
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1000
                              ? 4
                              : constraints.maxWidth >= 600
                              ? 2
                              : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: cards.length,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 88,
                            ),
                            itemBuilder: (context, index) => cards[index],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 28),
          _DashboardSection(
            title: 'Ready to Serve',
            subtitle: 'Paid orders waiting for customer handoff',
            child: StreamBuilder<List<OrderModel>>(
              stream: orderRepo.getReadyOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(
                    error: snapshot.error.toString(),
                    onRetry: () => _retryCashierPage(context),
                  );
                }
                if (!snapshot.hasData) return const LoadingState();
                if (snapshot.data!.isEmpty) {
                  return const EmptyState(message: 'No orders ready to serve.');
                }
                return _ReadyOrdersList(orders: snapshot.data!);
              },
            ),
          ),
          const SizedBox(height: 24),
          _DashboardSection(
            title: 'Pending Online Orders',
            subtitle: 'Delivery orders awaiting payment verification',
            child: StreamBuilder<List<OrderModel>>(
              stream: orderRepo.getPendingOnlineOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorState(
                    error: snapshot.error.toString(),
                    onRetry: () => _retryCashierPage(context),
                  );
                }
                if (!snapshot.hasData) return const LoadingState();
                if (snapshot.data!.isEmpty) {
                  return const EmptyState(message: 'No pending online orders.');
                }
                return _PendingOnlineOrdersList(
                  orders: snapshot.data!,
                  onOpenOnlineOrders: () => _selectCashierSection(context, CashierSection.onlineOrders),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _DashboardSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12.5),
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ReadyOrdersList extends StatefulWidget {
  final List<OrderModel> orders;

  const _ReadyOrdersList({required this.orders});

  @override
  State<_ReadyOrdersList> createState() => _ReadyOrdersListState();
}

class _ReadyOrdersListState extends State<_ReadyOrdersList> {
  final _orderRepo = OrderRepository();
  final Set<String> _locallyServedIds = {};
  String? _servingOrderId;

  Future<void> _markServed(OrderModel order) async {
    if (_servingOrderId != null) return;
    setState(() {
      _servingOrderId = order.id;
      _locallyServedIds.add(order.id);
    });
    try {
      await _orderRepo.updateOrderStatus(order.id, 'completed');
      if (!mounted) return;
      setState(() {
        _servingOrderId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order #${order.queueNumber} served.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locallyServedIds.remove(order.id);
        _servingOrderId = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to serve order: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final counterOrders = widget.orders
        .where((o) => o.serviceType != ServiceType.delivery && !_locallyServedIds.contains(o.id))
        .toList();
    final deliveryOrders = widget.orders
        .where((o) => o.serviceType == ServiceType.delivery && !_locallyServedIds.contains(o.id))
        .toList();

    if (counterOrders.isEmpty && deliveryOrders.isEmpty) {
      return const EmptyState(message: 'No orders ready to serve.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (counterOrders.isNotEmpty) ...[
          for (final order in counterOrders.take(5))
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.green.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE8F5E9),
                      radius: 20,
                      child: Text(
                        order.queueNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Order #${order.queueNumber}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.items.length} item(s) • ${order.serviceType.name.toUpperCase()}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _servingOrderId == order.id ? null : () => _markServed(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _servingOrderId == order.id
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text(
                              'SERVE COUNTER',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        if (deliveryOrders.isNotEmpty) ...[
          if (counterOrders.isNotEmpty) const Divider(height: 24),
          Text(
            "Ready for Delivery Dispatch:",
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEF6C00)),
          ),
          const SizedBox(height: 8),
          for (final order in deliveryOrders.take(5))
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.orange.shade200, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFFFF3E0),
                      radius: 20,
                      child: const Icon(Icons.local_shipping_outlined, color: Color(0xFFEF6C00), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Delivery Order #${order.queueNumber}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${order.items.length} item(s) • ${order.customerDetails?.address.isNotEmpty == true ? order.customerDetails!.address : "Laguna Area"}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _selectCashierSection(context, CashierSection.delivery),
                      icon: const Icon(Icons.local_shipping_rounded, size: 14),
                      label: const Text('DISPATCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF6C00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _PendingOnlineOrdersList extends StatelessWidget {
  final List<OrderModel> orders;
  final VoidCallback onOpenOnlineOrders;

  const _PendingOnlineOrdersList({
    required this.orders,
    required this.onOpenOnlineOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final order in orders.take(5))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD1DC)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE91E63),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              title: Text(
                order.customerDetails?.name ?? "Online Customer",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                "₱${order.totalAmount.toStringAsFixed(2)} • ${order.items.length} item(s) • ${order.customerDetails?.fullAddress ?? 'Sta. Cruz, Laguna'}",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: ElevatedButton.icon(
                onPressed: onOpenOnlineOrders,
                icon: const Icon(Icons.verified_user_outlined, size: 16),
                label: const Text("VERIFY"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onOpenOnlineOrders,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text("OPEN ONLINE ORDERS (${orders.length})"),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE91E63),
              side: const BorderSide(color: Color(0xFFE91E63)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _CashierOrderListPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool showReceiptAction;

  const _CashierOrderListPage({
    required this.title,
    required this.subtitle,
    this.showReceiptAction = false,
  });

  @override
  State<_CashierOrderListPage> createState() => _CashierOrderListPageState();
}

class _CashierOrderListPageState extends State<_CashierOrderListPage> {
  DateTime? _selectedDate;
  String _searchQuery = '';
  String _dateFilterMode = 'ALL'; // 'ALL', 'TODAY', 'YESTERDAY', 'THIS_WEEK', 'CUSTOM'

  Future<void> _pickCalendarDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFE91E63),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
              secondary: Color(0xFFFFD700),
            ),
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 12,
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFFE91E63),
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              headerHelpStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFD700),
              ),
              dayStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE91E63),
              ),
              yearStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              confirmButtonStyle: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateFilterMode = 'CUSTOM';
      });
    }
  }

  bool _matchesDateFilter(DateTime orderDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_dateFilterMode == 'TODAY') {
      final date = DateTime(orderDate.year, orderDate.month, orderDate.day);
      return date == today;
    } else if (_dateFilterMode == 'YESTERDAY') {
      final yesterday = today.subtract(const Duration(days: 1));
      final date = DateTime(orderDate.year, orderDate.month, orderDate.day);
      return date == yesterday;
    } else if (_dateFilterMode == 'THIS_WEEK') {
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      return orderDate.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
    } else if (_dateFilterMode == 'CUSTOM' && _selectedDate != null) {
      final target = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      final date = DateTime(orderDate.year, orderDate.month, orderDate.day);
      return date == target;
    }

    return true; // 'ALL'
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final orderDate = DateTime(date.year, date.month, date.day);

    if (orderDate == today) {
      return 'Today (${DateFormat("MMM dd, yyyy").format(date)})';
    } else if (orderDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday (${DateFormat("MMM dd, yyyy").format(date)})';
    } else {
      return DateFormat('EEEE, MMM dd, yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = OrderRepository().getCompletedOrdersStream();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Header Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                widget.subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),

        // Filter Bar with Calendar Picker & Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;

              final searchWidget = TextField(
                decoration: InputDecoration(
                  hintText: "Search queue # or customer name...",
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              );

              final filterButtonsWidget = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _filterChip('ALL', 'All Dates'),
                  _filterChip('TODAY', 'Today'),
                  _filterChip('YESTERDAY', 'Yesterday'),
                  _filterChip('THIS_WEEK', 'This Week'),
                  ElevatedButton.icon(
                    onPressed: _pickCalendarDate,
                    icon: const Icon(Icons.calendar_month_rounded, size: 16),
                    label: Text(
                      _dateFilterMode == 'CUSTOM' && _selectedDate != null
                          ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                          : 'Pick Date 📅',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _dateFilterMode == 'CUSTOM' ? const Color(0xFFE91E63) : Colors.grey[200],
                      foregroundColor: _dateFilterMode == 'CUSTOM' ? Colors.white : const Color(0xFF334155),
                      elevation: _dateFilterMode == 'CUSTOM' ? 2 : 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchWidget,
                    const SizedBox(height: 10),
                    filterButtonsWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchWidget),
                  const SizedBox(width: 12),
                  filterButtonsWidget,
                ],
              );
            },
          ),
        ),

        // Order List Grouped by Date
        Expanded(
          child: StreamBuilder<List<OrderModel>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  error: snapshot.error.toString(),
                  onRetry: () => _retryCashierPage(context),
                );
              }
              if (!snapshot.hasData) return const LoadingState();

              var orders = snapshot.data!;

              // Apply Smart Search Filter (handles # symbol, leading zeros, and customer names)
              if (_searchQuery.trim().isNotEmpty) {
                final rawQ = _searchQuery.toLowerCase().trim();
                final cleanQ = rawQ.replaceAll('#', '').trim();
                orders = orders.where((o) {
                  final name = (o.customerDetails?.name ?? '').toLowerCase();
                  final queue = o.queueNumber.toLowerCase();
                  final id = o.id.toLowerCase();
                  final queueNoInt = int.tryParse(queue) ?? -1;
                  final searchInt = int.tryParse(cleanQ) ?? -2;

                  return name.contains(rawQ) ||
                      name.contains(cleanQ) ||
                      queue.contains(cleanQ) ||
                      (searchInt > 0 && queueNoInt == searchInt) ||
                      id.contains(cleanQ);
                }).toList();
              }

              // Apply Date Filter
              orders = orders.where((o) => _matchesDateFilter(o.timestamp)).toList();

              if (orders.isEmpty) {
                return const EmptyState(
                  message: 'No completed records matching filters.',
                );
              }

              // Group orders by Date
              final Map<String, List<OrderModel>> grouped = {};
              for (var order in orders) {
                final header = _getDateHeader(order.timestamp);
                grouped.putIfAbsent(header, () => []).add(order);
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                itemCount: grouped.keys.length,
                itemBuilder: (context, sectionIndex) {
                  final sectionTitle = grouped.keys.elementAt(sectionIndex);
                  final sectionOrders = grouped[sectionTitle]!;
                  final sectionTotal = sectionOrders.fold<double>(0, (sum, o) => sum + o.totalAmount);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header with Total Revenue
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              sectionTitle,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF334155),
                              ),
                            ),
                            Text(
                              '${sectionOrders.length} Order(s) • Total: ₱${sectionTotal.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFE91E63),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Section Items
                      ...sectionOrders.map((order) => _buildOrderTile(order)),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String mode, String label) {
    final isSelected = _dateFilterMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFFE91E63),
      backgroundColor: Colors.grey[100],
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      onSelected: (_) {
        setState(() {
          _dateFilterMode = mode;
          _selectedDate = null;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      side: BorderSide.none,
    );
  }

  Widget _buildOrderTile(OrderModel order) {
    final formattedTime = DateFormat('MMM dd, yyyy • hh:mm a').format(order.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFFFF0F5),
          child: Text(
            '#${order.queueNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE91E63), fontSize: 11),
          ),
        ),
        title: Text(
          'Order #${order.queueNumber}${order.customerDetails?.name.isNotEmpty == true ? " - ${order.customerDetails!.name}" : ""}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5, color: const Color(0xFF0F172A)),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$formattedTime • ${order.items.length} item(s) • ${order.serviceType.name.toUpperCase()}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '₱${order.totalAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (order.paymentMethod?.name ?? 'CASH').toUpperCase(),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ),
            if (widget.showReceiptAction) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.receipt,
                  arguments: ReceiptArguments(order: order),
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 14),
                label: const Text('RECEIPT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CashierNotificationsPage extends StatelessWidget {
  const _CashierNotificationsPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: NotificationsModalSheet(forRole: UserRole.cashier),
    );
  }
}

class CashierGuard extends StatefulWidget {
  final Widget child;
  final bool allowOwner;
  final String? requiredRole;

  const CashierGuard({
    super.key,
    required this.child,
    this.allowOwner = false,
    this.requiredRole,
  });

  @override
  State<CashierGuard> createState() => _CashierGuardState();
}

class _CashierGuardState extends State<CashierGuard> {
  late final Future<bool> _authorized;

  @override
  void initState() {
    super.initState();
    _authorized = _checkAuthorization();
  }

  Future<bool> _checkAuthorization() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final profile = await Supabase.instance.client
        .from('profiles')
        .select('role, account_status')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) return false;
    final role = (profile['role'] as String?)?.toUpperCase();
    final isAllowedRole = widget.requiredRole != null
        ? role == widget.requiredRole
        : role == 'CASHIER' || (widget.allowOwner && role == 'OWNER');
    return isAllowedRole &&
        (profile['account_status'] as String?)?.toUpperCase() == 'ACTIVE';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorized,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: LoadingState());
        if (snapshot.data == true) return widget.child;
        return Scaffold(
          appBar: AppBar(title: const Text('Access denied')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 12),
                  const Text(
                    'This area is available only to active cashier accounts.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    ),
                    child: const Text('RETURN TO LOGIN'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
