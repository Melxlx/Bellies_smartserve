import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
    _checkExistingSession();
  }

  Future<void> _loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool remember = prefs.getBool('remember_me_staff_enabled') ?? false;
      final String? savedEmail = prefs.getString('remember_me_staff_email');
      if (remember && savedEmail != null && savedEmail.isNotEmpty) {
        if (mounted) {
          setState(() {
            _rememberMe = true;
            _emailController.text = savedEmail;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _checkExistingSession() async {
    final user = _authService.currentUser;
    if (user != null && !user.isAnonymous) {
      setState(() => _isLoading = true);
      try {
        final profile = await _authService.ensureProfileExists(user: user);
        _navigateToDashboard(profile);
      } catch (_) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToDashboard(UserModel profile) {
    if (!mounted) return;

    if (profile.accountStatus != AccountStatus.active) {
      _authService.signOut();
      _showErrorDialog(
        title: 'Account Unavailable',
        message: 'Your staff account is ${profile.accountStatus.name}.',
      );
      return;
    }

    final cleanEmail = profile.email.trim().toLowerCase();
    final isOwnerEmail = cleanEmail == 'mberuela11@gmail.com' ||
        cleanEmail == 'jubileealfonnn@gmail.com' ||
        cleanEmail == 'owner@bellies.com' ||
        profile.position.toLowerCase().contains('owner');

    final effectiveRole = isOwnerEmail ? UserRole.owner : profile.role;

    String? route;
    switch (effectiveRole) {
      case UserRole.owner: route = AppRoutes.ownerDashboard; break;
      case UserRole.cashier: route = AppRoutes.cashierDashboard; break;
      case UserRole.kitchen: route = AppRoutes.kitchenDashboard; break;
      case UserRole.rider: route = AppRoutes.riderDashboard; break;
      case UserRole.guest:
      case UserRole.customer:
        return;
    }

    Navigator.pushReplacementNamed(context, route);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 42),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleStaffLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    try {
      final profile = await _authService.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (profile.role == UserRole.guest || profile.role == UserRole.customer) {
        final email = profile.email.isNotEmpty ? profile.email : 'Your account';
        await _authService.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
            backgroundColor: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 28),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Customer Account Detected",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "$email is registered as a Customer account. You cannot log in through the Staff Portal. Please log in using the Customer Online Ordering Portal instead.",
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('CANCEL', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.customerMenu,
                              (route) => false,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            elevation: 0,
                          ),
                          child: const Text('GO TO CUSTOMER PORTAL', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me_staff_enabled', true);
        await prefs.setString('remember_me_staff_email', email);
      } else {
        await prefs.setBool('remember_me_staff_enabled', false);
        await prefs.remove('remember_me_staff_email');
      }

      _navigateToDashboard(profile);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(
        title: 'Invalid Staff Credentials',
        message: e.code == 'invalid_credentials'
            ? 'The email or password is incorrect.'
            : e.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(
        title: 'Login Error',
        message: 'An unexpected error occurred. Please check your connection.',
      );
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFFE91E63)),
              const SizedBox(width: 10),
              Text("Staff Reset Password", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your registered staff email address to receive a password reset link.",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Staff Email Address",
                  hintText: "e.g. staff@bellies.com",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE91E63)),
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty || !RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid email address.")),
                        );
                        return;
                      }

                      setDialogState(() => isSending = true);

                      try {
                        final isRegistered = await _authService.isEmailRegistered(email);
                        if (!isRegistered) {
                          setDialogState(() => isSending = false);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text("No staff account found with email '$email'. Please check your email."),
                              backgroundColor: Colors.orange[800],
                            ),
                          );
                          return;
                        }

                        final String? redirectTo = kIsWeb
                            ? Uri.base.replace(queryParameters: const {}, fragment: AppRoutes.resetPassword).toString()
                            : null;

                        await Supabase.instance.client.auth.resetPasswordForEmail(
                          email,
                          redirectTo: redirectTo,
                        );

                        if (!context.mounted) return;
                        Navigator.pop(dialogContext);

                        showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Row(
                              children: [
                                Icon(Icons.mark_email_read_rounded, color: Colors.green, size: 28),
                                SizedBox(width: 10),
                                Text("Reset Link Sent!"),
                              ],
                            ),
                            content: Text(
                              "A staff password reset link has been sent to $email.\n\nPlease check your inbox or spam folder and click the link to reset your password.",
                              style: const TextStyle(fontSize: 13, height: 1.4),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE91E63),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Unable to send reset link: ${e.toString().replaceAll("Exception: ", "")}"),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SEND RESET LINK"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bel.jpg',
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                color: const Color(0xFF3D0B1E),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF3D0B1E).withAlpha(160),
                      const Color(0xFF7A092B).withAlpha(140),
                      Colors.black.withAlpha(180),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ResponsiveLayout(
                  mobile: _buildStaffContainer(maxWidth: double.infinity),
                  desktop: _buildStaffContainer(maxWidth: 440),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffContainer({required double maxWidth}) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(230),
              border: Border.all(color: const Color(0xFFFFD1DC), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withAlpha(80),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/Bellieslogo.png',
                height: 85,
                width: 85,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => const Icon(
                  Icons.restaurant,
                  size: 60,
                  color: Color(0xFFE91E63),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Bellie’s SmartServe",
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Staff & Management Portal",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withAlpha(220),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withAlpha(180), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.badge_outlined, color: Color(0xFFE91E63), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "Employee Login",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocusNode),
                      decoration: InputDecoration(
                        labelText: "Staff Email Address",
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFE91E63)),
                        filled: true,
                        fillColor: const Color(0xFFFDF8FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        errorMaxLines: 3,
                        errorStyle: GoogleFonts.poppins(fontSize: 11, height: 1.2, color: const Color(0xFFD32F2F), fontWeight: FontWeight.w500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Staff email address is required";
                        }
                        if (!RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                          return "Please enter a valid email address (e.g. name@domain.com)";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isLoading,
                      focusNode: _passwordFocusNode,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _handleStaffLogin(),
                      decoration: InputDecoration(
                        labelText: "Password",
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFE91E63)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey[600],
                          ),
                          onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible,
                          ),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFDF8FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        errorMaxLines: 3,
                        errorStyle: GoogleFonts.poppins(fontSize: 11, height: 1.2, color: const Color(0xFFD32F2F), fontWeight: FontWeight.w500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE91E63), width: 2),
                        ),
                      ),
                      obscureText: !_isPasswordVisible,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Password is required";
                        }
                        if (value.trim().length < 6) {
                          return "Password must be at least 6 characters";
                        }
                        return null;
                      },
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: _isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: const Color(0xFFE91E63),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: _isLoading ? null : (val) => setState(() => _rememberMe = val ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Remember me",
                                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isLoading ? null : _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFE91E63),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            "Forgot Password?",
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                        : SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _handleStaffLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFFE91E63).withAlpha(100),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                "SIGN IN TO STAFF PORTAL",
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () => Navigator.pushReplacementNamed(
              context,
              AppRoutes.customerLogin,
            ),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(90),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Customer Online Ordering Portal",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
