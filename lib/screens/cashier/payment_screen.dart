import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
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
      _change = tendered - widget.order.totalAmount;
      if (tendered > 0 && _change < 0) {
        _error = "Insufficient cash";
      } else {
        _error = null;
      }
    });
  }

  Future<void> _confirmPayment() async {
    if (_selectedMethod == PaymentMethod.cash) {
      final tendered = double.tryParse(_cashController.text) ?? 0.0;
      if (tendered < widget.order.totalAmount) {
        setState(() => _error = "Insufficient cash");
        return;
      }
    } else {
      final inputRef = _referenceController.text.trim();
      final isCounterPos = widget.order.serviceType == ServiceType.dineIn || widget.order.serviceType == ServiceType.takeout;
      if (!isCounterPos || inputRef.isNotEmpty) {
        if (inputRef.isEmpty) {
          setState(() => _error = "Reference number required");
          return;
        }
        if (!ReceiptOcrService.isValidGcashRefNumber(inputRef)) {
          setState(() => _error = "Invalid GCash Reference Number (Must be 10 to 13 digits)");
          return;
        }
        if (!isCounterPos && !_agreedToOnlineTerms) {
          setState(() => _error = "Please agree to the Online Payment Terms & Conditions");
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
        Navigator.pushReplacementNamed(
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
      appBar: AppBar(title: const Text("Select Payment Method")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveLayout(
            mobile: _buildPaymentContent(maxWidth: double.infinity),
            desktop: _buildPaymentContent(maxWidth: 500),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentContent({required double maxWidth}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Total Amount: ₱${widget.order.totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _customerNameController,
                enabled: !_isProcessing,
                decoration: const InputDecoration(
                  labelText: "Customer Name (Optional)",
                  hintText: "e.g. Juan or Walk-in",
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _methodTile(PaymentMethod.cash, Icons.money, "CASH"),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _methodTile(
                      PaymentMethod.gcash,
                      Icons.qr_code,
                      "GCASH",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              if (_selectedMethod == PaymentMethod.cash) _buildCashView(),
              if (_selectedMethod == PaymentMethod.gcash) _buildGCashView(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              _isProcessing
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _confirmPayment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text("CONFIRM PAYMENT"),
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
      onTap: () => setState(() => _selectedMethod = method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFFE91E63) : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? const Color(0xFFE91E63).withAlpha((0.1 * 255).toInt())
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFE91E63) : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFE91E63) : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashView() {
    return Column(
      children: [
        TextField(
          controller: _cashController,
          enabled: !_isProcessing,
          decoration: const InputDecoration(
            labelText: "Amount Tendered",
            prefixText: "₱ ",
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Change:", style: TextStyle(fontSize: 18)),
              Text(
                "₱${_change.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade200),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _activeQr != null && _activeQr!.qrImageUrl.isNotEmpty
                    ? Image.network(
                        _activeQr!.qrImageUrl,
                        height: 150,
                        width: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Image.asset('assets/images/instapay_qr.png', height: 150, width: 150, fit: BoxFit.contain),
                      )
                    : Image.asset(
                        'assets/images/instapay_qr.png',
                        height: 150,
                        width: 150,
                        fit: BoxFit.contain,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                "SCAN TO PAY (${_activeQr?.providerName ?? 'GCASH'})",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Account Number: ${_activeQr?.accountNumber ?? '0928 732 2030'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("Account Name: ${_activeQr?.accountName ?? 'Bellies Duenas'}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
        const SizedBox(height: 16),
        if (!isCounterPos) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "GCash Reference Number (13 digits):",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
          TextField(
            controller: _referenceController,
            enabled: !_isProcessing,
            maxLength: 13,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "GCash Reference Number",
              counterText: "",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
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
            ),
          ),
        ] else ...[
          TextField(
            controller: _referenceController,
            enabled: !_isProcessing,
            maxLength: 13,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "GCash Reference Number (Optional for Counter)",
              counterText: "",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }
}
