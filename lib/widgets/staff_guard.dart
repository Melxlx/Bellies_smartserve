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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserModel?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingState());
        }

        final profile = snapshot.data;

        // 1. Not Authenticated or Inactive
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

        // 2. Unauthorized Role (Customer attempting staff area)
        if (profile.role == UserRole.guest) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.accessDenied);
          });
          return const Scaffold(body: LoadingState());
        }

        // 3. Specific Role Check (e.g. only Owner allowed in Employees)
        if (widget.allowedRoles != null &&
            !widget.allowedRoles!.contains(profile.role)) {
          // If the user is staff but doesn't have the specific role for this page
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, AppRoutes.accessDenied);
          });
          return const Scaffold(body: LoadingState());
        }

        return widget.child;
      },
    );
  }
}
