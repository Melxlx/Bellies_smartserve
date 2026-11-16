import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/app_colors.dart';
import '../services/device_location_service.dart';
import '../services/free_map_service.dart';
import '../widgets/premium_action_button.dart';

class FoodpandaMapPickerDialog extends StatefulWidget {
  final LatLng initialPosition;
  final String initialAddress;

  const FoodpandaMapPickerDialog({
    super.key,
    required this.initialPosition,
    required this.initialAddress,
  });

  static Future<String?> show(
    BuildContext context, {
    required LatLng initialPosition,
    required String initialAddress,
  }) async {
    return await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => FoodpandaMapPickerDialog(
        initialPosition: initialPosition,
        initialAddress: initialAddress,
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<FoodpandaMapPickerDialog> createState() => _FoodpandaMapPickerDialogState();
}

class _FoodpandaMapPickerDialogState extends State<FoodpandaMapPickerDialog> {
  final _freeMapService = FreeMapService();
  late final MapController _mapController;
  late LatLng _currentCenter;
  late final TextEditingController _addressController;
  bool _isLocatingGps = false;
  Timer? _geocodeTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentCenter = widget.initialPosition;
    final initialText = (widget.initialAddress.isNotEmpty && widget.initialAddress != 'Isabela')
        ? widget.initialAddress
        : "Pinned Location, Laguna";
    _addressController = TextEditingController(text: initialText);
    _acquireGpsLocation();
  }

  @override
  void dispose() {
    _geocodeTimer?.cancel();
    _mapController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _reverseGeocodeCenter(LatLng pos) async {
    final address = await _freeMapService.reverseGeocode(pos);
    if (mounted) {
      setState(() {
        if (address != null && address.trim().isNotEmpty && address != 'Isabela') {
          _addressController.text = address;
        } else {
          _addressController.text = "Pinned Location, Laguna";
        }
      });
    }
  }

  Future<void> _acquireGpsLocation() async {
    setState(() => _isLocatingGps = true);
    try {
      final pos = await DeviceLocationService().currentPosition();
      if (mounted) {
        _mapController.move(pos, 16.0);
        setState(() {
          _currentCenter = pos;
          _isLocatingGps = false;
        });
        await _reverseGeocodeCenter(pos);
      }
    } catch (e) {
      debugPrint("GPS location error: $e");
      if (mounted) {
        setState(() => _isLocatingGps = false);
        await _reverseGeocodeCenter(_currentCenter);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full Screen Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.5,
              onTap: (tapPosition, point) {
                _mapController.move(point, _mapController.camera.zoom);
                setState(() {
                  _currentCenter = point;
                });
                _geocodeTimer?.cancel();
                _reverseGeocodeCenter(point);
              },
              onPositionChanged: (pos, hasGesture) {
                _currentCenter = pos.center;
                if (hasGesture) {
                  _geocodeTimer?.cancel();
                  _geocodeTimer = Timer(const Duration(milliseconds: 350), () {
                    _reverseGeocodeCenter(pos.center);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.example.bellies_smartserve',
              ),
            ],
          ),

          // Center Fixed Pink Pin Marker (Locked at dead center of screen as map moves!)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(
                    Icons.location_on_rounded,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),

          // Top Left Close Button (X Circle)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.black87, size: 20),
                  onPressed: () => Navigator.pop(context),
                  tooltip: "Close Map",
                ),
              ),
            ),
          ),

          // Bottom Right Real-Time GPS Target Button (Elevated above bottom sheet)
          Positioned(
            right: 16,
            bottom: 275,
            child: Material(
              elevation: 6,
              shape: const CircleBorder(),
              color: Colors.white,
              shadowColor: Colors.black38,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: _isLocatingGps
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 22),
                  onPressed: _isLocatingGps ? null : _acquireGpsLocation,
                  tooltip: "Pin My Exact GPS Location",
                ),
              ),
            ),
          ),

          // Bottom Foodpanda Information Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location Title Row
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.textPrimary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _addressController.text.isNotEmpty ? _addressController.text : "Isabela",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary, size: 20),
                        onPressed: () => _showEditAddressDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info Alert Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBEE3F8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF2B6CB0), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Your rider will deliver to the pinned location. You can edit your written address on the next page.",
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: const Color(0xFF2C5282),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Confirm CTA Button
                  PremiumActionButton(
                    label: "Add Address Details",
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      Navigator.pop(context, _addressController.text.trim());
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit Address Text", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: _addressController,
          decoration: InputDecoration(
            hintText: "Enter Street, Barangay, City",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }
}
