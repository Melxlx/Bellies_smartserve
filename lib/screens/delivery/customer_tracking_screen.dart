import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/order_model.dart';
import '../../models/system_notification_model.dart';
import '../../models/user_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../services/free_map_service.dart';
import '../../services/delivery_service_area.dart';
import '../../services/order_tracking_service.dart';
import '../../widgets/order_rating_widget.dart';
import '../../widgets/product_image.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/premium_action_button.dart';
import '../../widgets/premium_content_card.dart';
import '../../widgets/notifications_modal_sheet.dart';

class CustomerTrackingScreen extends StatefulWidget {
  const CustomerTrackingScreen({super.key});

  @override
  State<CustomerTrackingScreen> createState() => _CustomerTrackingScreenState();
}

class _CustomerTrackingScreenState extends State<CustomerTrackingScreen> {
  final _repo = TrackingRepository();
  final _mapService = FreeMapService();
  final _trackingController = TextEditingController();
  final MapController _mapController = MapController();

  OrderModel? _initialOrder;
  List<OrderModel> _customerOrders = [];
  bool _isLoading = false;
  bool _searched = false;
  bool _loadingCustomerOrders = false;

  @override
  void initState() {
    super.initState();
    _loadCustomerOrdersAndAutoTrack();
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerOrdersAndAutoTrack() async {
    setState(() => _loadingCustomerOrders = true);

    final orders = await _repo.getCustomerOrders();
    _customerOrders = orders;

    final lastTrk = OrderTrackingService().lastTrackingNumber;
    String? trkToSearch = lastTrk;

    if ((trkToSearch == null || trkToSearch.isEmpty) && _customerOrders.isNotEmpty) {
      final activeOrder = _customerOrders.firstWhere(
        (o) => o.status.toLowerCase() != 'completed' && o.status.toLowerCase() != 'cancelled',
        orElse: () => _customerOrders.first,
      );
      trkToSearch = activeOrder.trackingNumber;
    }

    if (trkToSearch != null && trkToSearch.isNotEmpty) {
      _trackingController.text = trkToSearch;
      OrderTrackingService().setTrackingNumber(trkToSearch);
      _searchOrder(trkToSearch);
    }

    if (mounted) {
      setState(() => _loadingCustomerOrders = false);
    }
  }

  void _searchOrder([String? trackingNum]) async {
    final trk = (trackingNum ?? _trackingController.text).trim();
    if (trk.isEmpty) return;

    _trackingController.text = trk;
    OrderTrackingService().setTrackingNumber(trk);

    setState(() {
      _isLoading = true;
      _searched = true;
    });

    final order = await _repo.getOrderByTracking(trk);

    if (mounted) {
      setState(() {
        _initialOrder = order;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    final displayCode = _initialOrder != null
        ? "CR-${_initialOrder!.queueNumber}"
        : (_trackingController.text.isNotEmpty ? _trackingController.text : "Track Order");

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          displayCode,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: SmartBackButton(),
        ),
        actions: [
          if (isAuthenticated)
            StreamBuilder<List<SystemNotificationModel>>(
              stream: NotificationRepository().streamNotifications(forRole: UserRole.customer),
              builder: (context, snapshot) {
                final unread = snapshot.data?.where((n) => !n.isRead).length ?? 0;
                return IconButton(
                  tooltip: "Notifications",
                  icon: unread > 0
                      ? Badge(
                          label: Text('$unread'),
                          backgroundColor: AppColors.primary,
                          child: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                        )
                      : const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                  onPressed: () => NotificationsModalSheet.show(context, forRole: UserRole.customer),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _loadCustomerOrdersAndAutoTrack,
            tooltip: "Refresh Tracking",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_customerOrders.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _buildMyOrdersHorizontalBar(),
              ),
            ],

            // Tracking Code Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildTrackingCodeInput(),
            ),

            if (_isLoading || _loadingCustomerOrders)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingState(),
              )
            else if (_searched) ...[
              if (_initialOrder != null)
                StreamBuilder<OrderModel?>(
                  stream: _repo.trackOrderLive(_initialOrder!.id),
                  initialData: _initialOrder,
                  builder: (context, snapshot) {
                    final order = snapshot.data;
                    if (order == null) {
                      return const Padding(
                        padding: EdgeInsets.all(32),
                        child: EmptyState(message: "Order not found."),
                      );
                    }
                    return _buildLiveTrackingView(order);
                  },
                )
              else
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: EmptyState(message: "Order not found. Please check your tracking code."),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: EmptyState(message: "Enter a tracking code or select an active order above."),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyOrdersHorizontalBar() {
    return StreamBuilder<List<OrderModel>>(
      stream: _repo.streamCustomerOrders(),
      initialData: _customerOrders,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? _customerOrders;
        if (orders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MY ACTIVE ORDERS",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 11.5,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final isSelected = _initialOrder?.id == order.id ||
                      _trackingController.text.trim().toUpperCase() == order.trackingNumber.toUpperCase();

                  final isCompleted = order.status.toLowerCase() == 'completed';
                  final isCancelled = order.status.toLowerCase() == 'cancelled';

                  Color badgeColor = AppColors.warning;
                  if (isCompleted) badgeColor = AppColors.success;
                  if (isCancelled) badgeColor = AppColors.error;
                  if (order.status.toLowerCase() == 'ready' || order.deliveryStatus == DeliveryStatus.outForDelivery) {
                    badgeColor = AppColors.primary;
                  }

                  return GestureDetector(
                    onTap: () => _searchOrder(order.trackingNumber),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 180,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.lightPink : AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.8 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: isSelected ? 0.1 : 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "CR-${order.queueNumber}",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order.status.toUpperCase(),
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            order.itemsSummary,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrackingCodeInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightPink, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _trackingController,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "Enter Tracking Code (e.g. BELLIES-123456)",
                hintStyle: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _searchOrder(),
            ),
          ),
          ElevatedButton(
            onPressed: _searchOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text("TRACK", style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTrackingView(OrderModel order) {
    final isCompleted = order.status.toLowerCase() == 'completed' || order.deliveryStatus == DeliveryStatus.delivered;

    return Column(
      children: [
        // Map & Floating ETA Card Stack
        _buildEmbeddedMapWithFloatingEta(order),

        const SizedBox(height: 52),

        // Vertical Progress Timeline
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PremiumContentCard(
            padding: const EdgeInsets.all(20),
            child: _buildDeliveryTimeline(order),
          ),
        ),

        const SizedBox(height: 16),

        // Proof of Delivery Photo (if completed)
        if (order.deliveryProofUrl != null && order.deliveryProofUrl!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildProofOfDeliveryCard(order),
          ),
          const SizedBox(height: 16),
        ],

        // Order Rating Widget (if completed)
        if (isCompleted) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OrderRatingWidget(
              orderId: order.id,
              customerName: order.customerDetails?.name ?? 'Customer',
              customerId: order.createdBy,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Order Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildOrderSummaryCard(order),
        ),

        const SizedBox(height: 24),

        // Bottom CTA Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildBottomActionArea(order),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildEmbeddedMapWithFloatingEta(OrderModel order) {
    final customerPos = LatLng(
      order.customerDetails?.latitude ?? DeliveryServiceArea.storeLocation.latitude,
      order.customerDetails?.longitude ?? DeliveryServiceArea.storeLocation.longitude,
    );

    final etaText = _calculateEtaText(order);
    final stageSubtitle = _getStageSubtitle(order);
    final customerAddress = order.customerDetails?.address ?? "Customer Address";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Embedded Rounded Map Card
          Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.lightPink, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  _buildLiveMap(order, customerPos),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: FloatingActionButton.small(
                      backgroundColor: Colors.white,
                      elevation: 4,
                      tooltip: "Center Map",
                      onPressed: () => _mapController.move(customerPos, 14),
                      child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating ETA Card overlapping the lower part of the map
          Positioned(
            left: 14,
            right: 14,
            bottom: -36,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.lightPink, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        etaText,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.lightPink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              "LIVE TRACK",
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stageSubtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "Bellie's Kitchen",
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textSecondary),
                        ),
                        Expanded(
                          child: Text(
                            customerAddress,
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateEtaText(OrderModel order) {
    final status = order.status.toLowerCase();
    final dStatus = order.deliveryStatus;

    if (dStatus == DeliveryStatus.delivered || status == 'completed') {
      return "Delivered 🎉";
    }
    if (dStatus == DeliveryStatus.outForDelivery) {
      return "15–25 min";
    }
    if (status == 'ready') {
      return "10–15 min";
    }
    if (status == 'preparing') {
      return "25–35 min";
    }
    return "30–40 min";
  }

  String _getStageSubtitle(OrderModel order) {
    final status = order.status.toLowerCase();
    final dStatus = order.deliveryStatus;

    if (dStatus == DeliveryStatus.delivered || status == 'completed') {
      return "Order has been delivered. Enjoy your meal!";
    }
    if (dStatus == DeliveryStatus.outForDelivery) {
      return "Your order is on the way with the rider!";
    }
    if (status == 'ready') {
      return "Your order is ready & waiting for pickup.";
    }
    if (status == 'preparing') {
      return "Kitchen is preparing your delicious meal.";
    }
    return "Your order is confirmed & in line.";
  }

  Widget _buildLiveMap(OrderModel order, LatLng customerPos) {
    final storePos = DeliveryServiceArea.storeLocation;

    if (order.riderId == null) {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: customerPos, initialZoom: 14),
        children: [
          TileLayer(
            urlTemplate: _mapService.tileUrlTemplate,
            userAgentPackageName: _mapService.userAgentPackageName,
          ),
          MarkerLayer(markers: [
            Marker(
              point: storePos,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
              ),
            ),
            Marker(
              point: customerPos,
              child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 36),
            ),
          ]),
        ],
      );
    }

    return StreamBuilder<Map<String, double>?>(
      stream: _repo.streamRiderLocation(order.riderId!),
      builder: (context, snapshot) {
        final riderPos = snapshot.data != null ? LatLng(snapshot.data!['lat']!, snapshot.data!['lng']!) : null;

        return FutureBuilder<Map<String, dynamic>?>(
          future: riderPos != null ? _mapService.getRoute(start: riderPos, end: customerPos) : null,
          builder: (context, routeSnapshot) {
            final polyline = routeSnapshot.data?['polyline'] as List<LatLng>? ?? [];

            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: riderPos ?? customerPos, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: _mapService.tileUrlTemplate,
                  userAgentPackageName: _mapService.userAgentPackageName,
                ),
                if (polyline.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(points: polyline, strokeWidth: 5, color: AppColors.primary),
                  ]),
                MarkerLayer(markers: [
                  Marker(
                    point: storePos,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
                    ),
                  ),
                  Marker(
                    point: customerPos,
                    child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 36),
                  ),
                  if (riderPos != null)
                    Marker(
                      point: riderPos,
                      width: 44,
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                ]),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryTimeline(OrderModel order) {
    final status = order.status.toLowerCase();
    final dStatus = order.deliveryStatus;

    final isConfirmed = status != 'cancelled';
    final isKitchen = status == 'preparing' || status == 'ready' || status == 'completed' || dStatus == DeliveryStatus.outForDelivery || dStatus == DeliveryStatus.delivered;
    final isOnTheWay = dStatus == DeliveryStatus.outForDelivery || dStatus == DeliveryStatus.delivered || status == 'completed';
    final isDelivered = dStatus == DeliveryStatus.delivered || status == 'completed';

    String activeStageMessage = "The kitchen has it. The pans are about to get loud!";
    if (isDelivered) {
      activeStageMessage = "Order delivered! Thank you for ordering from Bellie's Kitchen!";
    } else if (isOnTheWay) {
      activeStageMessage = "Rider has picked up your food and is on the way to your address!";
    } else if (isKitchen) {
      activeStageMessage = "Our chefs are cooking your fresh meal in the kitchen!";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            activeStageMessage,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _timelineStepItem("Confirmed", isConfirmed, isKitchen, isFirst: true),
        _timelineStepItem("Kitchen", isKitchen, isOnTheWay),
        _timelineStepItem("On the way", isOnTheWay, isDelivered),
        _timelineStepItem("Delivered", isDelivered, false, isLast: true),
      ],
    );
  }

  Widget _timelineStepItem(String title, bool isDone, bool isNextDone, {bool isFirst = false, bool isLast = false}) {
    Color circleColor = AppColors.lightPink;
    Widget centerIndicator = const Icon(Icons.check_rounded, size: 12, color: AppColors.primary);

    if (isDone && !isNextDone) {
      // Active current stage
      circleColor = AppColors.primary;
      centerIndicator = Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      );
    } else if (!isDone) {
      // Pending stage
      circleColor = const Color(0xFFF1F5F9);
      centerIndicator = Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(color: Color(0xFFCBD5E1), shape: BoxShape.circle),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: isDone && !isNextDone
                      ? Border.all(color: AppColors.softPink, width: 3)
                      : null,
                ),
                child: Center(child: centerIndicator),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  color: isNextDone ? AppColors.primary : const Color(0xFFE2E8F0),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                color: isDone ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProofOfDeliveryCard(OrderModel order) {
    final proofUrl = order.deliveryProofUrl!;
    final isDataUrl = proofUrl.startsWith('data:image');

    return PremiumContentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Proof of Delivery Photo",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showFullScreenImage(proofUrl),
                icon: const Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.primary),
                label: Text("VIEW FULL", style: GoogleFonts.poppins(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showFullScreenImage(proofUrl),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: isDataUrl
                  ? Image.memory(base64Decode(proofUrl.split(',').last), fit: BoxFit.cover, height: 180, width: double.infinity)
                  : Image.network(proofUrl, fit: BoxFit.cover, height: 180, width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(String proofUrl) {
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
                  ? Image.memory(base64Decode(proofUrl.split(',').last), fit: BoxFit.contain)
                  : Image.network(proofUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard(OrderModel order) {
    final formattedDate = DateFormat('EEE, MMM dd, h:mm a').format(order.timestamp);
    final paymentText = (order.paymentMethod == PaymentMethod.gcash || (order.paymentMethod?.name.toUpperCase() ?? 'GCASH') == 'GCASH') ? 'GCash' : 'Cash on Delivery';

    return PremiumContentCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your order",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Order Items List
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: ProductImage(
                        path: item.product.imagePath ?? '',
                        productName: item.product.name,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${item.quantity} × ${item.product.name}",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "₱${item.product.sellingPrice.toStringAsFixed(2)} each",
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "₱${item.total.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 20),

          // Payment & Date Summary Rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Payment Method", style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              Text(paymentText, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Order Date & Time", style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              Text(formattedDate, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            ],
          ),
          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Amount", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(
                "₱${order.totalAmount.toStringAsFixed(2)}",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionArea(OrderModel order) {
    final dStatus = order.deliveryStatus;
    final status = order.status.toLowerCase();

    if (dStatus == DeliveryStatus.outForDelivery && order.riderId != null) {
      return Column(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: Supabase.instance.client
                .from('profiles')
                .select('contact_number, full_name')
                .eq('id', order.riderId!)
                .maybeSingle(),
            builder: (context, snapshot) {
              final riderContact = snapshot.data?['contact_number']?.toString() ?? '';
              
              return PremiumActionButton(
                label: "CONTACT RIDER",
                icon: Icons.phone_rounded,
                onPressed: () {
                  final phone = riderContact.isNotEmpty ? riderContact : '09171234567';
                  launchUrl(Uri.parse('tel:$phone'));
                },
              );
            },
          ),
          const SizedBox(height: 10),
          PremiumActionButton(
            label: "BACK TO MENU",
            isSecondary: true,
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.customerMenu),
          ),
        ],
      );
    }

    if (status == 'completed' || dStatus == DeliveryStatus.delivered) {
      return Column(
        children: [
          PremiumActionButton(
            label: "ORDER THIS AGAIN",
            icon: Icons.replay_rounded,
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.customerMenu),
          ),
          const SizedBox(height: 10),
          PremiumActionButton(
            label: "BACK TO MENU",
            isSecondary: true,
            onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.customerMenu),
          ),
        ],
      );
    }

    return PremiumActionButton(
      label: "BACK TO MENU",
      icon: Icons.storefront_rounded,
      onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.customerMenu),
    );
  }
}
