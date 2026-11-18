import 'package:flutter/material.dart';
import '../core/app_routes.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'state_widgets.dart';

class StaffGuard extends StatefulWidget {
  final Widget child;
  final List<UserRole>? allowedRoles;

  const StaffGuard({
    super.key,
    required this.child,
    this.allowedRoles,
  });

  @override
  State<StaffGuard> createState() => _StaffGuardState();
}

class _StaffGuardState extends State<StaffGuard> {
  late final Future<UserModel?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _checkAuthAndFetchProfile();
  }

  Future<UserModel?> _checkAuthAndFetchProfile() async {
    final authService = AuthService();
    final user = authService.currentUser;

    if (user == null || user.isAnonymous) return null;

    try {
      final profile = await authService.ensureProfileExists(user: user);
      if (profile.accountStatus != AccountStatus.active) {
        await authService.signOut();
        return null;
      }
      return profile;
    } catch (_) {
      return null;
    }
  }

  void _redirectByRole(BuildContext context, UserRole role) {
    String fallbackRoute = AppRoutes.customerMenu;
    switch (role) {
      case UserRole.owner:
        fallbackRoute = AppRoutes.staffDashboard;
        break;
      case UserRole.cashier:
        fallbackRoute = AppRoutes.cashierDashboard;
        break;
      case UserRole.kitchen:
        fallbackRoute = AppRoutes.staffKitchen;
        break;
      case UserRole.rider:
        fallbackRoute = AppRoutes.riderDashboard;
        break;
      case UserRole.customer:
      case UserRole.guest:
        fallbackRoute = AppRoutes.customerMenu;
        break;
    }
    Navigator.pushReplacementNamed(context, fallbackRoute);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingState());
        }

        final profile = snapshot.data;

        // 1. Not Authenticated or Inactive session
        if (profile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.staffLogin,
              arguments: ModalRoute.of(context)?.settings.name,
            );
          });
          return const Scaffold(body: LoadingState());
        }

        // 2. Customer or Guest attempting staff area
        if (profile.role == UserRole.guest || profile.role == UserRole.customer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
          });
          return const Scaffold(body: LoadingState());
        }

        // 3. Strict Role Restriction Check (e.g. Owner trying to access Rider Dashboard, or Cashier trying to access Employees)
        if (widget.allowedRoles != null &&
            !widget.allowedRoles!.contains(profile.role)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _redirectByRole(context, profile.role);
          });
          return const Scaffold(body: LoadingState());
        }

        return widget.child;
      },
    );
  }
}
