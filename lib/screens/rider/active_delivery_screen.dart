import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/order_model.dart';
import '../../repositories/rider_dashboard_repository.dart';
import '../../services/free_map_service.dart';
import '../../services/delivery_service_area.dart';
import '../../widgets/state_widgets.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final OrderModel order;
  const ActiveDeliveryScreen({super.key, required this.order});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final _repo = RiderDashboardRepository();
  final _mapService = FreeMapService();
  final MapController _mapController = MapController();

  bool _isUpdating = false;
  LatLng? _riderPos;
  List<LatLng> _routePolyline = [];
  double _distanceKm = 0;
  double _durationMin = 0;
  Timer? _locationTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    // 1. Request Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // 2. Initial Position
      Position pos = await Geolocator.getCurrentPosition();
      setState(() => _riderPos = LatLng(pos.latitude, pos.longitude));
      _updateRoute();

      // 3. Periodic Update to Supabase (Every 10 seconds)
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        if (_riderPos != null) {
          final riderId = Supabase.instance.client.auth.currentUser!.id;
          await _repo.updateRiderLocation(
            riderId,
            _riderPos!.latitude,
            _riderPos!.longitude,
          );
        }
      });

      // 4. Local Stream for Map UI (Real-time movement)
      _positionStream =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((Position position) {
            setState(
              () => _riderPos = LatLng(position.latitude, position.longitude),
            );
            // Recalculate route only if moved significantly or every few minutes
            _updateRoute();
          });
    }
  }

  Future<void> _updateRoute() async {
    if (_riderPos == null) return;
    final dest = LatLng(
      widget.order.customerDetails?.latitude ?? 0,
      widget.order.customerDetails?.longitude ?? 0,
    );

    final routeData = await _mapService.getRoute(start: _riderPos!, end: dest);
    if (routeData != null && mounted) {
      setState(() {
        _routePolyline = routeData['polyline'];
        _distanceKm = routeData['distance'];
        _durationMin = routeData['duration'];
      });
    }
  }

  void _recenter() {
    if (_riderPos != null) {
      _mapController.move(_riderPos!, 15);
    }
  }

  void _navigateExternal() async {
    final lat = widget.order.customerDetails?.latitude;
    final lng = widget.order.customerDetails?.longitude;
    if (lat != null && lng != null) {
      final url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
      );
      if (await canLaunchUrl(url)) await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerPos = LatLng(
      widget.order.customerDetails?.latitude ?? DeliveryServiceArea.storeLocation.latitude,
      widget.order.customerDetails?.longitude ?? DeliveryServiceArea.storeLocation.longitude,
    );

    return Scaffold(
      appBar: AppBar(title: Text("Order #${widget.order.queueNumber}")),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                flex: 4,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: customerPos,
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _mapService.tileUrlTemplate,
                      userAgentPackageName: 'com.bellies.smartserve',
                    ),
                    if (_routePolyline.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePolyline,
                            strokeWidth: 5,
                            color: const Color(0xFF2196F3),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // Customer Marker
                        Marker(
                          point: customerPos,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                        // Rider Marker
                        if (_riderPos != null)
                          Marker(
                            point: _riderPos!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.motorcycle,
                              color: Colors.orange,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                            Uri.parse('https://openstreetmap.org/copyright'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(flex: 3, child: _buildInfoPanel()),
            ],
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              tooltip: "Recenter Map to My GPS Location",
              onPressed: _recenter,
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _distanceKm > 0
                          ? "${_distanceKm.toStringAsFixed(1)} km"
                          : "Calculating...",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      _durationMin > 0
                          ? "~${_durationMin.toInt()} mins arrival"
                          : "Updating route...",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => launchUrl(
                    Uri.parse("tel:${widget.order.customerDetails?.contact}"),
                  ),
                  icon: const CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Icon(Icons.phone, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              widget.order.customerDetails?.name ?? "No Name",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.order.customerDetails?.address ?? "No Address",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_isUpdating) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        if (widget.order.deliveryStatus == DeliveryStatus.readyForDelivery)
          ElevatedButton(
            onPressed: () => _updateStatus('outForDelivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              minimumSize: const Size(double.infinity, 55),
            ),
            child: const Text("CONFIRM PICKUP & START"),
          ),
        if (widget.order.deliveryStatus == DeliveryStatus.outForDelivery)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _navigateExternal,
                  icon: const Icon(Icons.map),
                  label: const Text("GOOGLE MAPS"),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 55),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _showCompletionDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(0, 55),
                  ),
                  child: const Text("ARRIVED"),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _updateStatus(String deliveryStatus, {String? status, String? proofUrl}) async {
    setState(() => _isUpdating = true);
    try {
      await _repo.updateDeliveryStatus(
        widget.order.id,
        deliveryStatus,
        status: status,
        proofUrl: proofUrl,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        await showErrorDialog(
          context,
          title: 'Unable to Update Delivery',
          message: 'The delivery status could not be updated: $e',
        );
      }
    }
  }

  void _showCompletionDialog() {
    XFile? pickedProofImage;
    bool uploading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {

          bool isImageFile(XFile file) {
            final name = file.name.toLowerCase();
            final path = file.path.toLowerCase();
            final mime = file.mimeType?.toLowerCase() ?? '';

            if (mime.isNotEmpty && !mime.startsWith('image/')) {
              return false;
            }

            final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'];
            final hasValidExt = allowedExtensions.any((ext) => name.endsWith(ext) || path.endsWith(ext));

            return hasValidExt || mime.startsWith('image/');
          }

          Future<void> pickImage(ImageSource source) async {
            final picker = ImagePicker();
            final file = await picker.pickImage(
              source: source,
              imageQuality: 80,
              maxWidth: 1024,
            );
            if (file == null) return;

            if (!isImageFile(file)) {
              if (dialogContext.mounted) {
                await showErrorDialog(
                  dialogContext,
                  title: 'Invalid File Format',
                  message: 'Only image files (JPG, PNG, WEBP, HEIC) are accepted as Proof of Delivery. Documents (Word, Excel, PDF) are strictly prohibited.',
                );
              }
              return;
            }

            setDialogState(() => pickedProofImage = file);
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.camera_alt_outlined, color: Colors.green),
                SizedBox(width: 8),
                Text("Proof of Delivery"),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Please capture or upload a Proof of Delivery photo before completing.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: pickedProofImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: kIsWeb
                                ? Image.network(pickedProofImage!.path, fit: BoxFit.cover)
                                : Image.file(File(pickedProofImage!.path), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 8),
                              const Text("No Proof Photo Picked", style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text("CAMERA"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text("GALLERY"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: uploading ? null : () => Navigator.pop(dialogContext),
                child: const Text("CANCEL"),
              ),
              ElevatedButton.icon(
                onPressed: pickedProofImage == null || uploading
                    ? null
                    : () async {
                        final fileToUpload = pickedProofImage!;
                        setDialogState(() => uploading = true);
                        final nav = Navigator.of(dialogContext);
                        try {
                          final proofUrl = await _repo.uploadDeliveryProof(
                            widget.order.id,
                            fileToUpload,
                          );
                          nav.pop();
                          _updateStatus('delivered', status: 'completed', proofUrl: proofUrl);
                        } catch (e) {
                          setDialogState(() => uploading = false);
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text('Upload failed: $e')),
                            );
                          }
                        }
                      },
                icon: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(uploading ? "UPLOADING PROOF..." : "SUBMIT & COMPLETE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: pickedProofImage != null ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
