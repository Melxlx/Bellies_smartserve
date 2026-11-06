import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/order_model.dart';
import '../../services/free_search_service.dart';
import '../../services/free_map_service.dart';
import '../../services/delivery_service_area.dart';
import '../../services/delivery_fee_calculator.dart';
import '../../widgets/state_widgets.dart';

class DeliveryAddressScreen extends StatefulWidget {
  final CustomerDetails? initialDetails;
  final ValueChanged<CustomerDetails> onDraftChanged;

  const DeliveryAddressScreen({
    super.key,
    this.initialDetails,
    required this.onDraftChanged,
  });

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  final _searchService = FreeSearchService();
  final _mapService = FreeMapService();
  final _feeCalculator = DeliveryFeeCalculatorService();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _unitController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _notesController = TextEditingController();

  final MapController _mapController = MapController();
  LatLng _mapCenter = DeliveryServiceArea.storeLocation;
  LatLng? _selectedPoint;
  bool _isLocating = false;
  bool _isSearching = false;
  bool _isCalculatingFee = false;
  bool _isOutsideServiceArea = false;
  
  double? _calculatedDistanceKm;
  double? _calculatedDeliveryFee;
  String? _routingError;

  @override
  void initState() {
    super.initState();
    if (widget.initialDetails != null) {
      _nameController.text = widget.initialDetails!.name;
      _phoneController.text = widget.initialDetails!.contact;
      _unitController.text = widget.initialDetails!.houseUnit;
      _streetController.text = widget.initialDetails!.address;
      _landmarkController.text = widget.initialDetails!.landmark;
      _notesController.text = widget.initialDetails!.deliveryInstructions;
      _calculatedDistanceKm = widget.initialDetails!.deliveryDistanceKm;
      _calculatedDeliveryFee = widget.initialDetails!.calculatedDeliveryFee;
      if (widget.initialDetails!.latitude != null) {
        _selectedPoint = LatLng(
          widget.initialDetails!.latitude!,
          widget.initialDetails!.longitude!,
        );
        _mapCenter = _selectedPoint!;
        _checkServiceArea(_selectedPoint!, _streetController.text);
      }
    }
  }

  void _checkServiceArea(LatLng point, String? addressText) {
    final bool valid = DeliveryServiceArea.isWithinServiceArea(point, addressText);
    setState(() {
      _isOutsideServiceArea = !valid;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final point = LatLng(pos.latitude, pos.longitude);
      _selectMapPoint(point);
    } catch (e) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Location Unavailable',
          message: 'Could not get your current location. Check GPS settings and permissions.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _selectMapPoint(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _isSearching = true;
      _isCalculatingFee = true;
      _routingError = null;
    });
    _mapController.move(point, 14);

    final addressFuture = _searchService.reverseGeocode(point);
    final routeFuture = _feeCalculator.calculateDeliveryFee(destination: point);

    final address = await addressFuture;
    final feeResult = await routeFuture;

    if (mounted) {
      _checkServiceArea(point, address);
      setState(() {
        if (address != null) _streetController.text = address;
        _isSearching = false;
        _isCalculatingFee = false;
        if (feeResult.isSuccess) {
          _calculatedDistanceKm = feeResult.distanceKm;
          _calculatedDeliveryFee = feeResult.deliveryFee;
          _routingError = null;
        } else {
          _calculatedDistanceKm = null;
          _calculatedDeliveryFee = null;
          _routingError = feeResult.errorMessage;
        }
      });

      if (_isOutsideServiceArea) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⚠️ Outside active delivery area (Sta. Cruz, Pagsanjan, or Pila only)."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate() || _selectedPoint == null) {
      await showErrorDialog(
        context,
        title: 'Incomplete Delivery Address',
        message: 'Tap the map to set a delivery point and fill in the required fields.',
      );
      return;
    }

    if (_isOutsideServiceArea || !DeliveryServiceArea.isWithinServiceArea(_selectedPoint!, _streetController.text)) {
      await showErrorDialog(
        context,
        title: 'Outside Delivery Area',
        message: 'Sorry, delivery is strictly available for Sta. Cruz, Pagsanjan, and Pila, Laguna only.',
      );
      return;
    }

    if (_routingError != null || _calculatedDeliveryFee == null) {
      await showErrorDialog(
        context,
        title: 'Delivery Routing Error',
        message: _routingError ?? 'Unable to calculate road distance to your location. Please re-pin your address on the map or retry.',
      );
      return;
    }

