import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
import '../../models/order_model.dart';
import '../../models/payment_qr_model.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/payment_qr_repository.dart';
import '../../services/receipt_ocr_service.dart';

class PaymentScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _orderRepo = OrderRepository();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  final _customerNameController = TextEditingController();
  final _cashController = TextEditingController();
  final _referenceController = TextEditingController();
  double _change = 0.0;
  String? _error;
  bool _isProcessing = false;
  bool _agreedToOnlineTerms = false;
  PaymentQrModel? _activeQr;

  @override
  void initState() {
    super.initState();
    _cashController.addListener(_calculateChange);
    if (widget.order.customerDetails?.name != null &&
        widget.order.customerDetails!.name.isNotEmpty &&
        widget.order.customerDetails!.name != "Walk-in Customer") {
      _customerNameController.text = widget.order.customerDetails!.name;
    }
    _loadActiveQr();
  }

  Future<void> _loadActiveQr() async {
    try {
      final qr = await PaymentQrRepository().getActiveQr();
      if (mounted) {
        setState(() {
          _activeQr = qr;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _cashController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final tendered = double.tryParse(_cashController.text) ?? 0.0;
    setState(() {
      if (tendered >= widget.order.totalAmount) {
        _change = tendered - widget.order.totalAmount;
        _error = null;
      } else {
        _change = 0.0;
        if (_cashController.text.trim().isNotEmpty) {
          final needed = widget.order.totalAmount - tendered;
          _error = "Insufficient cash. Please add ₱${needed.toStringAsFixed(2)} more.";
        } else {
          _error = null;
        }
      }
    });
  }

  Future<void> _confirmPayment() async {
    if (_selectedMethod == PaymentMethod.cash) {
      final tendered = double.tryParse(_cashController.text) ?? 0.0;
      if (_cashController.text.trim().isEmpty) {
        setState(() => _error = "Please enter the cash amount tendered.");
        return;
      }
      if (tendered < widget.order.totalAmount) {
        final needed = widget.order.totalAmount - tendered;
        setState(() => _error = "Insufficient amount tendered. Please provide at least ₱${widget.order.totalAmount.toStringAsFixed(2)} (Short by ₱${needed.toStringAsFixed(2)}).");
        return;
      }
    } else {
      final inputRef = _referenceController.text.trim();
      final isCounterPos = widget.order.serviceType == ServiceType.dineIn || widget.order.serviceType == ServiceType.takeout;
      if (!isCounterPos || inputRef.isNotEmpty) {
        if (inputRef.isEmpty) {
          setState(() => _error = "GCash Reference Number is required.");
          return;
        }
        if (!ReceiptOcrService.isValidGcashRefNumber(inputRef)) {
          setState(() => _error = "Invalid GCash Reference Number (Must be 10 to 13 digits).");
          return;
        }
        if (!isCounterPos && !_agreedToOnlineTerms) {
          setState(() => _error = "Please agree to the Online Payment Terms & Conditions.");
          return;
        }
      }
    }

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final inputCustomerName = _customerNameController.text.trim();
      final customerName = inputCustomerName.isNotEmpty
          ? inputCustomerName
          : (widget.order.customerDetails?.name.isNotEmpty == true
              ? widget.order.customerDetails!.name
              : "Walk-in Customer");

      final updatedCustomerDetails = CustomerDetails(
        name: customerName,
        contact: widget.order.customerDetails?.contact ?? '',
        address: widget.order.customerDetails?.address ?? '',
        landmark: widget.order.customerDetails?.landmark ?? '',
        notes: widget.order.customerDetails?.notes ?? '',
      );

      final finalOrderWithPayment = OrderModel(
        id: '',
        queueNumber: '',
        trackingNumber:
            "TRK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}",
        items: widget.order.items,
        timestamp: DateTime.now(),
        subtotal: widget.order.subtotal,
        deliveryFee: widget.order.deliveryFee,
        totalAmount: widget.order.totalAmount,
        serviceType: widget.order.serviceType,
        customerDetails: updatedCustomerDetails,
        status: 'received',
        paymentStatus: (_selectedMethod == PaymentMethod.cash)
            ? 'PAID'
            : 'PENDING',
        deliveryStatus: widget.order.serviceType == ServiceType.delivery
            ? DeliveryStatus.preparing
            : null,
        paymentMethod: _selectedMethod,
        amountTendered: _selectedMethod == PaymentMethod.cash
            ? double.parse(_cashController.text)
            : null,
        change: _selectedMethod == PaymentMethod.cash ? _change : null,
        referenceNumber: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
        estimatedDeliveryTime: widget.order.serviceType == ServiceType.delivery
            ? "30-45 mins"
            : null,
      );

      final savedOrder = await _orderRepo.createOrder(finalOrderWithPayment);

      if (mounted) {
        Navigator.pop(context, true);
        Navigator.pushNamed(
          context,
          AppRoutes.receipt,
          arguments: ReceiptArguments(order: savedOrder),
        );
      }
    } catch (e) {
      setState(() {
        _error = "Error saving order: $e";
        _isProcessing = false;
      });
    }
  }

  void _scanReceiptOcr() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (pickedFile == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Scanning receipt via OCR..."), duration: Duration(seconds: 1)),
    );

    final extractedRef = await ReceiptOcrService.extractGcashReferenceNumber(
      pickedFile.path,
      fileName: pickedFile.name,
    );

    if (mounted) {
      if (extractedRef != null && extractedRef.isNotEmpty) {
        setState(() {
          _referenceController.text = extractedRef;
          _error = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Receipt scanned successfully via OCR! Reference: $extractedRef"),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No valid 10-13 digit GCash Reference Number found in the selected image."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Online Payment Terms & Conditions"),
        content: const SingleChildScrollView(
          child: Text(
            "1. All online GCash and digital payments are subject to store verification.\n"
            "2. Providing fraudulent or invalid reference numbers will result in order cancellation and account blacklisting.\n"
            "3. Refunds for online payments follow the restaurant's return policy.",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Payment Processing",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ResponsiveLayout(
            mobile: _buildPaymentContent(maxWidth: double.infinity),
            desktop: _buildPaymentContent(maxWidth: 520),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentContent({required double maxWidth}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Total Amount Header Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF1F5), Color(0xFFFFE4EC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFC1D6)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE91E63),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Total Amount Due",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.pink.shade900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "₱${widget.order.totalAmount.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFE91E63),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Customer Name Field
              TextField(
                controller: _customerNameController,
                enabled: !_isProcessing,
                decoration: InputDecoration(
                  labelText: "Customer Name (Optional)",
                  hintText: "e.g. Juan or Walk-in Customer",
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF64748B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Payment Method Selectors
              Text(
                "Payment Method",
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _methodTile(PaymentMethod.cash, Icons.payments_rounded, "CASH"),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _methodTile(
                      PaymentMethod.gcash,
                      Icons.qr_code_2_rounded,
                      "GCASH / QR",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              if (_selectedMethod == PaymentMethod.cash) _buildCashView(),
              if (_selectedMethod == PaymentMethod.gcash) _buildGCashView(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Confirm Button
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _confirmPayment,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(
                  _isProcessing ? "PROCESSING PAYMENT..." : "CONFIRM PAYMENT",
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodTile(PaymentMethod method, IconData icon, String label) {
    final isSelected = _selectedMethod == method;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _error = null;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFFE91E63) : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          color: isSelected
              ? const Color(0xFFFFF1F5)
              : Colors.white,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFE91E63) : const Color(0xFF64748B),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? const Color(0xFFE91E63) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCashButtons() {
    final total = widget.order.totalAmount;
    final List<double> defaultDenominations = [100, 200, 500, 1000];
    final Set<double> denominations = {total};

    for (final d in defaultDenominations) {
      if (d > total) {
        denominations.add(d);
      }
    }

    final sortedDenominations = denominations.toList()..sort();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortedDenominations.map((amount) {
        final isExact = (amount - total).abs() < 0.01;
        final label = isExact
            ? "Exact (₱${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)})"
            : "₱${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}";
        return OutlinedButton(
          onPressed: _isProcessing
              ? null
              : () {
                  _cashController.text = amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
                  _calculateChange();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: isExact ? const Color(0xFF059669) : const Color(0xFF2563EB),
            side: BorderSide(
              color: isExact ? const Color(0xFF10B981) : const Color(0xFF93C5FD),
              width: 1.5,
            ),
            backgroundColor: isExact ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
              color: isExact ? const Color(0xFF047857) : const Color(0xFF1D4ED8),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCashView() {
    final tendered = double.tryParse(_cashController.text) ?? 0.0;
    final isSufficient = tendered >= widget.order.totalAmount;
    final remainingNeeded = widget.order.totalAmount - tendered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Quick Cash Denominations",
          style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        _buildQuickCashButtons(),
        const SizedBox(height: 18),
        TextField(
          controller: _cashController,
          enabled: !_isProcessing,
          decoration: InputDecoration(
            labelText: "Amount Tendered",
            hintText: "Enter cash given by customer",
            prefixText: "₱ ",
            prefixIcon: const Icon(Icons.payments_outlined, color: Color(0xFFE91E63)),
            suffixIcon: _cashController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                    onPressed: () {
                      _cashController.clear();
                      _calculateChange();
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          autofocus: true,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isSufficient
                ? const Color(0xFFECFDF5)
                : (_cashController.text.trim().isNotEmpty
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSufficient
                  ? const Color(0xFFA7F3D0)
                  : (_cashController.text.trim().isNotEmpty
                      ? const Color(0xFFFECDD3)
                      : const Color(0xFFE2E8F0)),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSufficient ? Icons.check_circle_rounded : Icons.account_balance_wallet_outlined,
                        size: 22,
                        color: isSufficient
                            ? const Color(0xFF059669)
                            : (_cashController.text.trim().isNotEmpty
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Change To Return:",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSufficient
                              ? const Color(0xFF065F46)
                              : (_cashController.text.trim().isNotEmpty
                                  ? const Color(0xFF9F1239)
                                  : const Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "₱${_change.toStringAsFixed(2)}",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isSufficient
                          ? const Color(0xFF059669)
                          : (_cashController.text.trim().isNotEmpty
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
              if (!isSufficient && _cashController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Color(0xFFE11D48)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Insufficient cash. Please add ₱${remainingNeeded.toStringAsFixed(2)} more.",
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGCashView() {
    final isCounterPos = widget.order.serviceType == ServiceType.dineIn || widget.order.serviceType == ServiceType.takeout;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.shade200),
            boxShadow: [
              BoxShadow(color: Colors.blue.shade100.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _activeQr != null && _activeQr!.qrImageUrl.isNotEmpty
                    ? Image.network(
                        _activeQr!.qrImageUrl,
                        height: 160,
                        width: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Image.asset('assets/images/instapay_qr.png', height: 160, width: 160, fit: BoxFit.contain),
                      )
                    : Image.asset(
                        'assets/images/instapay_qr.png',
                        height: 160,
                        width: 160,
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                "SCAN TO PAY (${_activeQr?.providerName ?? 'GCASH'})",
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Account Number: ${_activeQr?.accountNumber ?? '0928 732 2030'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900)),
                  Text("Account Name: ${_activeQr?.accountName ?? 'Bellies Duenas'}", style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey.shade600)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.blue, size: 20),
                onPressed: () {
                  final accNum = _activeQr?.accountNumber ?? '09287322030';
                  Clipboard.setData(ClipboardData(text: accNum));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Account Number copied!"), duration: Duration(seconds: 2)),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!isCounterPos) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "GCash Reference Number (13 digits):",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _scanReceiptOcr,
                icon: const Icon(Icons.document_scanner_rounded, size: 16, color: Colors.blue),
                label: const Text("Scan Receipt (OCR)", style: TextStyle(fontSize: 11, color: Colors.blue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  side: BorderSide(color: Colors.blue.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _referenceController,
            enabled: !_isProcessing,
            maxLength: 13,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "GCash Reference Number",
              counterText: "",
              prefixIcon: const Icon(Icons.tag, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _agreedToOnlineTerms,
            onChanged: _isProcessing ? null : (val) => setState(() => _agreedToOnlineTerms = val ?? false),
            title: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  const TextSpan(text: "I agree to the "),
                  TextSpan(
                    text: "Online Payment Terms & Conditions",
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.bold,
                    ),
                    recognizer: TapGestureRecognizer()..onTap = _isProcessing ? null : _showTermsDialog,
                  ),
                ],
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
        ] else ...[
          TextField(
            controller: _referenceController,
            enabled: !_isProcessing,
            maxLength: 13,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "GCash Reference Number (Optional for Counter)",
              counterText: "",
              prefixIcon: const Icon(Icons.tag, color: Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ],
    );
  }
}
