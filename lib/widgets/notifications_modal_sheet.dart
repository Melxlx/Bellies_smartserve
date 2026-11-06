import 'package:flutter/material.dart';
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Top Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header Bar matching reference design
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Notifications",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await NotificationRepository().markAllAsRead();
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF059669)),
                  label: const Text(
                    "Mark all as read",
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filter Segment Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filterTab = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filterTab == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _filterTab == 0
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                "ALL NOTIFICATIONS",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _filterTab == 0
                                      ? const Color(0xFFE91E63)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _filterTab = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _filterTab == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: _filterTab == 1
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(12),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Text(
                                "UNREAD",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _filterTab == 1
                                      ? const Color(0xFFE91E63)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: "Clear All History",
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text("Clear Notifications?"),
                        content: const Text("Are you sure you want to clear stored notification history?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: const Text("CANCEL"),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

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
                        Icon(Icons.notifications_none_rounded, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _filterTab == 1 ? "No unread notifications." : "No notifications in history.",
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
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
                          color: const Color(0xFFF8FAFC),
                          child: Text(
                            sectionTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
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
        if (rawRoute.startsWith('/staff/inventory') ||
            rawRoute.startsWith('/staff/employees') ||
            rawRoute.startsWith('/staff/payroll') ||
            rawRoute.startsWith('/staff/reports') ||
            rawRoute.startsWith('/staff/settings')) {
          return AppRoutes.staffKitchen;
        }
        return rawRoute;

      case UserRole.cashier:
        if (rawRoute.contains('kitchen') || rawRoute.startsWith('/staff/kitchen')) {
          return AppRoutes.staffOnlineOrders;
        }
        if (rawRoute.startsWith('/staff/inventory') ||
            rawRoute.startsWith('/staff/employees') ||
            rawRoute.startsWith('/staff/payroll') ||
            rawRoute.startsWith('/staff/reports') ||
            rawRoute.startsWith('/staff/settings')) {
          return AppRoutes.cashierDashboard;
        }
        return rawRoute;

      case UserRole.rider:
        if (!rawRoute.startsWith('/rider')) {
          return AppRoutes.riderDashboard;
        }
        return rawRoute;

      case UserRole.owner:
        return rawRoute;
    }
  }

  Widget _buildNotificationCard(SystemNotificationModel n) {
    final isUnread = !n.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        // Soft green highlight tint for unread items matching reference image
        color: isUnread ? const Color(0xFFEBFDF5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnread ? const Color(0xFFA7F3D0) : const Color(0xFFF1F5F9),
          width: isUnread ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(n.icon, color: n.color, size: 20),
                ),
                const SizedBox(width: 14),

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
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  TextSpan(
                                    text: n.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                                      color: isUnread ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            n.formattedTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: isUnread ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                          color: isUnread ? const Color(0xFF1E293B) : const Color(0xFF64748B),
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
