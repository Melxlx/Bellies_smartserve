import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/theme/app_colors.dart';
import '../services/delivery_service_area.dart';
import '../widgets/premium_action_button.dart';
import 'foodpanda_map_picker_dialog.dart';

class FoodpandaAddressSheet extends StatefulWidget {
  final String currentAddress;
  final ValueChanged<String> onAddressUpdated;

  const FoodpandaAddressSheet({
    super.key,
    required this.currentAddress,
    required this.onAddressUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentAddress,
    required ValueChanged<String> onAddressUpdated,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodpandaAddressSheet(
        currentAddress: currentAddress,
        onAddressUpdated: onAddressUpdated,
      ),
    );
  }

  @override
  State<FoodpandaAddressSheet> createState() => _FoodpandaAddressSheetState();
}

class _FoodpandaAddressSheetState extends State<FoodpandaAddressSheet> {
  late final TextEditingController _addressController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.currentAddress);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) return;

    setState(() => _isSaving = true);
    final user = Supabase.instance.client.auth.currentUser;

    if (user != null) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'address': newAddress})
            .eq('id', user.id);
      } catch (e) {
        debugPrint("Error updating profile address: $e");
      }
    }

    widget.onAddressUpdated(newAddress);
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeLocation = DeliveryServiceArea.storeLocation;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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

          // Country & Region Row
          Row(
            children: [
              const Icon(Icons.language_rounded, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Text("🇵🇭", style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                "Philippines",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                child: Text(
                  _isEditing ? "Cancel" : "Change",
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mini Map Card (Tapping opens full-screen interactive Foodpanda location picker map)
          GestureDetector(
            onTap: () async {
              final newAddress = await FoodpandaMapPickerDialog.show(
                context,
                initialPosition: storeLocation,
                initialAddress: widget.currentAddress,
              );
              if (newAddress != null && newAddress.isNotEmpty) {
                _addressController.text = newAddress;
                await _saveAddress();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.lightPink, width: 1.2),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: storeLocation,
                        initialZoom: 13.5,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
                          userAgentPackageName: 'com.example.bellies_smartserve',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: storeLocation,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                                ),
                                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fullscreen_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text("TAP TO PIN MAP", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current Location Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightPink),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.lightPink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Current Location",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.currentAddress.isNotEmpty
                            ? widget.currentAddress
                            : "Isabela, Philippines",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isEditing) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: "New Delivery Address",
                hintText: "Enter Street, Barangay, City, Province",
                prefixIcon: const Icon(Icons.edit_location_alt_rounded, color: AppColors.primary),
                filled: true,
                fillColor: const Color(0xFFF9F9FB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            PremiumActionButton(
              label: "SAVE NEW ADDRESS",
              icon: Icons.check_circle_rounded,
              isLoading: _isSaving,
              onPressed: _saveAddress,
            ),
          ] else ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => setState(() => _isEditing = true),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Add / Edit Delivery Address",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
