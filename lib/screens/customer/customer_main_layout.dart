import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_routes.dart';
import '../../widgets/customer_bottom_nav_bar.dart';
import '../delivery/customer_tracking_screen.dart';
import 'customer_menu_screen.dart';

class CustomerMainLayout extends StatefulWidget {
  final int initialIndex;

  const CustomerMainLayout({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Cart Tab -> Open Cart directly inside menu or trigger cart sheet
      setState(() => _currentIndex = 0);
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // On Web, render CustomerMenuScreen directly with web navigation & NO bottom nav bar
    if (kIsWeb) {
      return const CustomerMenuScreen();
    }

    // On Mobile Devices / Narrow Screens, render bottom nav bar layout
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const CustomerMenuScreen(),
          const CustomerTrackingScreen(),
          const CustomerMenuScreen(), // Fallback for Cart
          _buildAccountPlaceholder(context),
        ],
      ),
      bottomNavigationBar: CustomerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == 3) {
            _showAccountBottomSheet(context);
            return;
          }
          _onTabTapped(index);
        },
      ),
    );
  }

  Widget _buildAccountPlaceholder(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Account"),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAuthenticated ? Icons.account_circle_rounded : Icons.lock_outline_rounded,
                size: 72,
                color: const Color(0xFFE91E63),
              ),
              const SizedBox(height: 16),
              Text(
                isAuthenticated ? (user.email ?? 'Customer') : 'Guest Account',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isAuthenticated
                    ? 'Manage your orders, profile and preferences'
                    : 'Sign in to save your orders and track live deliveries',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              if (!isAuthenticated)
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text("LOGIN / SIGN UP"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text("LOG OUT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountBottomSheet(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: Color(0xFFE91E63)),
              title: Text(isAuthenticated ? (user.email ?? 'Customer') : 'Guest Account'),
              subtitle: Text(isAuthenticated ? 'Active Customer Profile' : 'Not signed in'),
            ),
            const Divider(),
            if (!isAuthenticated)
              ListTile(
                leading: const Icon(Icons.login_rounded, color: Color(0xFF10B981)),
                title: const Text('Sign In / Register'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.login);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.red),
                title: const Text('Log Out'),
                onTap: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.customerMenu);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
