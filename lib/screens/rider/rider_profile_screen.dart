import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/input_validators.dart';
import '../../models/user_model.dart';
import '../../repositories/rider_dashboard_repository.dart';
import '../../widgets/state_widgets.dart';

class RiderProfileScreen extends StatefulWidget {
  final String riderId;
  const RiderProfileScreen({super.key, required this.riderId});

  @override
  State<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends State<RiderProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _repo = RiderDashboardRepository();
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserModel? _profile;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploading = false;
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
      final p = await _repo.getRiderProfile(widget.riderId);
      _profile = p;
      _avatarUrl = p.avatarUrl;
      _initControllers(p);
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initControllers(UserModel p) {
    final fullName = p.fullName.trim();
    final parts = fullName.split(RegExp(r'\s+'));
    _firstNameController.text = p.firstName ?? (parts.isNotEmpty ? parts.first : '');
    _lastNameController.text = p.lastName ?? (parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _phoneController.text = p.contactNumber ?? '';
  }

  void _startEditing() {
    if (_profile != null) {
      _initControllers(_profile!);
    }
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    if (_profile != null) {
      _initControllers(_profile!);
      _avatarUrl = _profile!.avatarUrl;
    }
    setState(() => _isEditing = false);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rider profile updated successfully!"), backgroundColor: AppColors.success),
      );
      await _loadProfile();
      setState(() => _isEditing = false);
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
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: 8),
            Text("Log Out Rider App"),
          ],
        ),
        content: const Text("Are you sure you want to log out of the Rider Portal?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("LOG OUT"),
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
    if (_isLoading) return const LoadingState();
    if (_profile == null) return ErrorState(error: "Profile not found", onRetry: _loadProfile);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildProfileHeader(),
                const SizedBox(height: 24),
                if (!_isEditing) ...[
                  _buildStatGrid(),
                  const SizedBox(height: 24),
                  _buildDetailsCard(),
                  const SizedBox(height: 24),
                  _buildSettingsList(),
                ] else ...[
                  _buildEditForm(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.adminPrimary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
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
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt_rounded, size: 16, color: AppColors.adminPrimary),
                      onPressed: _isUploading ? null : _pickPhoto,
                      tooltip: "Change Photo",
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(_profile!.fullName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(_profile!.position, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 16),
          if (!_isEditing)
            ElevatedButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text("EDIT PROFILE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.adminPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "Edit Rider Profile",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.adminPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  "Update your name and contact details below.",
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        enabled: !_isSaving && !_isUploading,
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
                        enabled: !_isSaving && !_isUploading,
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
                  initialValue: _profile!.email,
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
                  enabled: !_isSaving && !_isUploading,
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
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _cancelEditing,
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
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text("SAVE CHANGES", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _statItem("Deliveries", "48", Icons.local_shipping_outlined),
          const SizedBox(width: 16),
          _statItem("Vehicle", "Motorcycle", Icons.directions_bike_outlined),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent),
              const SizedBox(height: 8),
              Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Employee & Account Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 24),
              _profileRow('Role', _profile!.role.name.toUpperCase()),
              _profileRow('Position', _profile!.position),
              _profileRow('Daily Rate', '₱${_profile!.dailyRate.toStringAsFixed(2)}'),
              _profileRow('RFID Card UID', _profile!.rfidUid?.isNotEmpty == true ? _profile!.rfidUid! : 'Not Assigned'),
              _profileRow('Account Status', _profile!.accountStatus.name.toUpperCase()),
              if (_profile!.contactNumber?.isNotEmpty == true)
                _profileRow('Contact Number', _profile!.contactNumber!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: Text("LOGOUT RIDER APP", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