    final details = CustomerDetails(
      name: _nameController.text.trim(),
      contact: _phoneController.text.trim(),
      address: _streetController.text.trim(),
      houseUnit: _unitController.text.trim(),
      landmark: _landmarkController.text.trim(),
      notes: '',
      deliveryInstructions: _notesController.text.trim(),
      latitude: _selectedPoint!.latitude,
      longitude: _selectedPoint!.longitude,
      locationConfirmed: true,
      deliveryDistanceKm: _calculatedDistanceKm,
      calculatedDeliveryFee: _calculatedDeliveryFee,
    );

    widget.onDraftChanged(details);
    Navigator.pop(context, details);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Delivery Location"),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMap(),
            if (_isOutsideServiceArea)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.amber.shade100,
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Location outside delivery zone. We strictly deliver within Sta. Cruz, Pagsanjan, & Pila only.",
                        style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (_selectedPoint != null && !_isOutsideServiceArea)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: _routingError != null ? Colors.red.shade50 : const Color(0xFFE8F5E9),
                child: Row(
                  children: [
                    Icon(
                      _routingError != null ? Icons.error_outline : Icons.local_shipping_rounded,
                      color: _routingError != null ? Colors.red : Colors.green.shade800,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _isCalculatingFee
                          ? const Text(
                              "Calculating road distance and delivery fee...",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            )
                          : _routingError != null
                              ? Text(
                                  _routingError!,
                                  style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                                )
                              : Text(
                                  "Road Distance: ${_calculatedDistanceKm?.toStringAsFixed(1)} km · Delivery Fee: ₱${_calculatedDeliveryFee?.toStringAsFixed(2)}",
                                  style: TextStyle(fontSize: 13, color: Colors.green.shade900, fontWeight: FontWeight.bold),
                                ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isSearching && !_isCalculatingFee,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: "Recipient Name",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Recipient Name is required';
                        if (v.trim().length < 2) return 'Name must be at least 2 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isSearching && !_isCalculatingFee,
                      maxLength: 13,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                      decoration: const InputDecoration(
                        labelText: "Phone Number (e.g. 09171234567, +639171234567)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Phone number required';
                        final cleaned = v.trim().replaceAll(RegExp(r'[\s()\-]'), '');
                        if (!RegExp(r'^(09|\+?639)\d{9}$').hasMatch(cleaned)) {
                          return 'Invalid PH mobile (09XXXXXXXXX or +639XXXXXXXXX)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _unitController,
                      enabled: !_isSearching && !_isCalculatingFee,
                      maxLength: 20,
                      decoration: const InputDecoration(
                        labelText: "House/Unit/Floor No.",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _streetController,
                      maxLines: 2,
                      readOnly: true,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: "Street Address (Auto-filled by Map)",
                        border: const OutlineInputBorder(),
                        suffixIcon: (_isSearching || _isCalculatingFee)
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Tap the map to set address'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _landmarkController,
                      enabled: !_isSearching && !_isCalculatingFee,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: "Landmark / Instructions",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: (_isSearching || _isCalculatingFee || _isOutsideServiceArea || _routingError != null)
                            ? null
                            : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                        ),
                        child: Text(
                          _isOutsideServiceArea
                              ? "OUTSIDE DELIVERY AREA"
                              : (_isCalculatingFee
                                  ? "CALCULATING DELIVERY ROUTE..."
                                  : "CONFIRM THIS LOCATION"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return SizedBox(
      height: 350,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 13,
              onTap: (_, p) => _selectMapPoint(p),
            ),
            children: [
              TileLayer(
                urlTemplate: _mapService.tileUrlTemplate,
                userAgentPackageName: 'com.bellies_smartserve',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: DeliveryServiceArea.storeLocation,
                    radius: DeliveryServiceArea.maxRadiusKm * 1000,
                    useRadiusInMeter: true,
                    color: const Color(0xFFE91E63).withAlpha(30),
                    borderColor: const Color(0xFFE91E63),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: DeliveryServiceArea.storeLocation,
                    width: 100,
                    height: 80,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "Bellie's Kitchen",
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFFE91E63),
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                  if (_selectedPoint != null)
                    Marker(
                      point: _selectedPoint!,
                      width: 100,
                      height: 80,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _isOutsideServiceArea ? Colors.grey : const Color(0xFFE91E63),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _isOutsideServiceArea ? "UNAVAILABLE" : "DELIVER HERE",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.location_on,
                            color: _isOutsideServiceArea ? Colors.grey : const Color(0xFFE91E63),
                            size: 40,
                          ),
                        ],
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
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Color(0xFFE91E63), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Delivery Zone: Sta. Cruz, Pagsanjan, & Pila (Laguna)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              tooltip: "Locate My Current GPS Position",
              onPressed: _isLocating ? null : _useCurrentLocation,
              child: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFFE91E63)),
            ),
          ),
        ],
      ),
    );
  }
}
