import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_routes.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  String? _getInitialRequestedRoute() {
    String fragment = Uri.base.fragment.trim();
    if (fragment.isNotEmpty) {
      if (!fragment.startsWith('/')) {
        fragment = '/$fragment';
      }
      if (fragment.contains('?')) {
        fragment = fragment.split('?').first;
      }
      if (fragment.length > 1 && fragment.endsWith('/')) {
        fragment = fragment.substring(0, fragment.length - 1);
      }
      if (fragment != '/' && fragment != '/splash' && fragment != AppRoutes.splash) {
        return fragment;
      }
    }

    String path = Uri.base.path.trim();
    if (path.isNotEmpty && path != '/' && path != '/splash' && path != AppRoutes.splash) {
      if (!path.startsWith('/')) {
        path = '/$path';
      }
      if (path.contains('?')) {
        path = path.split('?').first;
      }
      if (path.length > 1 && path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      return path;
    }

    return null;
  }

  Future<void> _startApp() async {
    try {
      // Keep the branding visible briefly before routing.
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      final queryParameters = Uri.base.queryParameters;
      final isPasswordRecovery =
          queryParameters['type'] == 'recovery' ||
          Uri.base.fragment.contains('type=recovery');

      if (isPasswordRecovery) {
        final recoveryCode = queryParameters['code'];
        if (recoveryCode != null && recoveryCode.isNotEmpty) {
          try {
            await Supabase.instance.client.auth.exchangeCodeForSession(
              recoveryCode,
            );
          } catch (e) {
            debugPrint("Error exchanging recovery code: $e");
          }
        }
        await _waitForRecoverySession();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.resetPassword);
        return;
      }

      await _waitForRecoverySession();
      if (!mounted) return;

      final session = Supabase.instance.client.auth.currentSession;

      // Routing Logic for Anonymous / Unauthenticated Visitors
      if (session == null || session.user.isAnonymous) {
        if (!mounted) return;
        final requestedRoute = _getInitialRequestedRoute();
        if (requestedRoute != null && (
            requestedRoute.startsWith('/menu') ||
            requestedRoute.startsWith('/customer') ||
            requestedRoute.startsWith('/checkout') ||
            requestedRoute.startsWith('/tracking') ||
            requestedRoute.startsWith('/reset-password')
        )) {
          Navigator.pushReplacementNamed(context, requestedRoute);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
        }
        return;
      }

      // Fetch or auto-create profile for authenticated user
      final profile = await AuthService().ensureProfileExists(
        user: session.user,
        isCustomerPortal: true,
      );

      if (profile.accountStatus != AccountStatus.active) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      if (!mounted) return;

      // Preserve current URL route if user reloads / refreshes the page
      final requestedRoute = _getInitialRequestedRoute();
      if (requestedRoute != null && requestedRoute != '/' && requestedRoute != '/splash') {
        if (requestedRoute == '/staff' || requestedRoute == '/staff/') {
          switch (profile.role) {
            case UserRole.owner:
              Navigator.pushReplacementNamed(context, AppRoutes.staffDashboard);
              return;
            case UserRole.cashier:
              Navigator.pushReplacementNamed(context, AppRoutes.cashierDashboard);
              return;
            case UserRole.kitchen:
              Navigator.pushReplacementNamed(context, AppRoutes.staffKitchen);
              return;
            case UserRole.rider:
              Navigator.pushReplacementNamed(context, AppRoutes.riderDashboard);
              return;
            default:
              Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
              return;
          }
        } else {
          Navigator.pushReplacementNamed(context, requestedRoute);
          return;
        }
      }

      // Default Role-Based Auto-Routing if no specific deep URL route was requested:
      switch (profile.role) {
        case UserRole.owner:
          Navigator.pushReplacementNamed(context, AppRoutes.staffDashboard);
          break;
        case UserRole.cashier:
          Navigator.pushReplacementNamed(context, AppRoutes.cashierDashboard);
          break;
        case UserRole.kitchen:
          Navigator.pushReplacementNamed(context, AppRoutes.staffKitchen);
          break;
        case UserRole.rider:
          Navigator.pushReplacementNamed(context, AppRoutes.riderDashboard);
          break;
        case UserRole.guest:
        case UserRole.customer:
          Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
          break;
      }
    } catch (e) {
      debugPrint("SplashScreen error during initialization: $e");
      if (mounted) {
        if (e is AssertionError && e.toString().contains('Supabase.instance')) {
          return;
        }

        // If an OAuth code verifier error occurs (e.g., bad_code_verifier / expired code on mobile browser),
        // gracefully fall back to Customer Menu instead of crashing the splash screen!
        final errStr = e.toString();
        if (errStr.contains('bad_code_verifier') ||
            errStr.contains('code_challenge') ||
            errStr.contains('code_verifier') ||
            errStr.contains('AuthApiException')) {
          try {
            await Supabase.instance.client.auth.signOut();
          } catch (_) {}
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
            return;
          }
        }

        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _waitForRecoverySession() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (Supabase.instance.client.auth.currentSession != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: Checkbox.width > 0 ? MainAxisAlignment.center : MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                const Text(
                  "Startup Error",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setState(() {
                    _error = null;
                    _startApp();
                  }),
                  child: const Text("RETRY"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/Bellieslogo.png', height: 180),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFFE91E63)),
          ],
        ),
      ),
    );
  }
}
