import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/payment_qr_model.dart';
import '../../repositories/payment_qr_repository.dart';
import '../../widgets/state_widgets.dart';

class PaymentQrScreen extends StatefulWidget {
  const PaymentQrScreen({super.key});

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  final _repo = PaymentQrRepository();
  List<PaymentQrModel> _qrs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQrs();
  }

  Future<void> _loadQrs() async {
    setState(() => _isLoading = true);
    try {
      final qrs = await _repo.getPaymentQrs();
      if (mounted) {
        setState(() {
          _qrs = qrs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFormDialog({PaymentQrModel? qr}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PaymentQrFormDialog(
        qr: qr,
        onSave: _loadQrs,
      ),
    );
  }

  void _deleteQr(PaymentQrModel qr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Payment QR"),
        content: Text("Are you sure you want to delete ${qr.providerName} (${qr.accountName})?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteQr(qr.id);
        if (!mounted) return;
        _loadQrs();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting QR: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: Text("Payment QR Gateways", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showFormDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("ADD QR CODE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC2416C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : _qrs.isEmpty
              ? const EmptyState(message: "No payment QR codes added yet.\n\nAdd your GCash, Maya, or Bank QR codes so customers can pay online easily.")
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _qrs.length,
                  itemBuilder: (context, index) {
                    final qr = _qrs[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  qr.qrImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.qr_code, size: 40, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(qr.providerName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: qr.isActive ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          qr.isActive ? "ACTIVE" : "INACTIVE",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: qr.isActive ? const Color(0xFF059669) : Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text("${qr.accountName} • ${qr.accountNumber}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                ],
                              ),
                            ),
                            Switch(
                              value: qr.isActive,
                              activeTrackColor: const Color(0xFFC2416C),
                              onChanged: (val) async {
                                await _repo.toggleActive(qr.id, val);
                                if (!mounted) return;
                                _loadQrs();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showFormDialog(qr: qr),
                              tooltip: "Edit QR",
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                              onPressed: () => _deleteQr(qr),
                              tooltip: "Delete QR",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _PaymentQrFormDialog extends StatefulWidget {
  final PaymentQrModel? qr;
  final VoidCallback onSave;

  const _PaymentQrFormDialog({this.qr, required this.onSave});

  @override
  State<_PaymentQrFormDialog> createState() => _PaymentQrFormDialogState();
}

class _PaymentQrFormDialogState extends State<_PaymentQrFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _providerController = TextEditingController();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  String? _qrImageUrl;
  bool _isActive = true;
  bool _isUploading = false;
  bool _isSaving = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.qr != null) {
      _providerController.text = widget.qr!.providerName;
      _nameController.text = widget.qr!.accountName;
      _numberController.text = widget.qr!.accountNumber;
      _qrImageUrl = widget.qr!.qrImageUrl;
      _isActive = widget.qr!.isActive;
    } else {
      _providerController.text = 'GCash';
    }
  }

  @override
  void dispose() {
    _providerController.dispose();
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadQrImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;

    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final mime = file.mimeType?.toLowerCase() ?? '';

    // Validation: JPEG or PNG ONLY
    final allowedExts = ['.jpg', '.jpeg', '.png'];
    final hasValidExt = allowedExts.any((ext) => name.endsWith(ext) || path.endsWith(ext));
    final hasValidMime = mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/jpg';

    if (!hasValidExt && !hasValidMime) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid file format. Only JPEG (.jpg, .jpeg) and PNG (.png) images are accepted.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validation: Max 5 MB
    final bytes = await file.readAsBytes();
    const maxSizeBytes = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxSizeBytes) {
      final mbSize = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File size ($mbSize MB) exceeds the 5 MB maximum limit. Please choose a smaller image.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final uploadPath = 'qrs/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('payment-qrs')
          .uploadBinary(
            uploadPath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = Supabase.instance.client.storage.from('payment-qrs').getPublicUrl(uploadPath);
      if (!mounted) return;
      setState(() => _qrImageUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload QR image: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_qrImageUrl == null || _qrImageUrl!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a QR code image!'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final qr = PaymentQrModel(
        id: widget.qr?.id ?? '',
        providerName: _providerController.text.trim(),
        accountName: _nameController.text.trim(),
        accountNumber: _numberController.text.trim(),
        qrImageUrl: _qrImageUrl!,
        isActive: _isActive,
      );

      await PaymentQrRepository().saveQr(qr);
      if (!mounted) return;
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving QR: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.qr == null ? "Add Payment QR" : "Edit Payment QR", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickAndUploadQrImage,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300, width: 1.5),
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : (_qrImageUrl != null && _qrImageUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.network(_qrImageUrl!, fit: BoxFit.cover),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.qr_code_scanner_rounded, size: 36, color: Color(0xFFC2416C)),
                                    SizedBox(height: 8),
                                    Text("Upload QR Image", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ],
                                )),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _providerController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(labelText: "Provider Name (e.g. GCash, Maya)", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Provider name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(labelText: "Account Name", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Account name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numberController,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(labelText: "Account Number / Mobile", border: OutlineInputBorder()),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Account number is required' : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text("Active Gateway", style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _isActive,
                  activeTrackColor: const Color(0xFFC2416C),
                  onChanged: _isSaving ? null : (val) => setState(() => _isActive = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2416C), foregroundColor: Colors.white),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE QR"),
        ),
      ],
    );
  }
}
