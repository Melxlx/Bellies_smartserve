import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/input_validators.dart';
import '../../widgets/premium_action_button.dart';
import '../../widgets/premium_content_card.dart';
import '../../widgets/state_widgets.dart';

class CustomerAccountScreen extends StatefulWidget {
  const CustomerAccountScreen({super.key});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  Map<String, dynamic>? _profileData;
  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _addressController;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _contactController = TextEditingController();
    _addressController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      _profileData = res;

      final emailPrefix = user.email?.split('@').first ?? '';
      String getValidName(dynamic primary, dynamic fallback) {
        final p = primary?.toString().trim();
        if (p != null && p.isNotEmpty) return p;
        final f = fallback?.toString().trim();
        if (f != null && f.isNotEmpty) return f;
        return '';
      }

      final rawFullName = getValidName(
        _profileData?['full_name'],
        getValidName(user.userMetadata?['full_name'], user.userMetadata?['name']),
      );

      String fName = getValidName(_profileData?['first_name'], user.userMetadata?['first_name']);
      String mName = getValidName(_profileData?['middle_name'], user.userMetadata?['middle_name']);
      String lName = getValidName(_profileData?['last_name'], user.userMetadata?['last_name']);

      if (fName == emailPrefix) fName = '';
      if (lName == emailPrefix) lName = '';

      if (fName.isEmpty && rawFullName.isNotEmpty && rawFullName != emailPrefix) {
        final parts = rawFullName.replaceAll(RegExp(r'\s+'), ' ').split(' ');
        if (parts.length == 1) {
          fName = parts[0];
        } else if (parts.length == 2) {
          fName = parts[0];
          if (lName.isEmpty) lName = parts[1];
        } else if (parts.length >= 3) {
          fName = parts[0];
          if (mName.isEmpty) mName = parts.sublist(1, parts.length - 1).join(' ');
          if (lName.isEmpty) lName = parts.last;
        }
      }

      if (fName.isEmpty && lName.isNotEmpty) {
        fName = lName;
        lName = '';
      }

      _firstNameController.text = fName;
      _middleNameController.text = mName;
      _lastNameController.text = lName;
      _contactController.text = _profileData?['contact_number']?.toString() ?? user.userMetadata?['contact_number']?.toString() ?? '';
      _addressController.text = _profileData?['address']?.toString() ?? user.userMetadata?['address']?.toString() ?? '';
      _avatarUrl = _profileData?['avatar_url'] ?? user.userMetadata?['avatar_url'];

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading customer profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final path = file.path.toLowerCase();

      final isJpgOrPng = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') ||
                         path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png');

