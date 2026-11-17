import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'not_found_screen.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NotFound404Screen(
      title: "Access Denied",
      message:
          "You do not have the required permissions to view this portal or page. Click below to return safely to your dashboard.",
      buttonText: "Return to Your Dashboard",
      onButtonPressed: () async {
        final authService = AuthService();
        final user = authService.currentUser;
        if (user == null || user.isAnonymous) {
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
          }
          return;
        }

        try {
          final profile = await authService.ensureProfileExists(user: user);
          if (context.mounted) {
            String route = AppRoutes.customerMenu;
            switch (profile.role) {
              case UserRole.owner:
                route = AppRoutes.staffDashboard;
                break;
              case UserRole.cashier:
                route = AppRoutes.staffPos;
                break;
              case UserRole.kitchen:
                route = AppRoutes.staffKitchen;
                break;
              case UserRole.rider:
                route = AppRoutes.riderDashboard;
                break;
              case UserRole.customer:
              case UserRole.guest:
                route = AppRoutes.customerMenu;
                break;
            }
            Navigator.pushReplacementNamed(context, route);
          }
        } catch (_) {
          if (context.mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
          }
        }
      },
    );
  }
}
