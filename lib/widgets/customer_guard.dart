import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_routes.dart';
import 'state_widgets.dart';

class CustomerGuard extends StatefulWidget {
  final Widget child;

  const CustomerGuard({super.key, required this.child});

  @override
  State<CustomerGuard> createState() => _CustomerGuardState();
}

class _CustomerGuardState extends State<CustomerGuard> {
  late final Future<bool> _authorized;

  @override
  void initState() {
    super.initState();
    _authorized = _checkAuthorization();
  }

  Future<bool> _checkAuthorization() async {
    final user = Supabase.instance.client.auth.currentUser;
    // Must be logged in AND NOT anonymous
    return user != null && !user.isAnonymous;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorized,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: LoadingState());
        if (snapshot.data == true) return widget.child;

        // Redirect to login if not authorized
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.login,
            arguments: ModalRoute.of(context)?.settings.name,
          );
        });

        return const Scaffold(body: LoadingState());
      },
    );
  }
}
