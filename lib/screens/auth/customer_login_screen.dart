import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/state_widgets.dart';

class CustomerLoginScreen extends StatefulWidget {
  final String? targetRoute;

  const CustomerLoginScreen({super.key, this.targetRoute});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  late TabController _tabController;

  // Sign In Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Sign Up Controllers
  final _signUpFirstNameController = TextEditingController();
  final _signUpLastNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPhoneController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isOAuthLoading = false;
  bool _isPasswordVisible = false;
  bool _isSignUpPasswordVisible = false;
  bool _isSignUpConfirmPasswordVisible = false;
  bool _agreedToTerms = false; // Requirement 7: The checkbox must not be checked by default
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) {
        // Clear auto-filled saved passwords when switching to Create Account tab
        if (_signUpPasswordController.text.isNotEmpty && _signUpPasswordController.text == _passwordController.text) {
          _signUpPasswordController.clear();
          _signUpConfirmPasswordController.clear();
        }
      }
      if (mounted) setState(() {});
    });
    _loadRememberMe();
    _signUpPasswordController.addListener(() {
      setState(() {});
    });
    _passwordFocusNode.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingOAuthSession();
    });
  }

  Future<void> _loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool remember = prefs.getBool('remember_me_customer_enabled') ?? false;
      final String? savedEmail = prefs.getString('remember_me_customer_email');
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

  Future<void> _checkExistingOAuthSession() async {
    final user = _authService.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final profile = await _authService.ensureProfileExists(user: user, isCustomerPortal: true);
        if (mounted) {
          _navigateAfterAuth(profile);
        }
      } catch (e) {
        debugPrint("Session check error: $e");
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _signUpFirstNameController.dispose();
    _signUpLastNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPhoneController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _navigateAfterAuth(UserModel profile) async {
    if (!mounted) return;

    if (profile.accountStatus != AccountStatus.active) {
      await _authService.signOut();
      _showErrorDialog(
        title: 'Account Unavailable',
        message: 'Your account is ${profile.accountStatus.name}. Please contact support.',
      );
      return;
    }

    // STRICT PORTAL SEPARATION: Block staff members from logging in via Customer Login
    if (profile.role != UserRole.guest && profile.role != UserRole.customer) {
      final roleName = profile.role.name.toUpperCase();
      final email = profile.email.isNotEmpty ? profile.email : 'Your account';
      await _authService.signOut();
      if (!mounted) return;
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
                        child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Staff Account Detected",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "$email is registered as a $roleName staff member. You cannot log in through the customer page. Please log in using the Staff Portal instead.",
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
                            AppRoutes.staffLogin,
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
                        child: const Text('GO TO STAFF PORTAL', style: TextStyle(fontWeight: FontWeight.bold)),
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

    if (widget.targetRoute != null && widget.targetRoute!.isNotEmpty) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacementNamed(context, widget.targetRoute!);
      }
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
  }

  Future<void> _handleOAuthLogin(OAuthProvider provider) async {
    setState(() => _isOAuthLoading = true);
    try {
      final success = await _authService.signInWithOAuth(provider);
      if (!success && mounted) {
        setState(() => _isOAuthLoading = false);
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isOAuthLoading = false);
      _showErrorDialog(
        title: 'Authentication Failed',
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOAuthLoading = false);
      _showErrorDialog(
        title: 'Login Error',
        message: 'Unable to connect to ${provider.name.toUpperCase()} login provider.',
      );
    }
  }

  void _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();

    try {
      final profile = await _authService.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setBool('remember_me_customer_enabled', true);
        await prefs.setString('remember_me_customer_email', email);
      } else {
        await prefs.setBool('remember_me_customer_enabled', false);
        await prefs.remove('remember_me_customer_email');
      }

      _navigateAfterAuth(profile);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(
        title: 'Invalid Credentials',
        message: e.code == 'invalid_credentials' ? 'The email or password is incorrect.' : e.message,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(title: 'Login Error', message: e.toString().replaceAll("Exception: ", ""));
    }
  }

  void _handleEmailSignUp() async {
    // Requirement 9: If user attempts to continue without accepting, display exact text
    if (!_agreedToTerms) {
      _showErrorDialog(
        title: "Consent Required",
        message: "You must agree to the Terms of Service and Privacy Policy to create an account.",
      );
      return;
    }

    if (!_signUpFormKey.currentState!.validate()) return;

    if (_signUpPasswordController.text != _signUpConfirmPasswordController.text) {
      _showErrorDialog(title: "Password Mismatch", message: "Passwords do not match. Please re-enter.");
      return;
    }

    final email = _signUpEmailController.text.trim().toLowerCase();
    final password = _signUpPasswordController.text.trim();
    final firstName = _signUpFirstNameController.text.trim();
    final lastName = _signUpLastNameController.text.trim();
    final contactNumber = _signUpPhoneController.text.trim();
    final fullName = "$firstName $lastName";

    setState(() => _isLoading = true);

    try {
      // Step 1: Check if email is already registered in database
      final isRegistered = await _authService.isEmailRegistered(email);
      if (isRegistered) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showErrorDialog(
          title: "Email Already Registered",
          message: "An account with the email address \"$email\" already exists. Please sign in or reset your password.",
        );
        return;
      }

      // Step 2: Send 6-Digit OTP verification code to email
      final generatedCode = await _authService.initiateEmailSignUpOTP(
        email: email,
        password: password,
        fullName: fullName,
        contactNumber: contactNumber,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Verification code sent to $email! Please check your Gmail inbox and Spam folder."),
          duration: const Duration(seconds: 6),
          backgroundColor: const Color(0xFFE91E63),
        ),
      );

      // Step 3: Show 6-Digit OTP verification modal dialog
      _showOtpVerificationDialog(
        email: email,
        fullName: fullName,
        contactNumber: contactNumber,
        testCode: generatedCode,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.message.toLowerCase().contains('rate limit')
          ? 'Too many sign-up attempts in a short time. Please wait a moment or log in.'
          : e.message;
      _showErrorDialog(title: 'Registration Failed', message: msg);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog(title: 'Registration Failed', message: e.toString());
    }
  }

  void _showOtpVerificationDialog({
    required String email,
    required String fullName,
    String? username,
    String? contactNumber,
    String? testCode,
  }) {
    final otpController = TextEditingController();
    final focusNode = FocusNode();
    bool isVerifying = false;
    bool isResending = false;
    String? errorMessage;
    String selectedChannel = 'gmail'; // Default channel is Gmail OTP
    bool smsSent = false;
    int cooldownSeconds = 300;
    int resendAttempts = 0;
    const maxResendAttempts = 5;
    Timer? timer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Setup listener on controller to trigger rebuilds on typing so button updates instantly
            otpController.removeListener(() {});
            otpController.addListener(() {
              setDialogState(() {});
            });

            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (cooldownSeconds > 0) {
                setDialogState(() => cooldownSeconds--);
              } else {
                t.cancel();
              }
            });

            Future<void> verifyCode() async {
              final code = otpController.text.trim();
              if (code.length != 6 || isVerifying) return;

              setDialogState(() {
                isVerifying = true;
                errorMessage = null;
              });

              try {
                final profile = await _authService.verifyEmailSignUpOTP(
                  email: email,
                  code: code,
                  fullName: fullName,
                  username: username,
                  contactNumber: contactNumber,
                );

                timer?.cancel();
                focusNode.dispose();
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Account verified and created! Welcome to Bellie's Kitchen."),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _navigateAfterAuth(profile);
                }
              } catch (e) {
                setDialogState(() {
                  isVerifying = false;
                  otpController.clear();
                  focusNode.requestFocus();
                });
                if (dialogContext.mounted) {
                  await showErrorDialog(
                    dialogContext,
                    title: "Invalid Verification Code",
                    message: "The 6-digit code you entered is incorrect or expired. Please check your $selectedChannel and try again.",
                  );
                }
              }
            }

            Future<void> handleSwitchChannel(String channel) async {
              if (selectedChannel == channel || isResending) return;

              if (channel == 'sms') {
                if (contactNumber == null || contactNumber.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("No phone number provided during registration. Using Gmail OTP."),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  selectedChannel = 'sms';
                  errorMessage = null;
                });

                if (!smsSent) {
                  setDialogState(() => isResending = true);
                  try {
                    await _authService.sendSignUpSMS(phone: contactNumber);
                    smsSent = true;
                    setDialogState(() => isResending = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text("Verification code sent via SMS to $contactNumber."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    final cleanMsg = e is AuthException ? e.message : "SMS verification is unavailable. Please verify using Gmail OTP.";
                    setDialogState(() {
                      isResending = false;
                      errorMessage = cleanMsg;
                      selectedChannel = 'gmail';
                    });
                  }
                }
              } else {
                setDialogState(() {
                  selectedChannel = 'gmail';
                  errorMessage = null;
                });
              }
            }

            Future<void> handleResendCode() async {
              if (cooldownSeconds > 0 || isResending || resendAttempts >= maxResendAttempts) return;

              setDialogState(() {
                isResending = true;
                errorMessage = null;
              });

              try {
                if (selectedChannel == 'sms' && contactNumber != null && contactNumber.isNotEmpty) {
                  await _authService.sendSignUpSMS(phone: contactNumber);
                  smsSent = true;
                } else {
                  await _authService.resendSignUpOTP(email: email);
                }

                resendAttempts++;
                cooldownSeconds = 300;
                isResending = false;
                timer?.cancel();
                timer = null;
                setDialogState(() {});

                if (ctx.mounted) {
                  final channelName = selectedChannel == 'sms' ? "SMS to $contactNumber" : "Gmail ($email)";
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text("New verification code sent via $channelName."),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                setDialogState(() {
                  isResending = false;
                  errorMessage = "Failed to resend code: $e";
                });
              }
            }

            final currentDigits = otpController.text.trim();
            final isCodeComplete = currentDigits.length == 6;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 10,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              selectedChannel == 'gmail' ? Icons.mark_email_read_outlined : Icons.sms_outlined,
                              color: const Color(0xFFE91E63),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Verify Your Account",
                                  style: GoogleFonts.poppins(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E1E1E),
                                  ),
                                ),
                                Text(
                                  selectedChannel == 'gmail'
                                      ? "Default verification via Gmail"
                                      : "Secondary choice via SMS",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: isVerifying
                                ? null
                                : () {
                                    timer?.cancel();
                                    focusNode.dispose();
                                    Navigator.pop(dialogContext);
                                  },
                            icon: const Icon(Icons.close, color: Colors.grey),
                            tooltip: "Close",
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Method Choice Switcher (Default: Gmail, Second Choice: SMS)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => handleSwitchChannel('gmail'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selectedChannel == 'gmail' ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: selectedChannel == 'gmail'
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.mail_outline_rounded,
                                        size: 16,
                                        color: selectedChannel == 'gmail' ? const Color(0xFFE91E63) : Colors.grey[600],
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Gmail OTP (Default)",
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: selectedChannel == 'gmail' ? FontWeight.bold : FontWeight.w500,
                                          color: selectedChannel == 'gmail' ? const Color(0xFFE91E63) : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (contactNumber != null && contactNumber.isNotEmpty) ...[
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => handleSwitchChannel('sms'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: selectedChannel == 'sms' ? Colors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: selectedChannel == 'sms'
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.06),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.phone_android_rounded,
                                          size: 16,
                                          color: selectedChannel == 'sms' ? const Color(0xFFE91E63) : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "SMS OTP (Option)",
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: selectedChannel == 'sms' ? FontWeight.bold : FontWeight.w500,
                                            color: selectedChannel == 'sms' ? const Color(0xFFE91E63) : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Information Notice
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedChannel == 'gmail' ? Icons.info_outline_rounded : Icons.smartphone_rounded,
                              size: 18,
                              color: const Color(0xFFE91E63),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedChannel == 'gmail'
                                    ? "We sent a 6-digit verification code to $email. Please check your inbox and Spam folder."
                                    : "We sent a 6-digit verification code via SMS to $contactNumber.",
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700], height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 6 Box Input Row
                      GestureDetector(
                        onTap: () => focusNode.requestFocus(),
                        child: Stack(
                          children: [
                            // Invisible TextField overlaid across input area
                            Opacity(
                              opacity: 0.0,
                              child: TextField(
                                controller: otpController,
                                focusNode: focusNode,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                autofocus: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (val) {
                                  if (errorMessage != null) {
                                    setDialogState(() => errorMessage = null);
                                  }
                                  if (val.length == 6 && !isVerifying) {
                                    verifyCode();
                                  }
                                },
                              ),
                            ),

                            // 6 Visual Box Cells
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                final boxWidth = ((availableWidth - (5 * 8)) / 6).clamp(38.0, 52.0);
                                final boxHeight = (boxWidth * 1.15).clamp(46.0, 58.0);
                                final text = otpController.text;

                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    final char = index < text.length ? text[index] : '';
                                    final isFocused = focusNode.hasFocus && index == text.length;
                                    final isFilled = index < text.length;
                                    final hasError = errorMessage != null;

                                    return Container(
                                      width: boxWidth,
                                      height: boxHeight,
                                      decoration: BoxDecoration(
                                        color: (isFocused || isFilled) ? const Color(0xFFFFF5F8) : const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: hasError
                                              ? const Color(0xFFD32F2F)
                                              : (isFocused || isFilled
                                                  ? const Color(0xFFE91E63)
                                                  : const Color(0xFFCBD5E1)),
                                          width: (isFocused || hasError) ? 2.0 : 1.2,
                                        ),
                                        boxShadow: isFocused
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : [],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        char,
                                        style: GoogleFonts.poppins(
                                          fontSize: boxWidth * 0.48,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E1E1E),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // Error message callout
                      if (errorMessage != null && errorMessage!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFD32F2F), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFFD32F2F),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Resend Code Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (cooldownSeconds > 0) ...[
                            Icon(Icons.timer_outlined, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(
                              "Resend code in ${(cooldownSeconds ~/ 60).toString().padLeft(2, '0')}:${(cooldownSeconds % 60).toString().padLeft(2, '0')}",
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                            ),
                          ] else ...[
                            TextButton.icon(
                              onPressed: (isResending || resendAttempts >= maxResendAttempts)
                                  ? null
                                  : handleResendCode,
                              icon: isResending
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE91E63)))
                                  : const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFE91E63)),
                              label: Text(
                                "Resend Code via ${selectedChannel == 'sms' ? 'SMS' : 'Gmail'}",
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFE91E63)),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Main Action Button: VERIFY ACCOUNT
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE91E63),
                            disabledBackgroundColor: Colors.grey.shade200,
                            disabledForegroundColor: Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            elevation: isCodeComplete && !isVerifying ? 3 : 0,
                            shadowColor: const Color(0xFFE91E63).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: (isVerifying || !isCodeComplete) ? null : () => verifyCode(),
                          child: isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "VERIFY ACCOUNT",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- TERMS & PRIVACY MODALS ---

  void _openLegalModal({
    required String title,
    required String lastUpdated,
    required String content,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(180), // Requirement 10: Dark transparent background overlay
      barrierDismissible: true,
      builder: (dialogContext) {
        return FocusScope(
          autofocus: true,
          child: KeyboardListener(
            focusNode: FocusNode()..requestFocus(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 16,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 650,
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header (Always Visible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Last Updated: $lastUpdated",
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.black54),
                            tooltip: "Close",
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // Scrollable Body (Title & Buttons remain visible)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: SelectableText(
                          content,
                          style: const TextStyle(
                            fontSize: 13.5,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),

                    // Footer Buttons (Always Visible)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text("Close", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTermsOfService() {
    _openLegalModal(
      title: "Terms of Service & Account Agreement",
      lastUpdated: "September 23, 2026",
      content: """
Welcome to Bellie’s SmartServe! By accessing, registering an account, or placing an order through our application, website, or customer portal, you expressly agree to be legally bound by these Terms of Service. Please read them carefully before creating your account.

1. Acceptance of Terms & Eligibility
- By registering a user account or submitting an order, you certify that you are at least 18 years of age or possess legal parental/guardian consent.
- You agree to provide accurate, current, and complete information during registration and to update such information promptly if it changes.

2. User Accounts, Credentials & Security
- You are solely responsible for maintaining the strict confidentiality of your password, login credentials, and account details.
- You accept full responsibility for all activities, orders, and transactions conducted under your account.
- Bellie’s SmartServe shall not be held liable for any loss or damage arising from unauthorized use of your account due to your failure to secure your credentials.

3. Ordering, Inventory & Pricing Policy
- All food orders (Silog meals, Korean noodles, beverages, and specialties) are subject to kitchen preparation capacity and real-time stock availability.
- Prices, packaging fees, and delivery rates are listed in Philippine Pesos (₱) and are inclusive of applicable VAT unless specified otherwise.
- We reserve the right to refuse, cancel, or adjust any order in cases of pricing errors, ingredient shortages, or suspected fraudulent activity.

4. Delivery, Fulfillment & Cancellations
- Estimated delivery times provided by the app are approximations and may vary depending on weather conditions, traffic, kitchen queue, and rider availability.
- Once food preparation has commenced in our kitchen, order modification or cancellation requests cannot be accommodated.
- Customers must ensure someone is available at the designated delivery address to receive and pay for the order upon arrival.

5. Online Payments & Cash on Delivery (COD)
- Cash on Delivery (COD) orders require exact or sufficient payment upon delivery. Riders carry limited change.
- Online payments (such as GCash or InstaPay) require strict submission of valid, unique reference numbers and receipts. Fraudulent or duplicate reference submissions will result in immediate account suspension and blacklisting.

6. Acceptable Use & Code of Conduct
- Users agree not to engage in bogus ordering, spamming, harassment of delivery riders or kitchen staff, or submission of fraudulent feedback/reviews.
- Any violation of this code of conduct will result in immediate, permanent termination of your account without prior notice.

7. Modifications to Terms & Termination
- Bellie’s SmartServe reserves the right to modify, amend, or update these Terms of Service at any time. Continued use of the platform constitutes acceptance of the revised terms.
""",
    );
  }

  void _showPrivacyPolicy() {
    _openLegalModal(
      title: "Privacy Policy",
      lastUpdated: "September 23, 2026",
      content: """
At Bellie’s SmartServe, protecting your privacy and securing your personal information is our top priority.

1. Information We Collect
We collect information you provide directly during registration and order placement:
- Contact details (Full name, email address, contact phone number).
- Delivery addresses for accurate rider dispatch.
- Order history and preferences.
- Authentication metadata when logging in through Google or Facebook OAuth.

2. How We Use Your Data
Your personal data is strictly used for:
- Processing, cooking, and delivering your food orders.
- Providing live delivery tracking updates.
- Customer support and account recovery.
- Compliance with food safety and legal accountability requirements.

3. Data Sharing & Security
- We NEVER sell your personal data to third parties.
- Delivery information is shared only with the assigned rider strictly for fulfillment purposes.
- Passwords are encrypted using modern cryptographic standards managed by Supabase.

4. Your Rights
You have the right to access, update, or request the deletion of your account information at any time by contacting our support or using the account profile settings.
""",
    );
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
              Text("Reset Password", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter your registered email address and we'll send you a password reset link.",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email Address",
                  hintText: "e.g. customer@example.com",
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
                              content: Text("No account found with email '$email'. Please check your email address."),
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
                              "A password reset link has been sent to $email.\n\nPlease check your inbox or spam folder and click the link to reset your password.",
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
    final bool isDesktop = ResponsiveLayout.isDesktop(context) || ResponsiveLayout.isTablet(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), // iOS system background
      body: Stack(
        children: [
          // Enhanced subtle glow for modern feel
          Positioned(top: -100, right: -100, child: _backgroundGlow(600, const Color(0xFFFF4081).withAlpha(20))),
          Positioned(bottom: -100, left: -100, child: _backgroundGlow(700, const Color(0xFF448AFF).withAlpha(15))),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Container(
                width: isDesktop ? 1050 : 450,
                decoration: BoxDecoration(
                  color: Colors.white, // Clean premium white
                  borderRadius: BorderRadius.circular(24), // iOS typical radius
                  border: Border.all(color: Colors.white, width: 2), // Frosted edge effect
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 32, offset: const Offset(0, 16)),
                    BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundGlow(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withAlpha(0)])),
    );
  }

  Widget _buildDesktopLayout() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 700),
              decoration: const BoxDecoration(
                image: DecorationImage(image: AssetImage('assets/images/loginpage.png'), fit: BoxFit.cover),
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter, 
                        stops: const [0.0, 0.5, 1.0], 
                        colors: [Colors.black.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.85)]
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15), 
                            borderRadius: BorderRadius.circular(20), 
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
                          ),
                          child: Image.asset('assets/images/Bellieslogo.png', height: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 120),
                        Text(
                          "Savor the\nAuthentic Flavors", 
                          style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.1)
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Experience freshly cooked Silog and our finest Korean favorites. Elevating your dining experience every day.", 
                          style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w400, height: 1.5)
                        ),
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            _userBadge("U1", "https://api.dicebear.com/7.x/avataaars/png?seed=Hallel"),
                            _userBadge("U2", "https://api.dicebear.com/7.x/avataaars/png?seed=Juan"),
                            _userBadge("U3", "https://api.dicebear.com/7.x/avataaars/png?seed=Maria"),
                            const SizedBox(width: 16),
                            Text("Joined by 1,000+ local foodies", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 520, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 48), child: _buildFormContent())),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          width: double.infinity, height: 200,
          decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/images/loginpage.png'), fit: BoxFit.cover)),
          child: Container(
            color: Colors.black.withAlpha(100),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Image.asset('assets/images/Bellieslogo.png', height: 60, color: Colors.white),
              const SizedBox(height: 8),
              Text("BELLIE'S KITCHEN", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ]),
          ),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32), child: _buildFormContent()),
      ],
    );
  }

  Widget _userBadge(String name, String url) {
    return Align(
      widthFactor: 0.7,
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: Image.network(
              url,
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFFE91E63),
                  child: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    final bool isSignIn = _tabController.index == 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isSignIn ? "Welcome Back" : "Create Account", 
          style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF1D1D1F), letterSpacing: -0.5)
        ),
        const SizedBox(height: 8),
        Text(
          isSignIn ? "Sign in to access your favorite meals." : "Join us and enjoy delicious food.", 
          style: GoogleFonts.poppins(color: const Color(0xFF86868B), fontSize: 14)
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF0), // Perfect iOS Segmented Control background
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: _tabLink("Sign In", 0)),
              Expanded(child: _tabLink("Create Account", 1)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: isSignIn ? 300 : 640,
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildSignInForm(), _buildSignUpForm()],
          ),
        ),
        const SizedBox(height: 8),
        _buildOAuthDivider(),
        const SizedBox(height: 12),
        _buildOAuthButtons(),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.staffLogin),
            icon: Icon(Icons.badge_outlined, color: const Color(0xFF86868B), size: 16),
            label: Text("STAFF PORTAL", style: GoogleFonts.poppins(color: const Color(0xFF86868B), fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _tabLink(String label, int index) {
    bool active = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.index = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10), // Matched iOS Segmented Control
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            color: active ? const Color(0xFF1D1D1F) : const Color(0xFF86868B),
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildOAuthDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE5E5EA))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("Or Continue With", style: GoogleFonts.poppins(color: const Color(0xFF86868B), fontSize: 12, fontWeight: FontWeight.w500))
        ),
        const Expanded(child: Divider(color: Color(0xFFE5E5EA)))
      ]
    );
  }

  Widget _buildOAuthButtons() {
    if (_isOAuthLoading) return const Center(child: CircularProgressIndicator());
    return SizedBox(
      width: double.infinity,
      child: _oauthBtn("Continue with Google", _googleIcon(), Colors.white, const Color(0xFF1D1D1F), () => _handleOAuthLogin(OAuthProvider.google)),
    );
  }

  Widget _oauthBtn(String label, Widget icon, Color bg, Color text, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: bg == Colors.white ? Border.all(color: Colors.grey.shade300, width: 1) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, 
            children: [
              icon, 
              const SizedBox(width: 12), 
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: text))
            ]
          ),
        ),
      ),
    );
  }

  Widget _googleIcon() {
    return Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Center(child: Text("G", style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.w900, fontSize: 14))));
  }

  Widget _buildSignInForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _inputLabel("Email Address"),
          TextFormField(
            controller: _emailController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: _inputDecoration("Enter your email", Icons.email_outlined),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return "Email address is required";
              if (!RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                return "Enter a valid email address (e.g. name@domain.com)";
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _inputLabel("Password"),
          TextFormField(
            controller: _passwordController,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            obscureText: !_isPasswordVisible,
            decoration: _inputDecoration("Enter your password", Icons.lock_outline, suffix: IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, size: 18),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return "Password is required";
              if (val.trim().length < 6) return "Password must be at least 6 characters";
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InkWell(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
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
                        onChanged: (val) => setState(() => _rememberMe = val ?? false),
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
                onPressed: _showForgotPasswordDialog,
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
          const SizedBox(height: 12),
          _isLoading ? const Center(child: CircularProgressIndicator()) : _primaryBtn("SIGN IN", _handleEmailLogin, isEnabled: true),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputLabel("First Name"),
                      TextFormField(
                        controller: _signUpFirstNameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        maxLength: 30,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                          DenyLeadingSpaceFormatter(),
                        ],
                        decoration: _inputDecoration("e.g. Juan", null),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "First name required";
                          final trimmed = v.trim();
                          if (v.startsWith(' ')) return "Cannot start with a space";
                          if (trimmed.length < 2) return "Must be at least 2 letters";
                          if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(trimmed)) {
                            return "Numbers & symbols not allowed";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _inputLabel("Last Name"),
                      TextFormField(
                        controller: _signUpLastNameController,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        maxLength: 30,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                          DenyLeadingSpaceFormatter(),
                        ],
                        decoration: _inputDecoration("e.g. Cruz", null),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return "Last name required";
                          final trimmed = v.trim();
                          if (v.startsWith(' ')) return "Cannot start with a space";
                          if (trimmed.length < 2) return "Must be at least 2 letters";
                          if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(trimmed)) {
                            return "Numbers & symbols not allowed";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ]),
            const SizedBox(height: 12),
            _inputLabel("Email Address"),
            TextFormField(
              controller: _signUpEmailController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.emailAddress,
              maxLength: 60,
              decoration: _inputDecoration("your@email.com", Icons.email_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Email address is required";
                final trimmed = v.trim();
                if (trimmed.length > 60) return "Email address cannot exceed 60 characters";
                final emailRegex = RegExp(
                  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$",
                );
                if (!emailRegex.hasMatch(trimmed)) {
                  return "Enter a valid email address (e.g. name@domain.com or user@lu.edu.ph)";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _inputLabel("Phone Number"),
            TextFormField(
              controller: _signUpPhoneController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: _inputDecoration("09XXXXXXXXX", Icons.phone_outlined),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Phone number is required";
                final trimmed = v.trim();
                if (!RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
                  return "Enter a valid 11-digit PH mobile number starting with 09";
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _inputLabel("Password"),
            TextFormField(
              controller: _signUpPasswordController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              focusNode: _passwordFocusNode,
              obscureText: !_isSignUpPasswordVisible,
              autofillHints: const [AutofillHints.newPassword],
              enableSuggestions: false,
              autocorrect: false,
              maxLength: 30,
              decoration: _inputDecoration("••••••••", Icons.lock_outline, suffix: IconButton(
                icon: Icon(_isSignUpPasswordVisible ? Icons.visibility : Icons.visibility_off, size: 18),
                onPressed: () => setState(() => _isSignUpPasswordVisible = !_isSignUpPasswordVisible),
              )),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Password required";
                if (!(_hasMinLength && _hasUppercase && _hasNumberOrSymbol)) {
                  return "Password does not meet all security requirements";
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            if (_passwordFocusNode.hasFocus) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _passwordStrengthCount / 3.0,
                      backgroundColor: Colors.grey.shade200,
                      color: _passwordStrengthCount == 3
                          ? Colors.green
                          : _passwordStrengthCount == 2
                              ? Colors.orange
                              : Colors.red,
                      minHeight: 4,
                    ),
                    const SizedBox(height: 8),
                    _buildPasswordRequirementRow("Minimum 8 characters", _hasMinLength),
                    _buildPasswordRequirementRow("At least one uppercase letter", _hasUppercase),
                    _buildPasswordRequirementRow("One number or symbol", _hasNumberOrSymbol),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _inputLabel("Confirm Password"),
            TextFormField(
              controller: _signUpConfirmPasswordController,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              obscureText: !_isSignUpConfirmPasswordVisible,
              autofillHints: const [AutofillHints.newPassword],
              enableSuggestions: false,
              autocorrect: false,
              maxLength: 30,
              decoration: _inputDecoration("Re-enter password", Icons.lock_outline, suffix: IconButton(
                icon: Icon(_isSignUpConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, size: 18),
                onPressed: () => setState(() => _isSignUpConfirmPasswordVisible = !_isSignUpConfirmPasswordVisible),
              )),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Confirm password required";
                if (v != _signUpPasswordController.text) return "Passwords do not match";
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Required Consent Checkbox with Clickable Text Links (Requirements 1, 4, 7, 8)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _agreedToTerms,
                    activeColor: const Color(0xFFE91E63), // Keep brand red/pink
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), // iOS checkbox style
                    side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                    onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF86868B), height: 1.5),
                      children: [
                        const TextSpan(text: "I have read and agree to the "),
                        TextSpan(
                          text: "Terms of Service",
                          style: const TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = _showTermsOfService,
                        ),
                        const TextSpan(text: " and "),
                        TextSpan(
                          text: "Privacy Policy",
                          style: const TextStyle(
                            color: Color(0xFF1D1D1F),
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = _showPrivacyPolicy,
                        ),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)))
                : _primaryBtn(
                    "CREATE ACCOUNT",
                    _handleEmailSignUp,
                    isEnabled: _agreedToTerms,
                  ),
          ],
        ),
      ),
    );
  }

  bool get _hasMinLength => _signUpPasswordController.text.trim().length >= 8;
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_signUpPasswordController.text);
  bool get _hasNumberOrSymbol => RegExp(r'[0-9!@#$%^&*(),.?":{}|<>\-_]').hasMatch(_signUpPasswordController.text);

  int get _passwordStrengthCount {
    int count = 0;
    if (_hasMinLength) count++;
    if (_hasUppercase) count++;
    if (_hasNumberOrSymbol) count++;
    return count;
  }

  Widget _buildPasswordRequirementRow(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: met ? Colors.green : Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green.shade800 : Colors.grey.shade600,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1D1D1F), // Deep iOS dark gray
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData? icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      counterText: "", // Hides the annoying character counter
      hintStyle: GoogleFonts.poppins(color: const Color(0xFF86868B), fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF86868B)) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF5F5F7).withOpacity(0.5), // Clean iOS light gray
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300, width: 1)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5)),
      errorMaxLines: 3,
      errorStyle: GoogleFonts.poppins(fontSize: 11, height: 1.2, color: const Color(0xFFFF3B30), fontWeight: FontWeight.w500),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap, {required bool isEnabled}) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: isEnabled
            ? [BoxShadow(color: const Color(0xFFE91E63).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))]
            : [],
      ),
      child: ElevatedButton(
        onPressed: isEnabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE91E63),
          disabledBackgroundColor: const Color(0xFFE5E5EA),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF86868B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class DenyLeadingSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }
    return newValue;
  }
}
