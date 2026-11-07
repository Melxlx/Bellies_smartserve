import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/input_validators.dart';
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;

    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final mime = file.mimeType?.toLowerCase() ?? '';

    final allowedExts = ['.jpg', '.jpeg', '.png'];
    final hasValidExt = allowedExts.any((ext) => name.endsWith(ext) || path.endsWith(ext));
    final hasValidMime = mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/jpg';

    if (!hasValidExt && !hasValidMime) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only JPG, JPEG, and PNG images are accepted for profile photo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    const maxSizeBytes = 5 * 1024 * 1024;
    if (bytes.length > maxSizeBytes) {
      final mbSize = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File size ($mbSize MB) exceeds 5 MB limit. Choose a smaller image.'),
          backgroundColor: AppColors.error,
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
        SnackBar(content: Text('Could not upload photo: $e'), backgroundColor: AppColors.error),
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

      final fName = InputValidators.sanitize(_firstNameController.text);
      final lName = InputValidators.sanitize(_lastNameController.text);
      final fullName = "$fName $lName".trim();
      final phone = InputValidators.sanitize(_phoneController.text);

      await _supabase.from('profiles').update({
        'full_name': fullName,
        'first_name': fName,
        'last_name': lName,
        'contact_number': phone,
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Owner profile updated successfully!"), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating profile: $e"), backgroundColor: AppColors.error),
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
            Icon(Icons.logout_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text("Sign Out"),
          ],
        ),
        content: const Text("Are you sure you want to sign out of Bellie's SmartServe?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: Text("Owner Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text("EDIT PROFILE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.adminPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
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
                                    radius: 52,
                                    backgroundColor: const Color(0xFFFFE4EE),
                                    backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                                    child: _isUploading
                                        ? const CircularProgressIndicator(color: AppColors.adminPrimary)
                                        : (_avatarUrl == null || _avatarUrl!.isEmpty
                                            ? const Icon(Icons.person, size: 52, color: AppColors.adminPrimary)
                                            : null),
                                  ),
                                  if (_isEditing)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.adminPrimary,
                                        child: IconButton(
                                          icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
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
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.adminPrimary),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    readOnly: !_isEditing || _isSaving || _isLoading || _isUploading,
                                    inputFormatters: InputValidators.nameFormatters,
                                    decoration: const InputDecoration(
                                      labelText: "First Name *",
                                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                                      counterText: "",
                                    ),
                                    validator: (v) => InputValidators.validateName(v, fieldName: "First Name"),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    readOnly: !_isEditing || _isSaving || _isLoading || _isUploading,
                                    inputFormatters: InputValidators.nameFormatters,
                                    decoration: const InputDecoration(
                                      labelText: "Last Name *",
                                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18),
                                      counterText: "",
                                    ),
                                    validator: (v) => InputValidators.validateName(v, fieldName: "Last Name"),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              initialValue: _email,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Email Address (Read-only)",
                                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                                filled: true,
                                fillColor: isDark ? Colors.black26 : const Color(0xFFF8FAFC),
                              ),
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _phoneController,
                              readOnly: !_isEditing || _isSaving || _isLoading || _isUploading,
                              keyboardType: TextInputType.phone,
                              inputFormatters: InputValidators.phoneFormatters,
                              decoration: const InputDecoration(
                                labelText: "Contact Number *",
                                prefixIcon: Icon(Icons.phone_iphone_rounded, size: 18),
                                hintText: "09171234567",
                                counterText: "",
                              ),
                              validator: (v) => InputValidators.validatePhoneNumber(v),
                            ),
                            const SizedBox(height: 32),
                            if (_isEditing) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSaving ? null : () {
                                        setState(() => _isEditing = false);
                                        _loadProfile();
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      ),
                                      child: const Text("CANCEL"),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: SizedBox(
                                      height: 48,
                                      child: ElevatedButton(
                                        onPressed: _isSaving ? null : _saveProfile,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.adminPrimary,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        child: _isSaving
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                              )
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
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(color: AppColors.error),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.logout_rounded, size: 18),
                                label: Text("SIGN OUT", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
