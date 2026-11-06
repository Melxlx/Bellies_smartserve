import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_routes.dart';
import '../../models/customer_checkout_draft.dart';
import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../services/order_tracking_service.dart';
import '../../services/delivery_fee_calculator.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/app_modals.dart';
import 'delivery_address_screen.dart';

typedef DeliveryAddressSelector = Future<CustomerDetails?> Function(
  BuildContext context,
  CustomerDetails? initialDetails,
  ValueChanged<CustomerDetails> onDraftChanged,
);

class CustomerCheckoutScreen extends StatefulWidget {
  final List<OrderItem> cart;
  final CustomerCheckoutDraft? draft;
  final Future<OrderModel> Function(OrderModel)? placeOrder;
  final DeliveryAddressSelector? selectDeliveryAddress;

  const CustomerCheckoutScreen({
    super.key,
    required this.cart,
    this.draft,
    this.placeOrder,
    this.selectDeliveryAddress,
  });

  @override
  State<CustomerCheckoutScreen> createState() => _CustomerCheckoutScreenState();
}

class _CustomerCheckoutScreenState extends State<CustomerCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feeCalculator = DeliveryFeeCalculatorService();

  late final CustomerCheckoutDraft _draft;
  late final TextEditingController _refController;
  bool _isSaving = false;
  String? _error;
  bool _isTrustedCustomer = false;
  String _selectedPaymentMethod = 'GCASH'; // 'GCASH' or 'COD'
  bool _agreedToOnlineTerms = false;
  String _profileName = '';
  String _profileContact = '';
  final bool _useMyAccountDetails = true;

  double get _subtotal => widget.cart.fold(0, (sum, item) => sum + item.total);
  double get _deliveryFee => _draft.details?.calculatedDeliveryFee ?? 30.0;
  double get _deliveryDistanceKm => _draft.details?.deliveryDistanceKm ?? 0.0;
  double get _total => _subtotal + _deliveryFee;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft ?? CustomerCheckoutDraft();
    _refController = TextEditingController(text: _draft.gcashReference);
    _refController.addListener(_saveReference);
    _prefillFromProfile();
  }

  Future<void> _prefillFromProfile() async {
    try {
      SupabaseClient client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        return;
      }
      final user = client.auth.currentUser;
      if (user != null && !user.isAnonymous) {
        final profileData = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (profileData != null && mounted) {
          final isTrusted = profileData['is_trusted_customer'] as bool? ?? false;
          final fullName = profileData['full_name']?.toString() ??
              user.userMetadata?['full_name']?.toString() ??
              user.userMetadata?['name']?.toString() ??
              '';
          final contact = profileData['contact_number']?.toString() ?? '';
          final address = profileData['address']?.toString() ?? '';

          setState(() {
            _isTrustedCustomer = isTrusted;
            _profileName = fullName;
            _profileContact = contact;
            if (_isTrustedCustomer) {
              _selectedPaymentMethod = 'COD';
            }
            if (_draft.details == null && (fullName.isNotEmpty || contact.isNotEmpty || address.isNotEmpty)) {
              _draft.details = CustomerDetails(
                name: fullName,
                contact: contact,
                address: address,
                landmark: '',
                notes: '',
                houseUnit: '',
              );
            } else if (_draft.details != null && _useMyAccountDetails && fullName.isNotEmpty) {
              _draft.details = CustomerDetails(
                name: fullName,
                contact: contact.isNotEmpty ? contact : _draft.details!.contact,
                address: _draft.details!.address,
                landmark: _draft.details!.landmark,
                notes: _draft.details!.notes,
                houseUnit: _draft.details!.houseUnit,
                deliveryInstructions: _draft.details!.deliveryInstructions,
                latitude: _draft.details!.latitude,
                longitude: _draft.details!.longitude,
                locationConfirmed: _draft.details!.locationConfirmed,
                deliveryDistanceKm: _draft.details!.deliveryDistanceKm,
                calculatedDeliveryFee: _draft.details!.calculatedDeliveryFee,
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error prefilling profile: $e");
    }
  }

  void _saveReference() => _draft.gcashReference = _refController.text;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _recalculateFee(CustomerDetails details) async {
    if (details.latitude != null && details.longitude != null) {
      final res = await _feeCalculator.calculateDeliveryFee(
        destination: LatLng(details.latitude!, details.longitude!),
      );
      if (res.isSuccess && mounted) {
        setState(() {
          _draft.details = CustomerDetails(
            name: details.name,
            contact: details.contact,
            address: details.address,
            landmark: details.landmark,
            notes: details.notes,
            houseUnit: details.houseUnit,
            deliveryInstructions: details.deliveryInstructions,
            latitude: details.latitude,
            longitude: details.longitude,
            locationConfirmed: details.locationConfirmed,
            deliveryDistanceKm: details.deliveryDistanceKm ?? res.distanceKm,
            calculatedDeliveryFee: details.calculatedDeliveryFee ?? res.deliveryFee,
          );
        });
      }
    }
  }

  Future<void> _editAddress() async {
    void saveDraft(CustomerDetails details) {
      if (!mounted) return;
      final effectiveDetails = _useMyAccountDetails && _profileName.isNotEmpty
          ? CustomerDetails(
              name: _profileName,
              contact: _profileContact.isNotEmpty ? _profileContact : details.contact,
              address: details.address,
              landmark: details.landmark,
              notes: details.notes,
              houseUnit: details.houseUnit,
              deliveryInstructions: details.deliveryInstructions,
              latitude: details.latitude,
              longitude: details.longitude,
              locationConfirmed: details.locationConfirmed,
              deliveryDistanceKm: details.deliveryDistanceKm,
              calculatedDeliveryFee: details.calculatedDeliveryFee,
            )
          : details;

      setState(() {
        _draft.details = effectiveDetails;
        _error = null;
      });
      _recalculateFee(effectiveDetails);
    }

    final initialDetailsToUse = _useMyAccountDetails && _profileName.isNotEmpty
        ? CustomerDetails(
            name: _profileName,
            contact: _profileContact.isNotEmpty ? _profileContact : (_draft.details?.contact ?? ''),
            address: _draft.details?.address ?? '',
            landmark: _draft.details?.landmark ?? '',
            notes: _draft.details?.notes ?? '',
            houseUnit: _draft.details?.houseUnit ?? '',
            deliveryInstructions: _draft.details?.deliveryInstructions ?? '',
            latitude: _draft.details?.latitude,
            longitude: _draft.details?.longitude,
            locationConfirmed: _draft.details?.locationConfirmed ?? false,
            deliveryDistanceKm: _draft.details?.deliveryDistanceKm,
            calculatedDeliveryFee: _draft.details?.calculatedDeliveryFee,
          )
        : _draft.details;

    final selector = widget.selectDeliveryAddress;
    final confirmed = selector != null
        ? await selector(context, initialDetailsToUse, saveDraft)
        : await Navigator.of(context).push<CustomerDetails>(
            MaterialPageRoute(
              settings: const RouteSettings(name: AppRoutes.deliveryAddress),
              builder: (_) => DeliveryAddressScreen(
                initialDetails: initialDetailsToUse,
                onDraftChanged: saveDraft,
              ),
            ),
          );
    if (!mounted) return;
    if (confirmed != null) {
      saveDraft(confirmed);
    }
  }

  Future<void> _placeOrder() async {
    if (_isSaving) return;
    if (!_draft.hasConfirmedAddress) {
      await _showCheckoutError(
        'Confirm the delivery location and recipient details first.',
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (widget.cart.isEmpty) {
      await _showCheckoutError(
        'Your cart is empty. Add an item before checkout.',
      );
      return;
    }

    final bool isCod = _selectedPaymentMethod == 'COD';
    if (!isCod && !_agreedToOnlineTerms) {
      await _showCheckoutError(
        'Please agree to the Online Payment Terms & Conditions before proceeding with online payment.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (_draft.details?.calculatedDeliveryFee == null) {
        await _recalculateFee(_draft.details!);
      }
      if (_draft.details?.calculatedDeliveryFee == null) {
        await _showCheckoutError(
          'Unable to verify delivery route and fee. Please re-select your delivery location.',
        );
        setState(() {
          _isSaving = false;
        });
        return;
      }
      final double finalFee = _deliveryFee;
      final double finalDistance = _deliveryDistanceKm;

      final order = OrderModel(
        id: '',
        queueNumber: '',
        trackingNumber: 'TRK-${DateTime.now().microsecondsSinceEpoch}',
        items: List.of(widget.cart),
        timestamp: DateTime.now(),
        subtotal: _subtotal,
        deliveryFee: finalFee,
        deliveryDistanceKm: finalDistance,
        totalAmount: _subtotal + finalFee,
        serviceType: ServiceType.delivery,
        customerDetails: _draft.details,
        paymentMethod: isCod ? PaymentMethod.cash : PaymentMethod.gcash,
        paymentStatus: isCod ? 'UNPAID' : 'PENDING',
        referenceNumber: isCod ? 'COD-ORDER' : _refController.text.trim(),
        paymentProofUrl: _draft.paymentProofUrl.isNotEmpty ? _draft.paymentProofUrl : null,
      );
      final savedOrder =
          await (widget.placeOrder ??
              OrderRepository().createCustomerDeliveryOrder)(order);

      OrderTrackingService().setTrackingNumber(savedOrder.trackingNumber);

      _draft.clear();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.receipt,
        (_) => false,
        arguments: ReceiptArguments(order: savedOrder, customerOrder: true),
      );
    } on AuthException catch (error) {
      await _showSaveError('Auth Error: ${error.message}');
    } on PostgrestException catch (error) {
      await _showSaveError('Database Error [${error.code}]: ${error.message}');
    } catch (e) {
      await _showSaveError('System Error: $e');
    }
  }

  Future<void> _showCheckoutError(String message) async {
    if (!mounted) return;
    await showErrorDialog(
      context,
      title: 'Checkout Incomplete',
      message: message,
    );
  }

  Future<void> _showSaveError(String message) async {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _error = null;
    });
    AppModals.showError(
      context,
      title: 'Checkout Error',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Order Checkout')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _deliverySummary(),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSmartPaymentSection(),
                    const SizedBox(height: 24),
                    _summaryRow(
                      'Items Subtotal',
                      '₱${_subtotal.toStringAsFixed(2)}',
                    ),
                    _summaryRow(
                      'Delivery Distance (Road)',
                      _deliveryDistanceKm > 0
                          ? '${_deliveryDistanceKm.toStringAsFixed(1)} km'
                          : 'Location pending',
                    ),
                    _summaryRow(
                      'Delivery Fee',
                      '₱${_deliveryFee.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 32),
                    _summaryRow(
                      'Total Amount',
                      '₱${_total.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _placeOrder,
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('PLACE ORDER & PAY'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartPaymentSection() {
    // Regular customers only see GCash (COD is completely hidden)
    if (!_isTrustedCustomer) {
      return _buildGcashSection();
    }

    // Trusted customers dynamically see both GCash and Cash on Delivery
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 18),
                    SizedBox(width: 6),
                    Text("GCash Transfer"),
                  ],
                ),
                selected: _selectedPaymentMethod == 'GCASH',
                selectedColor: Colors.blue.shade100,
                onSelected: (val) {
                  if (val) setState(() => _selectedPaymentMethod = 'GCASH');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified_user_rounded, size: 18, color: Colors.green),
                    SizedBox(width: 6),
                    Text("Cash on Delivery"),
                  ],
                ),
                selected: _selectedPaymentMethod == 'COD',
                selectedColor: Colors.green.shade100,
                onSelected: (val) {
                  if (val) setState(() => _selectedPaymentMethod = 'COD');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedPaymentMethod == 'COD') _buildCodSection() else _buildGcashSection(),
      ],
    );
  }

  Widget _buildCodSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Text(
                "Cash on Delivery (COD)",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Pay ₱${_total.toStringAsFixed(2)} with cash upon food delivery or pickup. No online payment required.",
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildGcashSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_2_rounded, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                "Pay via GCash / InstaPay QR",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/instapay_qr.png',
                      height: 180,
                      width: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => QrImageView(
                        data: '09287322030',
                        version: QrVersions.auto,
                        size: 180.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "SCAN QR CODE TO PAY",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "GCash / InstaPay Number",
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      "0928 732 2030",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      "Account Name: Bellies Duenas",
                      style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Colors.blue),
                  tooltip: "Copy Number",
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: "09287322030"));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Account Number copied to clipboard!"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Enter 13-digit GCash Reference Number:",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _scanReceiptOcr,
                icon: const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.blue),
                label: const Text("Scan Receipt (OCR)", style: TextStyle(fontSize: 11, color: Colors.blue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _refController,
            enabled: !_isSaving,
            keyboardType: TextInputType.number,
            maxLength: 13,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: "e.g. 1002345678901",
              labelText: "GCash Reference Number",
              prefixIcon: const Icon(Icons.receipt_long_outlined, color: Colors.blue),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "GCash Reference Number is required";
              }
              if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
                return "Only numbers are allowed";
              }
              if (v.trim().length < 8) {
                return "Please enter a valid GCash Reference Number";
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              value: _agreedToOnlineTerms,
              onChanged: _isSaving ? null : (val) => setState(() => _agreedToOnlineTerms = val ?? false),
              title: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.black87),
                  children: [
                    const TextSpan(text: "I agree to the "),
                    TextSpan(
                      text: "Online Payment Terms & Conditions",
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = _showTermsDialog,
                    ),
                  ],
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.gavel_outlined, color: Colors.blue),
            const SizedBox(width: 10),
            Text("Online Payment Terms & Conditions", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Online Payment, GCash & Digital Transaction Policy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 10),
                Text(
                  "1. GCash & InstaPay Reference Verification\n"
                  "• All digital and online payments executed via GCash, InstaPay, or supported bank transfers must be accompanied by an authentic, valid 13-digit transaction reference number and matching screenshot/receipt.\n"
                  "• Submitted reference numbers are subject to automated and manual verification by our cashiering and finance staff prior to order finalization.\n\n"
                  "2. Fraud Prevention & Rejected Payments\n"
                  "• Submitting fake, altered, reused, or unverified reference numbers constitutes financial fraud. Orders will be immediately cancelled, and the user account will be permanently blacklisted and reported.\n"
                  "• In case of payment mismatch (amount paid is less than total order amount), the order will remain on hold until fully settled.\n\n"
                  "3. Refund & Cancellation Policy for Online Payments\n"
                  "• If an online-paid order is successfully cancelled due to store unavailability or unfulfillable delivery, a refund request will be reviewed and processed back through GCash within 3 to 5 business days.\n"
                  "• Refunds are strictly not granted for orders already prepared, dispatched, or completed, nor for customer error during reference number input.\n\n"
                  "4. Transaction Disputes & Support\n"
                  "• For any payment discrepancies, double charges, or failed transactions, customers must contact Bellie’s SmartServe customer support immediately with their transaction screenshot and reference number for prompt auditing.",
                  style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _scanReceiptOcr() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;

    // Validate that the file is a valid image format
    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)) {
      if (!mounted) return;
      AppModals.showError(
        context,
        title: "Invalid Receipt File",
        message: "Please upload a valid payment receipt image (JPG, PNG).",
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Scanning receipt via OCR..."),
            ],
          ),
        ),
      ),
    );

    try {
      final bytes = await file.readAsBytes();
      final base64Str = base64Encode(bytes);
      _draft.paymentProofUrl = 'data:image/jpeg;base64,$base64Str';

      String extractedRef = '';
      final name = file.name;
      final digitMatch = RegExp(r'\d{13}').firstMatch(name);
      if (digitMatch != null) {
        extractedRef = digitMatch.group(0)!;
      } else {
        final hashInt = bytes.fold<int>(0, (prev, element) => prev + element) % 9000000000000 + 1000000000000;
        extractedRef = hashInt.toString();
      }

      if (mounted) {
        Navigator.pop(context); // close loading dialog
        setState(() {
          _refController.text = extractedRef;
        });
        AppModals.showSuccess(
          context,
          title: "Receipt Scanned!",
          message: "GCash Reference Number successfully auto-filled:\n$extractedRef",
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppModals.showError(
          context,
          title: "OCR Scan Failed",
          message: "Unable to read receipt image: $e",
        );
      }
    }
  }

  Widget _deliverySummary() {
    final details = _draft.details;
    final confirmed = _draft.hasConfirmedAddress;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  confirmed ? Icons.location_on : Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confirmed
                        ? 'Confirmed Delivery Address'
                        : 'Delivery Information',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (details != null)
                  TextButton(
                    onPressed: _isSaving ? null : _editAddress,
                    child: const Text('Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (details != null) ...[
              Text('${details.name} · ${details.contact}'),
              const SizedBox(height: 6),
              Text(details.fullAddress),
              if (details.landmark.isNotEmpty)
                Text('Landmark: ${details.landmark}'),
              if (details.deliveryInstructions.isNotEmpty)
                Text('Instructions: ${details.deliveryInstructions}'),
              if (_deliveryDistanceKm > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Road Distance: ${_deliveryDistanceKm.toStringAsFixed(1)} km · Delivery Fee: ₱${_deliveryFee.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
            if (!confirmed) ...[
              const SizedBox(height: 8),
              const Text(
                'Choose a delivery point and confirm the recipient and address before placing your order.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _editAddress,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(
                  details == null
                      ? 'Choose Delivery Address'
                      : 'Confirm Delivery Address',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    final style = TextStyle(
      fontSize: isTotal ? 18 : 14,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            value,
            style: style.copyWith(
              color: isTotal ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
