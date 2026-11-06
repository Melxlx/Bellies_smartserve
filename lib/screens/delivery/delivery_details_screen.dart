import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../repositories/rider_repository.dart';
import '../../services/free_map_service.dart';
import '../../services/delivery_service_area.dart';
import '../../repositories/tracking_repository.dart';

class DeliveryDetailsScreen extends StatefulWidget {
  final OrderModel order;

  const DeliveryDetailsScreen({super.key, required this.order});

  @override
  State<DeliveryDetailsScreen> createState() => _DeliveryDetailsScreenState();
}

class _DeliveryDetailsScreenState extends State<DeliveryDetailsScreen> {
  final _riderRepo = RiderRepository();
  final _trackingRepo = TrackingRepository();
  final _mapService = FreeMapService();
  late OrderModel _order;
  bool _isUpdating = false;
  bool _isReassigning = false;
  List<UserModel> _availableRiders = [];
  String? _selectedRiderId;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _loadOrderDetails();
    _loadRiders();
  }

  Future<void> _loadOrderDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('orders')
          .select('*, order_items(*, products(*)), profiles(full_name)')
          .eq('id', _order.id)
          .maybeSingle();

      if (response != null && mounted) {
        final updatedOrder = OrderModel.fromJson(response);
        setState(() {
          _order = updatedOrder;
          if (_order.riderId != null && _order.riderId!.isNotEmpty) {
            _selectedRiderId = _order.riderId;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading latest order details: $e");
    }
  }

  Future<void> _loadRiders() async {
    try {
      final riders = await _riderRepo.getAvailableRiders();
      if (!mounted) return;
      setState(() {
        _availableRiders = riders;
        if (_order.riderId != null && _order.riderId!.isNotEmpty) {
          _selectedRiderId = _order.riderId;
        } else if (riders.isNotEmpty && _selectedRiderId == null) {
          _selectedRiderId = riders.first.id;
        }
      });
    } catch (e) {
      debugPrint("Error loading riders: $e");
    }
  }

  Future<void> _assignRider() async {
    if (_selectedRiderId == null) return;
    setState(() => _isUpdating = true);
    try {
      await _riderRepo.assignRider(_order.id, _selectedRiderId!);
      if (mounted) {
        final rider = _availableRiders.firstWhere(
          (candidate) => candidate.id == _selectedRiderId,
          orElse: () => UserModel(
            id: _selectedRiderId!,
            email: '',
            fullName: 'Selected Rider',
            position: 'Rider',
            role: UserRole.rider,
            accountStatus: AccountStatus.active,
          ),
        );
        setState(() {
          _order = _order.copyWith(
            riderId: rider.id,
            riderName: rider.fullName,
            deliveryStatus: _order.deliveryStatus ?? DeliveryStatus.readyForDelivery,
          );
          _isReassigning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Rider ${rider.fullName} assigned successfully!")),
        );
        await _loadRiders();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  String get _nextStatusLabel {
    switch (_order.deliveryStatus) {
      case DeliveryStatus.preparing:
        return "MARK AS READY FOR DELIVERY";
      case DeliveryStatus.readyForDelivery:
        return "MARK AS OUT FOR DELIVERY";
      case DeliveryStatus.outForDelivery:
        return "MARK AS DELIVERED";
      default:
        return "UPDATE STATUS";
    }
  }

  Future<void> _updateStatus() async {
    DeliveryStatus? nextStatus;
    String newStatus = _order.status;

    switch (_order.deliveryStatus) {
      case DeliveryStatus.preparing:
        nextStatus = DeliveryStatus.readyForDelivery;
        break;
      case DeliveryStatus.readyForDelivery:
        nextStatus = DeliveryStatus.outForDelivery;
        break;
      case DeliveryStatus.outForDelivery:
        nextStatus = DeliveryStatus.delivered;
        newStatus = 'completed';
        break;
      default:
        return;
    }

    setState(() => _isUpdating = true);

    try {
      await Supabase.instance.client
          .from('orders')
          .update({
            'delivery_status': nextStatus.name,
            'status': newStatus,
            'completed_at': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
          })
          .eq('id', _order.id);

      setState(() {
        _order = _order.copyWith(
          deliveryStatus: nextStatus,
          status: newStatus,
        );
        _isUpdating = false;
      });
    } catch (e) {
      setState(() => _isUpdating = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Delivery Monitoring")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMapSection(),
            const SizedBox(height: 24),
            _buildInfoCard(),
            if (_order.deliveryProofUrl != null && _order.deliveryProofUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildProofOfDeliveryCard(),
            ],
            const SizedBox(height: 24),
            _buildRiderAssignment(),
            const SizedBox(height: 24),
            if (_order.deliveryStatus != DeliveryStatus.delivered && _order.status.toLowerCase() != 'completed')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _updateStatus,
                  icon: _isUpdating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  label: Text(
                    _isUpdating ? "UPDATING..." : _nextStatusLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    final customerPos = LatLng(
      _order.customerDetails?.latitude ?? DeliveryServiceArea.storeLocation.latitude,
      _order.customerDetails?.longitude ?? DeliveryServiceArea.storeLocation.longitude,
    );
    final storePos = DeliveryServiceArea.storeLocation;

    return SizedBox(
      height: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: _order.riderId == null 
        ? FlutterMap(
            options: MapOptions(initialCenter: customerPos, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: _mapService.tileUrlTemplate,
                userAgentPackageName: 'com.bellies_smartserve',
              ),
              MarkerLayer(markers: [
                Marker(point: storePos, child: const Icon(Icons.store, color: Colors.blue, size: 30)),
                Marker(point: customerPos, child: const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 40)),
              ]),
              RichAttributionWidget(attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                ),
              ]),
            ],
          )
        : StreamBuilder<Map<String, double>?>(
            stream: _trackingRepo.streamRiderLocation(_order.riderId!),
            builder: (context, snapshot) {
              final riderPos = snapshot.data != null ? LatLng(snapshot.data!['lat']!, snapshot.data!['lng']!) : null;
              return FlutterMap(
                options: MapOptions(initialCenter: riderPos ?? customerPos, initialZoom: 14),
                children: [
                  TileLayer(
                    urlTemplate: _mapService.tileUrlTemplate,
                    userAgentPackageName: 'com.bellies_smartserve',
                  ),
                  MarkerLayer(markers: [
                    Marker(point: storePos, child: const Icon(Icons.store, color: Colors.blue, size: 30)),
                    Marker(point: customerPos, child: const Icon(Icons.location_on, color: Color(0xFFE91E63), size: 40)),
                    if (riderPos != null)
                      Marker(point: riderPos, child: const Icon(Icons.motorcycle, color: Colors.orange, size: 35)),
                  ]),
                  RichAttributionWidget(attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
                    ),
                  ]),
                ],
              );
            },
          ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Tracking: ${_order.trackingNumber}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            _row("Customer:", _order.customerDetails?.name ?? 'N/A'),
            _row("Contact:", _order.customerDetails?.contact ?? 'N/A'),
            _row("Address:", _order.customerDetails?.fullAddress ?? 'N/A'),
            _row("Landmark:", _order.customerDetails?.landmark ?? 'N/A'),
            if (_order.customerDetails?.deliveryInstructions.isNotEmpty == true)
              _row("Instructions:", _order.customerDetails!.deliveryInstructions),
            const Divider(),
            _row("Payment:", _order.paymentMethod?.name.toUpperCase() ?? 'N/A'),
            _row("Total:", "₱${_order.totalAmount.toStringAsFixed(2)}"),
          ],
        ),
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

  Widget _buildProofOfDeliveryCard() {
    if (_order.deliveryProofUrl == null || _order.deliveryProofUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final proofUrl = _order.deliveryProofUrl!;
    final isDataUrl = proofUrl.startsWith('data:image');

    return Card(
      color: Colors.green.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 8),
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
                            child: const Center(
                              child: Text("Unable to load proof photo", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
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
      ),
    );
  }

  Widget _buildRiderAssignment() {
    final hasRider = _order.riderId != null && _order.riderId!.isNotEmpty;
    final assignedRiderName = _order.riderName ??
        _availableRiders
            .firstWhere(
              (r) => r.id == _order.riderId,
              orElse: () => UserModel(
                id: '',
                email: '',
                fullName: 'Assigned Rider',
                position: 'Rider',
                role: UserRole.rider,
                accountStatus: AccountStatus.active,
              ),
            )
            .fullName;

    // Display Assigned Card if rider is already assigned and user is not in reassign mode
    if (hasRider && !_isReassigning) {
      return Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 22),
                      SizedBox(width: 8),
                      Text("Assigned Rider", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  if (_order.deliveryStatus != DeliveryStatus.delivered &&
                      _order.status.toLowerCase() != 'completed')
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _isReassigning = true),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text("Reassign"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.green,
                    radius: 20,
                    child: Icon(Icons.person, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          assignedRiderName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          "Status: ${_formatStatus(_order.deliveryStatus)}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isReassigning ? "Reassign Rider" : "Rider Assignment",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_isReassigning)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _isReassigning = false),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedRiderId,
              decoration: const InputDecoration(
                labelText: "Select Rider",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _availableRiders.map((r) => DropdownMenuItem<String>(value: r.id, child: Text(r.fullName))).toList(),
              onChanged: (val) => setState(() => _selectedRiderId = val),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedRiderId == null || _isUpdating ? null : _assignRider,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text(_isReassigning ? "REASSIGN RIDER" : "ASSIGN RIDER"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStatus(DeliveryStatus? status) {
    if (status == null) return "PENDING";
    return status.name
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}')
        .toUpperCase();
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
