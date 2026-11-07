import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../repositories/tracking_repository.dart';
import '../../services/free_map_service.dart';
import '../../services/delivery_service_area.dart';
import '../../services/order_tracking_service.dart';
import '../../widgets/order_rating_widget.dart';
import '../../widgets/state_widgets.dart';

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
      _searchOrder();
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E3),
      appBar: AppBar(
        title: const Text("Track My Order"),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomerOrdersAndAutoTrack,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (_customerOrders.isNotEmpty) ...[
              _buildMyOrdersSection(),
              const SizedBox(height: 20),
            ],
            _buildSearchField(),
            const SizedBox(height: 24),
            if (_isLoading || _loadingCustomerOrders) 
              const LoadingState()
            else if (_searched) ...[
              if (_initialOrder != null)
                StreamBuilder<OrderModel?>(
                  stream: _repo.trackOrderLive(_initialOrder!.id),
                  initialData: _initialOrder,
                  builder: (context, snapshot) {
                    final order = snapshot.data;
                    if (order == null) return const Text("Order not found.");
                    return _buildLiveTracking(order);
                  },
                )
              else
                const EmptyState(message: "Order not found. Check tracking code."),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyOrdersSection() {
    return StreamBuilder<List<OrderModel>>(
      stream: _repo.streamCustomerOrders(),
      initialData: _customerOrders,
      builder: (context, snapshot) {
        final orders = snapshot.data ?? _customerOrders;
        if (orders.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                "MY ORDERS (LIVE)",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
              ),
            ),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final isSelected = _initialOrder?.id == order.id ||
                      _trackingController.text.trim().toUpperCase() == order.trackingNumber.toUpperCase();

                  final isCompleted = order.status.toLowerCase() == 'completed';
                  final isCancelled = order.status.toLowerCase() == 'cancelled';

                  Color badgeColor = Colors.orange;
                  if (isCompleted) badgeColor = Colors.green;
                  if (isCancelled) badgeColor = Colors.red;
                  if (order.status.toLowerCase() == 'ready' || order.deliveryStatus == DeliveryStatus.outForDelivery) {
                    badgeColor = const Color(0xFFE91E63);
                  }

                  return InkWell(
                    onTap: () => _searchOrder(order.trackingNumber),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE91E63).withAlpha(20) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE91E63) : Colors.grey[200]!,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Order #${order.queueNumber}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order.status.toUpperCase(),
                                  style: TextStyle(color: badgeColor, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            order.itemsSummary,
                            style: TextStyle(color: Colors.grey[700], fontSize: 11),
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

  Widget _buildSearchField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Enter Tracking Code"),
            const SizedBox(height: 12),
            TextField(
              controller: _trackingController,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "BELLIES-XXXXXX"),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _searchOrder, child: const Text("TRACK LIVE")),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTracking(OrderModel order) {
    final bool isDeliveredOrCompleted =
        order.status.toLowerCase() == 'completed' ||
        order.deliveryStatus == DeliveryStatus.delivered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusHeader(order),
        const SizedBox(height: 20),
        _buildMapSection(order),
        if (order.deliveryProofUrl != null && order.deliveryProofUrl!.isNotEmpty) ...[
          _buildProofOfDeliveryCard(order),
        ],
        if (isDeliveredOrCompleted) ...[
          const SizedBox(height: 20),
          OrderRatingWidget(
            orderId: order.id,
            customerName: order.customerDetails?.name ?? 'Customer',
            customerId: order.createdBy,
          ),
        ],
        const SizedBox(height: 32),
        _buildTimeline(order),
      ],
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
                  ? Image.memory(
                      base64Decode(proofUrl.split(',').last),
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      proofUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Text("Unable to load full photo", style: TextStyle(color: Colors.white)),
                      ),
                    ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofOfDeliveryCard(OrderModel order) {
    if (order.deliveryProofUrl == null || order.deliveryProofUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final proofUrl = order.deliveryProofUrl!;
    final isDataUrl = proofUrl.startsWith('data:image');

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Proof of Delivery Photo",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showFullScreenImage(proofUrl),
                icon: const Icon(Icons.zoom_in, size: 16, color: Colors.green),
                label: const Text("VIEW FULL", style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showFullScreenImage(proofUrl),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 380, minHeight: 180),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isDataUrl
                    ? Image.memory(
                        base64Decode(proofUrl.split(',').last),
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        proofUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Container(
                          height: 120,
                          color: Colors.grey[200],
                          child: const Center(child: Text("Unable to load proof photo", style: TextStyle(fontSize: 12, color: Colors.grey))),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              "🔍 Tap photo to view in full resolution",
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Color(0xFFE91E63)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(_formatStatus(order.deliveryStatus), 
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatStatus(DeliveryStatus? status) {
    if (status == null) return "Preparing...";
    return status.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .toUpperCase();
  }

  Widget _buildMapSection(OrderModel order) {
    final customerPos = LatLng(
      order.customerDetails?.latitude ?? DeliveryServiceArea.storeLocation.latitude,
      order.customerDetails?.longitude ?? DeliveryServiceArea.storeLocation.longitude,
    );

    return SizedBox(
      height: 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            _buildLiveMap(order, customerPos),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                tooltip: "Center Map to Delivery Location",
                onPressed: () => _mapController.move(customerPos, 14),
                child: const Icon(Icons.my_location, color: Color(0xFFE91E63)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMap(OrderModel order, LatLng customerPos) {
    final storePos = DeliveryServiceArea.storeLocation;

    if (order.riderId == null) {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: customerPos, initialZoom: 14),
        children: [
          TileLayer(urlTemplate: _mapService.tileUrlTemplate),
          MarkerLayer(markers: [
            Marker(point: storePos, child: const Icon(Icons.store, color: Colors.blue, size: 30)),
            Marker(point: customerPos, child: const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 40)),
          ]),
          _buildAttribution(),
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
                TileLayer(urlTemplate: _mapService.tileUrlTemplate),
                if (polyline.isNotEmpty)
                  PolylineLayer(polylines: [
                    Polyline(points: polyline, strokeWidth: 5, color: Colors.blue),
                  ]),
                MarkerLayer(markers: [
                  Marker(point: storePos, child: const Icon(Icons.store, color: Colors.blue, size: 30)),
                  Marker(point: customerPos, child: const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 40)),
                  if (riderPos != null)
                    Marker(
                      point: riderPos,
                      width: 50, height: 50,
                      child: const Icon(Icons.motorcycle, color: Colors.orange, size: 40),
                    ),
                ]),
                _buildAttribution(),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAttribution() {
    return RichAttributionWidget(
      attributions: [
        TextSourceAttribution(
          'OpenStreetMap contributors',
          onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
        ),
      ],
    );
  }

  Widget _buildTimeline(OrderModel order) {
    final status = order.status.toLowerCase();
    final dStatus = order.deliveryStatus;

    return Column(
      children: [
        _timelineItem("Verified", true, Icons.check_circle),
        _timelineItem("Preparing", status == 'preparing' || status == 'ready' || status == 'completed', Icons.restaurant),
        _timelineItem("On the Way", dStatus == DeliveryStatus.outForDelivery || dStatus == DeliveryStatus.delivered, Icons.motorcycle),
        _timelineItem("Delivered", dStatus == DeliveryStatus.delivered, Icons.home),
      ],
    );
  }

  Widget _timelineItem(String label, bool active, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: active ? const Color(0xFFE91E63) : Colors.grey[300]),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(color: active ? Colors.black : Colors.grey, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          if (active) const Icon(Icons.check, color: Colors.green, size: 16),
        ],
      ),
    );
  }
}
