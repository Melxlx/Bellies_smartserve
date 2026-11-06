import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_routes.dart';
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
      if (p != null) {
        _profile = p;
        _avatarUrl = p.avatarUrl;
        _initControllers(p);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rider profile updated successfully!"), backgroundColor: Colors.green),
      );
      await _loadProfile();
      setState(() => _isEditing = false);
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
            Icon(Icons.logout, color: Colors.red),
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
              backgroundColor: Colors.red,
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

    return Scaffold(
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
        color: Color(0xFFC2416C),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white,
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                child: _isUploading
                    ? const CircularProgressIndicator(color: Color(0xFFC2416C))
                    : (_avatarUrl == null || _avatarUrl!.isEmpty
                        ? const Icon(Icons.person, size: 52, color: Color(0xFFC2416C))
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
                      icon: const Icon(Icons.camera_alt, size: 16, color: Color(0xFFC2416C)),
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
                foregroundColor: const Color(0xFFC2416C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFC2416C)),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Update your name and contact details below.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        maxLength: 30,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                          DenyLeadingSpaceFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: "First Name *",
                          border: OutlineInputBorder(),
                          counterText: "",
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'First name is required';
                          if (v.trim().length < 2) return 'Min 2 characters';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        maxLength: 30,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                          DenyLeadingSpaceFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: "Last Name *",
                          border: OutlineInputBorder(),
                          counterText: "",
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Last name is required';
                          if (v.trim().length < 2) return 'Min 2 characters';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _profile!.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Email Address (Read-only)",
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  maxLength: 13,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                    DenyLeadingSpaceFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Contact Number *",
                    border: OutlineInputBorder(),
                    hintText: "e.g. 09171234567",
                    counterText: "",
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Contact number is required';
                    final phone = v.trim().replaceAll(RegExp(r'[\s()\-]'), '');
                    if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(phone)) {
                      return 'Enter valid PH mobile (e.g. 09171234567)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : _cancelEditing,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("CANCEL"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC2416C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          _statItem("Deliveries", "48", Icons.local_shipping),
          const SizedBox(width: 16),
          _statItem("Vehicle", "Motorcycle", Icons.directions_bike),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Employee & Account Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.red,
              elevation: 0,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("LOGOUT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
