import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_routes.dart';
import '../../widgets/state_widgets.dart';

class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _email = '';
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isEditing = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        _email = user.email ?? '';
        final res = await _supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (res != null && !_isEditing && !_isSaving) {
          final fullName = res['full_name']?.toString() ?? '';
          final parts = fullName.split(' ');
          _firstNameController.text = res['first_name'] ?? (parts.isNotEmpty ? parts.first : '');
          _lastNameController.text = res['last_name'] ?? (parts.length > 1 ? parts.sublist(1).join(' ') : '');
          _phoneController.text = res['contact_number'] ?? '';
          _avatarUrl = res['avatar_url']?.toString();
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
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
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final uploadPath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('employee-avatars')
          .uploadBinary(
            uploadPath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = _supabase.storage.from('employee-avatars').getPublicUrl(uploadPath);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload photo: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final fName = _firstNameController.text.trim();
      final lName = _lastNameController.text.trim();
      final fullName = "$fName $lName".trim();

      await _supabase.from('profiles').update({
        'full_name': fullName,
        'first_name': fName,
        'last_name': lName,
        'contact_number': _phoneController.text.trim(),
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
      }).eq('id', user.id);

      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Owner profile updated successfully!"), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Sign Out"),
          ],
        ),
        content: const Text("Are you sure you want to sign out of Bellie's SmartServe?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("SIGN OUT"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _supabase.auth.signOut();
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.staffLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: Text("Owner Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text("EDIT PROFILE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC2416C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(28.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundColor: const Color(0xFFFFF0F5),
                                    backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                                    child: _isUploading
                                        ? const CircularProgressIndicator(color: Color(0xFFC2416C))
                                        : (_avatarUrl == null || _avatarUrl!.isEmpty
                                            ? ClipOval(
                                                child: Image.asset(
                                                  'assets/images/mami.png',
                                                  width: 100,
                                                  height: 100,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant, size: 40, color: Color(0xFFC2416C)),
                                                ),
                                              )
                                            : null),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: const Color(0xFFC2416C),
                                        child: IconButton(
                                          icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                          onPressed: _isUploading ? null : _pickPhoto,
                                          tooltip: "Change Photo",
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                "Owner / Administrator",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFFC2416C)),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    readOnly: !_isEditing || _isSaving || _isLoading || _isUploading,
                                    maxLength: 30,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                                      DenyLeadingSpaceFormatter(),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: "First Name",
                                      border: const OutlineInputBorder(),
                                      filled: !_isEditing || _isSaving || _isLoading || _isUploading,
                                      fillColor: (_isEditing && !_isSaving && !_isLoading && !_isUploading) ? Colors.white : const Color(0xFFF8FAFC),
                                      counterText: "",
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      if (v.trim().length < 2) return 'Min 2 chars';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    readOnly: !_isEditing || _isSaving || _isLoading || _isUploading,
                                    maxLength: 30,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                                      DenyLeadingSpaceFormatter(),
                                    ],
                                    decoration: InputDecoration(
                                      labelText: "Last Name",
                                      border: const OutlineInputBorder(),
                                      filled: !_isEditing || _isSaving || _isLoading || _isUploading,
                                      fillColor: (_isEditing && !_isSaving && !_isLoading && !_isUploading) ? Colors.white : const Color(0xFFF8FAFC),
                                      counterText: "",
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      if (v.trim().length < 2) return 'Min 2 chars';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              initialValue: _email,
                              readOnly: true,
                              decoration: const InputDecoration(labelText: "Email Address (Read-only)", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF8FAFC)),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _phoneController,
                              readOnly: !_isEditing || _isSaving || _isLoading || _isUploading,
                              maxLength: 13,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                                DenyLeadingSpaceFormatter(),
                              ],
                              decoration: InputDecoration(
                                labelText: "Contact Number",
                                border: const OutlineInputBorder(),
                                filled: !_isEditing || _isSaving || _isLoading || _isUploading,
                                fillColor: (_isEditing && !_isSaving && !_isLoading && !_isUploading) ? Colors.white : const Color(0xFFF8FAFC),
                                counterText: "",
                              ),
                              validator: (v) {
                                if (v != null && v.trim().isNotEmpty) {
                                  final phone = v.trim().replaceAll(RegExp(r'[\s()\-]'), '');
                                  if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(phone)) {
                                    return 'Enter valid PH mobile (e.g. 09171234567)';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),
                            if (_isEditing) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSaving ? null : () {
                                        setState(() => _isEditing = false);
                                        _loadProfile(); // reset changes
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: const Text("CANCEL"),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _saveProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFC2416C),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: _isSaving
                                            ? const CircularProgressIndicator(color: Colors.white)
                                            : Text("SAVE CHANGES", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              OutlinedButton.icon(
                                onPressed: _logout,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text("SIGN OUT", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class DenyLeadingSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }
    return newValue;
  }
}
