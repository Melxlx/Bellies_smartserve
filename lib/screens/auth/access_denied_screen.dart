import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import '../../services/auth_service.dart';
import 'not_found_screen.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NotFound404Screen(
      title: "Access Denied",
      message:
          "You do not have the required permissions to view this portal or page. Please contact your administrator.",
      buttonText: "Return to Home",
      onButtonPressed: () async {
        await AuthService().signOut();
        if (context.mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
        }
      },
    );
  }
}
