import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_routes.dart';
import '../models/system_notification_model.dart';
import '../models/user_model.dart';
import '../repositories/notification_repository.dart';

class NotificationsModalSheet extends StatefulWidget {
  final UserRole forRole;

  const NotificationsModalSheet({super.key, required this.forRole});

  static Future<void> show(BuildContext context, {required UserRole forRole}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationsModalSheet(forRole: forRole),
    );
  }

  @override
  State<NotificationsModalSheet> createState() => _NotificationsModalSheetState();
}

class _NotificationsModalSheetState extends State<NotificationsModalSheet> {
  int _filterTab = 0; // 0: All, 1: Unread

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Top iOS Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E5EA),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFE91E63), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Notifications",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D1D1F),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () async {
                    await NotificationRepository().markAllAsRead();
                    if (mounted) setState(() {});
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE91E63),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(
                    "Mark all read",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Segmented Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filterTab = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filterTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _filterTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                "ALL",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _filterTab == 0
                                      ? const Color(0xFFE91E63)
                                      : const Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filterTab = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filterTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _filterTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                "UNREAD",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _filterTab == 1
                                      ? const Color(0xFFE91E63)
                                      : const Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Material(
                  color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text("Clear Notifications?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          content: Text("Are you sure you want to clear all stored notification history?", style: GoogleFonts.poppins(fontSize: 13)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx, false),
                              child: const Text("CANCEL"),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(dialogCtx, true),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), foregroundColor: Colors.white),
                              child: const Text("CLEAR ALL"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await NotificationRepository().clearAllNotifications();
                        if (mounted) setState(() {});
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.delete_sweep_outlined, color: Color(0xFFFF3B30), size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE5E5EA)),

          // Notifications List
          Expanded(
            child: StreamBuilder<List<SystemNotificationModel>>(
              stream: NotificationRepository().streamNotifications(forRole: widget.forRole),
              builder: (context, snapshot) {
                final allNotifs = snapshot.data ?? [];
                final filtered = _filterTab == 1
                    ? allNotifs.where((n) => !n.isRead).toList()
                    : allNotifs;

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 52, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _filterTab == 1 ? "No unread notifications." : "No notifications in history.",
                          style: GoogleFonts.poppins(color: const Color(0xFF8E8E93), fontSize: 13.5),
                        ),
                      ],
                    ),
                  );
                }

                // Group by date ("Today", "Yesterday", "Earlier")
                final Map<String, List<SystemNotificationModel>> grouped = {};
                for (var n in filtered) {
                  final header = n.dateGroupHeader;
                  grouped.putIfAbsent(header, () => []).add(n);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, sectionIndex) {
                    final sectionTitle = grouped.keys.elementAt(sectionIndex);
                    final sectionItems = grouped[sectionTitle]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          color: const Color(0xFFF9F9FB),
                          child: Text(
                            sectionTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF8E8E93),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),

                        // Section Items
                        ...sectionItems.map((n) => _buildNotificationCard(n)),
                      ],
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

  String _getSafeRouteForRole(String rawRoute, UserRole role) {
    if (rawRoute.isEmpty) return '';

    switch (role) {
      case UserRole.customer:
      case UserRole.guest:
        if (rawRoute.startsWith('/staff') || rawRoute.startsWith('/rider') || rawRoute.startsWith('/kitchen')) {
          return AppRoutes.customerMenu;
        }
        return rawRoute;

      case UserRole.kitchen:
        if (rawRoute.contains('inventory') || rawRoute.startsWith('/staff/inventory')) {
          return AppRoutes.inventoryHub;
        }
        return AppRoutes.kitchenQueue;

      case UserRole.cashier:
        if (rawRoute.contains('kitchen') || rawRoute.startsWith('/staff/kitchen') || rawRoute.contains('order')) {
          return AppRoutes.staffOnlineOrders;
        }
        if (rawRoute.startsWith('/staff/inventory')) {
          return AppRoutes.inventoryHub;
        }
        return rawRoute;

      case UserRole.rider:
        if (!rawRoute.startsWith('/rider')) {
          return AppRoutes.riderDashboard;
        }
        return rawRoute;

      case UserRole.owner:
        // Owner manages Online Orders for order & preparation alerts, Inventory Hub for inventory alerts
        if (rawRoute.contains('kitchen') || rawRoute.startsWith('/staff/kitchen') || rawRoute.contains('order')) {
          return AppRoutes.onlineOrders;
        }
        if (rawRoute.contains('inventory') || rawRoute.startsWith('/staff/inventory')) {
          return AppRoutes.inventoryHub;
        }
        if (rawRoute.contains('rider') || rawRoute.contains('delivery')) {
          return AppRoutes.deliveryProofs;
        }
        return rawRoute;
    }
  }

  Widget _buildNotificationCard(SystemNotificationModel n) {
    final isUnread = !n.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFFFF0F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? const Color(0xFFFCE4EC) : const Color(0xFFF2F2F7),
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final nav = Navigator.of(context);
            await NotificationRepository().markAsRead(n.id);
            if (mounted) setState(() {});
            if (n.route != null && n.route!.isNotEmpty) {
              try {
                final target = _getSafeRouteForRole(n.route!, widget.forRole);
                if (target.isNotEmpty) {
                  nav.pop();
                  nav.pushNamed(target);
                }
              } catch (_) {}
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Leading Circular Icon Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: n.color.withValues(alpha: 0.12),
                    border: Border.all(color: n.color.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Icon(n.icon, color: n.color, size: 20),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  if (isUnread)
                                    const TextSpan(
                                      text: "• ",
                                      style: TextStyle(
                                        color: Color(0xFFE91E63),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  TextSpan(
                                    text: n.title,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                      color: isUnread ? const Color(0xFF1D1D1F) : const Color(0xFF48484A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            n.formattedTime,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isUnread ? const Color(0xFFE91E63) : const Color(0xFF8E8E93),
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.message,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                          color: isUnread ? const Color(0xFF2C2C2E) : const Color(0xFF636366),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
