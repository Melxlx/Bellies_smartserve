import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/responsive_layout.dart';
import '../../models/customer_checkout_draft.dart';
import '../../models/order_model.dart';
import '../../services/delivery_service_area.dart';
import '../../widgets/premium_action_button.dart';
import '../../widgets/product_image.dart';
import 'delivery_address_screen.dart';
import 'customer_checkout_screen.dart';

class OrderReviewScreen extends StatefulWidget {
  final List<OrderItem> cart;
  final CustomerCheckoutDraft? draft;

  const OrderReviewScreen({
    super.key,
    required this.cart,
    this.draft,
  });

  @override
  State<OrderReviewScreen> createState() => _OrderReviewScreenState();
}

class _OrderReviewScreenState extends State<OrderReviewScreen> {
  late final CustomerCheckoutDraft _draft;
  bool _highlightAddressError = false;

  double get _subtotal => widget.cart.fold(0, (sum, item) => sum + item.total);
  double get _deliveryFee => _draft.details?.calculatedDeliveryFee ?? 30.0;
  double get _deliveryDistanceKm => _draft.details?.deliveryDistanceKm ?? 0.0;
  double get _total => _subtotal + _deliveryFee;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? CustomerCheckoutDraft();
    _prefillSavedAddress();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });
  }

  Future<void> _prefillSavedAddress() async {
    if (_draft.hasConfirmedAddress) return;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && !user.isAnonymous) {
        final profileData = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null && mounted) {
          final String name = profileData['full_name'] ?? '';
          final String phone = profileData['contact_number'] ?? '';
          final String address = profileData['address'] ?? '';

          if (address.isNotEmpty) {
            final details = CustomerDetails(
              name: name.isNotEmpty ? name : 'Valued Customer',
              contact: phone,
              address: address,
              landmark: '',
              notes: '',
              locationConfirmed: true,
              calculatedDeliveryFee: 30.0,
            );
            setState(() {
              _draft.details = details;
            });
          }
        }
      }
    } catch (_) {}
  }

  void _chooseAddress() async {
    final CustomerDetails? initialDetails = _draft.details;
    final confirmed = await Navigator.of(context).push<CustomerDetails>(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.deliveryAddress),
        builder: (_) => DeliveryAddressScreen(
          initialDetails: initialDetails,
          onDraftChanged: (updated) {
            if (mounted) {
              setState(() {
                _draft.details = updated;
              });
            }
          },
        ),
      ),
    );

    if (confirmed != null && mounted) {
      setState(() {
        _draft.details = confirmed;
        _highlightAddressError = false;
      });
    }
  }

  void _proceedToPayment() {
    if (!_draft.hasConfirmedAddress) {
      setState(() {
        _highlightAddressError = true;
      });
      _chooseAddress();
      return;
    }

    final address = _draft.details?.address ?? '';
    final lat = _draft.details?.latitude ?? DeliveryServiceArea.storeLocation.latitude;
    final lng = _draft.details?.longitude ?? DeliveryServiceArea.storeLocation.longitude;
    final inRange = DeliveryServiceArea.isWithinServiceArea(LatLng(lat, lng), address);

    if (!inRange) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
              const SizedBox(width: 10),
              Text("Outside Delivery Area", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            "Sorry! Bellie’s SmartServe delivers exclusively within Sta. Cruz, Pagsanjan, and Pila, Laguna. Your delivery address ($address) is outside our delivery range.",
            style: GoogleFonts.inter(fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text("OK"),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerCheckoutScreen(
          cart: widget.cart,
          draft: _draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = _draft.details;
    final hasAddress = _draft.hasConfirmedAddress;
    final bool isDesktop = ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Review Your Order",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: widget.cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Your cart is empty", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text("Back to Menu", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 960 : double.infinity),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // Step Indicator Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.lightPink,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Step 1: Order Summary & Review",
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                ),
                                Text(
                                  "Please review your items and delivery details before checkout.",
                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Delivery Information Summary Card (Tap to Choose Address)
                    Text("Delivery Details", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _chooseAddress,
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _highlightAddressError ? const Color(0xFFFFF0F2) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: _highlightAddressError ? const Color(0xFFFF2D55) : (hasAddress ? AppColors.lightPink : Colors.grey.shade300),
                            width: _highlightAddressError ? 2.5 : 1.2,
                          ),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasAddress ? Icons.location_on_rounded : Icons.add_location_alt_rounded,
                              color: _highlightAddressError ? const Color(0xFFFF2D55) : AppColors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasAddress ? (details!.name.isNotEmpty ? details.name : 'Delivery Address') : 'No delivery address set',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: _highlightAddressError ? const Color(0xFFD32F2F) : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasAddress ? details!.fullAddress : 'Tap to choose delivery address & pin map',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.lightPink,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                hasAddress ? "CHANGE" : "CHOOSE",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Order Items List Card
                    Text("Order Items (${widget.cart.length})", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.cart.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = widget.cart[index];
                          return Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: ProductImage(
                                      path: item.product.imagePath ?? '',
                                      productName: item.product.name,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.instructions != null && item.instructions!.isNotEmpty)
                                        Text(
                                          "Note: ${item.instructions}",
                                          style: GoogleFonts.inter(fontSize: 11, color: Colors.orange.shade800),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "₱${item.product.sellingPrice.toStringAsFixed(2)} × ${item.quantity}",
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  "₱${item.total.toStringAsFixed(2)}",
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cost Breakdown Card
                    Text("Payment Summary", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        children: [
                          _summaryRow('Items Subtotal', '₱${_subtotal.toStringAsFixed(2)}'),
                          const SizedBox(height: 8),
                          _summaryRow('Delivery Distance', _deliveryDistanceKm > 0 ? '${_deliveryDistanceKm.toStringAsFixed(1)} km' : 'Standard'),
                          const SizedBox(height: 8),
                          _summaryRow('Delivery Fee', '₱${_deliveryFee.toStringAsFixed(2)}'),
                          const Divider(height: 24),
                          _summaryRow('Total Amount', '₱${_total.toStringAsFixed(2)}', isTotal: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Proceed to Payment CTA Button
                    PremiumActionButton(
                      label: "PROCEED TO PAYMENT",
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _proceedToPayment,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 16 : 13.5,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 18 : 13.5,
            fontWeight: FontWeight.bold,
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
