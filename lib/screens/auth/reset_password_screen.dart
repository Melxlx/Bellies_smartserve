import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSaving = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (Supabase.instance.client.auth.currentSession == null) {
      await _showErrorDialog(
        title: 'Invalid Reset Link',
        message: 'This password reset link is invalid or has expired. Please request a new link.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated. Please log in again.'),
          backgroundColor: Colors.green,
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _showErrorDialog(
        title: 'Password Update Failed',
        message: error.message,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await _showErrorDialog(
        title: 'Password Update Failed',
        message: 'Unable to update your password. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Set New Password',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isSaving,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip: _isPasswordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible,
                            ),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 6
                            ? 'Password must be at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        enabled: !_isSaving,
                        obscureText: !_isConfirmPasswordVisible,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            tooltip: _isConfirmPasswordVisible
                                ? 'Hide password'
                                : 'Show password',
                            onPressed: () => setState(
                              () => _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible,
                            ),
                          ),
                        ),
                        validator: (value) => value != _passwordController.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _updatePassword,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('UPDATE PASSWORD'),
                      ),
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