      bool hasValidHeader = false;
      if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        hasValidHeader = true;
      } else if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
        hasValidHeader = true;
      }

      if (!isJpgOrPng || !hasValidHeader) {
        if (mounted) {
          await showErrorDialog(
            context,
            title: 'Invalid Format',
            message: 'Only JPEG and PNG images are accepted.',
          );
        }
        return;
      }

      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          await showErrorDialog(
            context,
            title: 'File Too Large',
            message: 'Image size exceeds the 5MB maximum limit.',
          );
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final storagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('employee-avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      final url = Supabase.instance.client.storage.from('employee-avatars').getPublicUrl(storagePath);

      setState(() {
        _avatarUrl = url;
        _isUploadingPhoto = false;
      });

      await Supabase.instance.client.from('profiles').update({
        'avatar_url': url,
      }).eq('id', user.id);

    } catch (e) {
      setState(() => _isUploadingPhoto = false);
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Upload Failed',
          message: 'Could not upload picture: $e',
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final fName = _firstNameController.text.trim();
      final mName = _middleNameController.text.trim();
      final lName = _lastNameController.text.trim();
      final fullName = [fName, mName, lName].where((s) => s.isNotEmpty).join(' ');
      final contact = _contactController.text.trim();
      final addr = _addressController.text.trim();

      final profileUpdates = <String, dynamic>{
        'first_name': fName,
        'middle_name': mName.isNotEmpty ? mName : null,
        'last_name': lName,
        'full_name': fullName,
        'contact_number': contact,
        'address': addr,
        'avatar_url': _avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client.from('profiles').update(profileUpdates).eq('id', user.id);
      } on PostgrestException catch (pgError) {
        debugPrint("Postgrest update warning: ${pgError.message}");
        final safeUpdates = Map<String, dynamic>.from(profileUpdates)
          ..remove('address')
          ..remove('contact_number');
        try {
          await Supabase.instance.client.from('profiles').update(safeUpdates).eq('id', user.id);
        } catch (_) {}
      }

      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': fullName,
              'first_name': fName,
              'middle_name': mName,
              'last_name': lName,
              'contact_number': contact,
              'address': addr,
              'avatar_url': _avatarUrl,
            },
          ),
        );
      } catch (_) {}

      setState(() {
        _isSaving = false;
        _isEditing = false;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text("Profile updated successfully!")),
      );
      await _loadProfile();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Update Failed',
          message: 'Failed to update profile: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    if (!isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text("My Account", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: 16),
                Text("Guest Visitor", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  "Sign in to manage your profile, delivery address, and track your orders.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                PremiumActionButton(
                  label: "LOGIN / SIGN UP",
                  icon: Icons.login_rounded,
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final fullName = [_firstNameController.text, _lastNameController.text].where((s) => s.isNotEmpty).join(' ');
    final displayName = fullName.isNotEmpty
        ? fullName
        : (user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Customer');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("My Customer Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar Card
                    PremiumContentCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 3),
                                ),
                                child: CircleAvatar(
                                  radius: 46,
                                  backgroundColor: AppColors.lightPink,
                                  backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                                  child: _avatarUrl == null || _avatarUrl!.isEmpty
                                      ? const Icon(Icons.person_rounded, size: 46, color: AppColors.primary)
                                      : null,
                                ),
                              ),
                              if (_isEditing)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: CircleAvatar(
                                    radius: 17,
                                    backgroundColor: AppColors.primary,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: _isUploadingPhoto
                                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                                      onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                                      tooltip: 'Upload Picture',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayName,
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            user.email ?? '',
                            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Inline Editable / Viewable Fields Card
                    PremiumContentCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditing) ...[
                            TextFormField(
                              controller: _firstNameController,
                              enabled: !_isSaving,
                              inputFormatters: InputValidators.nameFormatters,
                              decoration: _inputDecoration(
                                label: "First Name *",
                                icon: Icons.badge_outlined,
                                hint: "First Name",
                              ),
                              validator: (v) => InputValidators.validateName(v, fieldName: "First Name"),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _middleNameController,
                              enabled: !_isSaving,
                              inputFormatters: InputValidators.nameFormatters,
                              decoration: _inputDecoration(
                                label: "Middle Name (Optional)",
                                icon: Icons.badge_outlined,
                                hint: "Middle Name",
                              ),
                              validator: (v) => InputValidators.validateName(v, fieldName: "Middle Name", isRequired: false),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastNameController,
                              enabled: !_isSaving,
                              inputFormatters: InputValidators.nameFormatters,
                              decoration: _inputDecoration(
                                label: "Last Name *",
                                icon: Icons.badge_outlined,
                                hint: "Last Name",
                              ),
                              validator: (v) => InputValidators.validateName(v, fieldName: "Last Name"),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _contactController,
                              enabled: !_isSaving,
                              keyboardType: TextInputType.phone,
                              inputFormatters: InputValidators.phoneFormatters,
                              decoration: _inputDecoration(
                                label: "Contact Number *",
                                icon: Icons.phone_outlined,
                                hint: "e.g. 09171234567",
                              ),
                              validator: (v) => InputValidators.validatePhoneNumber(v),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              enabled: !_isSaving,
                              maxLines: 2,
                              inputFormatters: InputValidators.addressFormatters,
                              decoration: _inputDecoration(
                                label: "Delivery Address *",
                                icon: Icons.location_on_outlined,
                                hint: "Street, Barangay, City",
                              ),
                              validator: (v) => InputValidators.validateAddress(v),
                            ),
                          ] else ...[
                            _buildDetailRow(Icons.badge_outlined, "First Name", _firstNameController.text.isEmpty ? "Not provided" : _firstNameController.text),
                            const Divider(height: 20),
                            _buildDetailRow(Icons.badge_outlined, "Middle Name", _middleNameController.text.isEmpty ? "None" : _middleNameController.text),
                            const Divider(height: 20),
                            _buildDetailRow(Icons.badge_outlined, "Last Name", _lastNameController.text.isEmpty ? "Not provided" : _lastNameController.text),
                            const Divider(height: 20),
                            _buildDetailRow(Icons.phone_outlined, "Contact Number", _contactController.text.isEmpty ? "Not provided" : _contactController.text),
                            const Divider(height: 20),
                            _buildDetailRow(Icons.location_on_outlined, "Delivery Address", _addressController.text.isEmpty ? "Not provided" : _addressController.text),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    if (_isEditing) ...[
                      PremiumActionButton(
                        label: "SAVE PROFILE CHANGES",
                        icon: Icons.check_circle_rounded,
                        isLoading: _isSaving,
                        onPressed: _saveProfile,
                      ),
                      const SizedBox(height: 10),
                      PremiumActionButton(
                        label: "CANCEL EDITING",
                        isSecondary: true,
                        onPressed: _isSaving ? null : () => setState(() => _isEditing = false),
                      ),
                    ] else ...[
                      PremiumActionButton(
                        label: "EDIT PROFILE DETAILS",
                        icon: Icons.edit_rounded,
                        onPressed: () => setState(() => _isEditing = true),
                      ),
                      const SizedBox(height: 10),
                      PremiumActionButton(
                        label: "LOG OUT",
                        icon: Icons.logout_rounded,
                        isSecondary: true,
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("Sign Out"),
                                ],
                              ),
                              content: const Text("Are you sure you want to log out of your account?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text("CANCEL"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                  child: const Text("LOG OUT"),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            await Supabase.instance.client.auth.signOut();
                            if (context.mounted) {
                              Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      filled: true,
      fillColor: const Color(0xFFF9F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5)),
      labelStyle: GoogleFonts.poppins(color: AppColors.textSecondary, fontSize: 13),
      floatingLabelStyle: GoogleFonts.poppins(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
      hintStyle: GoogleFonts.poppins(color: const Color(0xFFC7C7CC), fontSize: 13),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lightPink,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
              Text(
                value,
                style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
