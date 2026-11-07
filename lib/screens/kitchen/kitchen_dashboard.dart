import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../models/order_model.dart';
import '../../models/recipe_model.dart';
import '../../models/ingredient_model.dart';
import '../../models/inventory_movement_model.dart';
import '../../models/system_notification_model.dart';
import '../../models/user_model.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/recipe_repository.dart';
import '../../repositories/ingredient_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../widgets/notifications_modal_sheet.dart';
import '../../widgets/state_widgets.dart';

class KitchenDashboard extends StatefulWidget {
  const KitchenDashboard({super.key});

  @override
  State<KitchenDashboard> createState() => _KitchenDashboardState();
}

class _KitchenDashboardState extends State<KitchenDashboard>
    with SingleTickerProviderStateMixin {
  final _orderRepo = OrderRepository();
  late TabController _tabController;
  Timer? _timer;
  final Set<String> _notifiedPrepAlertOrderIds = {};

  void _checkPreparationTimeAlerts(List<OrderModel> orders) {
    for (var order in orders) {
      if (order.status.toLowerCase() == 'received' || order.status.toLowerCase() == 'preparing') {
        final elapsedMins = DateTime.now().difference(order.timestamp).inMinutes;
        if (elapsedMins >= 15 && !_notifiedPrepAlertOrderIds.contains(order.id)) {
          _notifiedPrepAlertOrderIds.add(order.id);
          NotificationRepository().addNotification(
            title: 'Preparation Time Alert',
            message: 'Order #${order.queueNumber}: Preparation time has exceeded the standard threshold (15 mins).',
            category: 'PREPARATION_TIME',
            route: AppRoutes.kitchenQueue,
            targetRole: 'KITCHEN,OWNER',
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Refresh UI every 30 seconds to update elapsed time labels
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Log Out Kitchen Station"),
          ],
        ),
        content: const Text("Are you sure you want to log out of Kitchen Station?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("LOG OUT"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.staffLogin);
      }
    }
  }

  void _updateStatus(OrderModel order, String newStatus) async {
    try {
      if (order.serviceType == ServiceType.delivery && newStatus.toLowerCase() == 'completed') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Delivery orders are completed by the Delivery Rider upon successful drop-off."),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      await _orderRepo.updateOrderStatus(order.id, newStatus.toLowerCase());
      if (mounted) {
        setState(() {
          order.status = newStatus.toLowerCase();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order #${order.queueNumber} updated to $newStatus"),
            backgroundColor: const Color(0xFFE91E63),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Unable to Update Order',
          message: 'The order status could not be updated: $e',
        );
      }
    }
  }

  void _showWastageDialog() async {
    final ingRepo = IngredientRepository();
    List<IngredientModel> ingredients = [];
    try {
      ingredients = await ingRepo.getIngredients();
    } catch (_) {}

    if (!mounted || ingredients.isEmpty) return;

    IngredientModel selectedIng = ingredients.first;
    final qtyController = TextEditingController(text: '1.0');
    final reasonController = TextEditingController(text: 'Burned / Spoiled in Kitchen');
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                SizedBox(width: 8),
                Text("Report Food Wastage"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Select ingredient wasted during cooking:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                DropdownButtonFormField<IngredientModel>(
                  initialValue: selectedIng,
                  decoration: InputDecoration(
                    labelText: "Ingredient",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ingredients
                      .map((ing) => DropdownMenuItem(value: ing, child: Text("${ing.name} (${ing.unit.name.toUpperCase()})")))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedIng = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyController,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: "Quantity Wasted (${selectedIng.unit.name.toUpperCase()})",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: "Reason / Notes",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("CANCEL"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (saving) return;
                  final qty = double.tryParse(qtyController.text.trim());
                  if (qty == null || qty <= 0) return;

                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(dialogContext);

                  setDialogState(() => saving = true);
                  await ingRepo.recordIngredientMovement(
                    ingredientId: selectedIng.id,
                    movementType: MovementType.wastage,
                    quantity: qty,
                    reason: reasonController.text.trim().isEmpty ? 'Kitchen Wastage' : reasonController.text.trim(),
                  );

                  NotificationRepository().addNotification(
                    title: 'Kitchen Wastage Reported',
                    message: '${selectedIng.name}: -$qty ${selectedIng.unit.name.toUpperCase()} (${reasonController.text.trim()})',
                    category: 'INVENTORY',
                    route: '/staff/inventory',
                    targetRole: 'OWNER',
                  );

                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("Recorded $qty ${selectedIng.unit.name.toUpperCase()} wastage for ${selectedIng.name}."),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                child: const Text("RECORD WASTAGE"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderRepo.getKitchenOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: ErrorState(
              error: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            ),
          );
        }
        if (!snapshot.hasData) return const Scaffold(body: LoadingState());

        final allOrders = snapshot.data!;
        _checkPreparationTimeAlerts(allOrders);

        final screenWidth = MediaQuery.sizeOf(context).width;
        final isMobileScreen = screenWidth < 600;

        return Scaffold(
          backgroundColor: const Color(0xFFF0F2F5),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            elevation: 1,
            titleSpacing: isMobileScreen ? 8 : 16,
            title: Row(
              children: [
                Image.asset('assets/images/Bellieslogo.png', height: isMobileScreen ? 32 : 40),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isMobileScreen ? "KITCHEN" : "KITCHEN STATION",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobileScreen ? 14 : 18,
                        color: Colors.black87,
                      ),
                    ),
                    if (!isMobileScreen)
                      const Text(
                        "Real-time Order Queue",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              if (isMobileScreen) ...[
                IconButton(
                  tooltip: "Report Wastage",
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                  onPressed: _showWastageDialog,
                ),
                StreamBuilder<List<SystemNotificationModel>>(
                  stream: NotificationRepository().streamNotifications(forRole: UserRole.kitchen),
                  builder: (context, snapshot) {
                    final unread = snapshot.data?.where((n) => !n.isRead).length ?? 0;
                    return IconButton(
                      tooltip: "Notifications",
                      icon: unread > 0
                          ? Badge(
                              label: Text('$unread'),
                              child: const Icon(Icons.notifications_outlined, color: Colors.black87),
                            )
                          : const Icon(Icons.notifications_outlined, color: Colors.black87),
                      onPressed: () => NotificationsModalSheet.show(context, forRole: UserRole.kitchen),
                    );
                  },
                ),
                _buildQueueBadge(allOrders.length, compact: true),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (val) {
                    if (val == 'profile') {
                      Navigator.pushNamed(context, AppRoutes.staffProfile);
                    } else if (val == 'logout') {
                      _logout();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person_outline_rounded, color: Colors.black87, size: 20),
                          SizedBox(width: 8),
                          Text("My Profile"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text("Log Out", style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _showWastageDialog,
                  icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 18),
                  label: const Text("REPORT WASTAGE", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<List<SystemNotificationModel>>(
                  stream: NotificationRepository().streamNotifications(forRole: UserRole.kitchen),
                  builder: (context, snapshot) {
                    final unread = snapshot.data?.where((n) => !n.isRead).length ?? 0;
                    return IconButton(
                      tooltip: "Notifications",
                      icon: unread > 0
                          ? Badge(
                              label: Text('$unread'),
                              child: const Icon(Icons.notifications_outlined, color: Colors.black87),
                            )
                          : const Icon(Icons.notifications_outlined, color: Colors.black87),
                      onPressed: () => NotificationsModalSheet.show(context, forRole: UserRole.kitchen),
                    );
                  },
                ),
                _buildQueueBadge(allOrders.length),
                IconButton(
                  tooltip: "My Profile",
                  icon: const Icon(Icons.person_outline_rounded, color: Colors.black87),
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.staffProfile),
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                ),
                const SizedBox(width: 8),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: isMobileScreen,
              tabAlignment: isMobileScreen ? TabAlignment.start : TabAlignment.fill,
              labelColor: const Color(0xFFE91E63),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFE91E63),
              tabs: [
                _buildTab(
                  "New",
                  Icons.fiber_new,
                  allOrders.where((o) => o.status == 'received').length,
                ),
                _buildTab(
                  "Cooking",
                  Icons.fire_truck_outlined,
                  allOrders.where((o) => o.status == 'preparing').length,
                ),
                _buildTab(
                  "Ready",
                  Icons.check_circle_outline,
                  allOrders.where((o) => o.status == 'ready').length,
                ),
                _buildTab("History", Icons.history, null),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOrderList(allOrders, 'received'),
              _buildOrderList(allOrders, 'preparing'),
              _buildOrderList(allOrders, 'ready'),
              _buildHistoryList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(String label, IconData icon, int? count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE91E63),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueBadge(int total, {bool compact = false}) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(right: compact ? 4 : 12),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          compact ? "Q: $total" : "TOTAL QUEUE: $total",
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> allOrders, String status) {
    final orders = allOrders
        .where((o) => o.status.toLowerCase() == status.toLowerCase())
        .toList();

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "No $status orders at the moment.",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isLandscape = screenWidth > screenHeight;

    int crossAxisCount = 3;
    double aspectRatio = 0.75;

    if (screenWidth < 600) {
      if (isLandscape) {
        crossAxisCount = 2;
        aspectRatio = 1.25;
      } else {
        crossAxisCount = 1;
        aspectRatio = 0.85;
      }
    } else if (screenWidth < 1000) {
      crossAxisCount = 2;
      aspectRatio = isLandscape ? 1.05 : 0.80;
    } else {
      crossAxisCount = 3;
      aspectRatio = 0.78;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) => KitchenOrderCard(
        order: orders[index],
        onStatusChange: (newStatus) => _updateStatus(orders[index], newStatus),
      ),
    );
  }

  Widget _buildHistoryList() {
    return StreamBuilder<List<OrderModel>>(
      stream: _orderRepo.getCompletedOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            error: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) return const LoadingState();
        if (snapshot.data!.isEmpty) {
          return const Center(child: Text("No completed orders yet."));
        }

        final screenWidth = MediaQuery.sizeOf(context).width;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final isLandscape = screenWidth > screenHeight;

        int crossAxisCount = 4;
        double aspectRatio = 1.1;

        if (screenWidth < 600) {
          if (isLandscape) {
            crossAxisCount = 2;
            aspectRatio = 1.3;
          } else {
            crossAxisCount = 1;
            aspectRatio = 1.0;
          }
        } else if (screenWidth < 1000) {
          crossAxisCount = 2;
          aspectRatio = isLandscape ? 1.2 : 1.0;
        } else {
          crossAxisCount = 4;
          aspectRatio = 1.1;
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: aspectRatio,
          ),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) => KitchenOrderCard(
            order: snapshot.data![index],
            onStatusChange: (_) {},
            isHistory: true,
          ),
        );
      },
    );
  }
}

class KitchenOrderCard extends StatefulWidget {
  final OrderModel order;
  final Function(String) onStatusChange;
  final bool isHistory;

  const KitchenOrderCard({
    super.key,
    required this.order,
    required this.onStatusChange,
    this.isHistory = false,
  });

  @override
  State<KitchenOrderCard> createState() => _KitchenOrderCardState();
}

class _KitchenOrderCardState extends State<KitchenOrderCard> {
  bool _isUpdating = false;

  String _getElapsedTime() {
    final diff = DateTime.now().difference(widget.order.timestamp);
    if (diff.inMinutes < 1) return "JUST NOW";
    return "${diff.inMinutes} MINS AGO";
  }

  Color _getServiceColor() {
    switch (widget.order.serviceType) {
      case ServiceType.dineIn:
        return Colors.green;
      case ServiceType.takeout:
        return Colors.orange;
      case ServiceType.delivery:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsedMins = DateTime.now().difference(widget.order.timestamp).inMinutes;
    final isDelayed = !widget.isHistory && elapsedMins > 15;

    return Card(
      elevation: isDelayed ? 8 : 2,
      shadowColor: isDelayed
          ? Colors.red.withAlpha((0.3 * 255).toInt())
          : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDelayed
              ? Colors.red
              : (widget.isHistory ? Colors.grey[200]! : Colors.transparent),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDelayed ? Colors.red : const Color(0xFF333333),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ORDER #${widget.order.queueNumber}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _getElapsedTime(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Service Type Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            color: _getServiceColor().withAlpha((0.1 * 255).toInt()),
            child: Row(
              children: [
                Icon(Icons.circle, size: 8, color: _getServiceColor()),
                const SizedBox(width: 8),
                Text(
                  widget.order.serviceType.name.toUpperCase(),
                  style: TextStyle(
                    color: _getServiceColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.order.items.length,
              separatorBuilder: (context, index) => const Divider(height: 20),
              itemBuilder: (context, i) {
                final item = widget.order.items[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "${item.quantity}x",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Recipe Ingredients Display
                    FutureBuilder<List<RecipeItemModel>>(
                      future: RecipeRepository().getRecipeForProduct(
                        item.product.id,
                        productName: item.product.name,
                      ),
                      builder: (context, recipeSnapshot) {
                        final recipe = recipeSnapshot.data ?? [];
                        if (recipe.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(left: 32, top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: recipe.map((r) {
                              final totalQty = r.quantityRequired * item.quantity;
                              final formattedQty = (totalQty.truncateToDouble() == totalQty)
                                  ? totalQty.toStringAsFixed(0)
                                  : totalQty.toStringAsFixed(2);
                              return Text(
                                "• $formattedQty ${r.unit.toLowerCase()} ${r.ingredientName}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    if (item.instructions != null &&
                        item.instructions!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8, left: 32),
                        padding: const EdgeInsets.all(8),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "NOTE: ${item.instructions}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          // Footer Action
          if (!widget.isHistory)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: _buildActionBtn(),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBtn() {
    String label = "";
    Color color = Colors.black;
    String target = "";

    switch (widget.order.status.toLowerCase()) {
      case 'received':
        label = "START COOKING";
        color = const Color(0xFFE91E63);
        target = "Preparing";
        break;
      case 'preparing':
        label = "MARK AS READY";
        color = Colors.orange;
        target = "Ready";
        break;
      case 'ready':
        if (widget.order.serviceType == ServiceType.delivery) {
          label = "WAITING FOR RIDER";
          color = Colors.blueGrey;
          target = "Ready";
        } else {
          label = "COMPLETE ORDER";
          color = Colors.green;
          target = "Completed";
        }
        break;
    }

    return ElevatedButton(
      onPressed: _isUpdating
          ? null
          : () async {
              setState(() => _isUpdating = true);
              try {
                await widget.onStatusChange(target);
              } finally {
                if (mounted) {
                  setState(() => _isUpdating = false);
                }
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: _isUpdating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
