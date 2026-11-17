import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/customer_bottom_nav_bar.dart';
import '../delivery/customer_tracking_screen.dart';
import 'customer_account_screen.dart';
import 'customer_menu_screen.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../core/app_routes.dart';
import '../../core/theme/app_colors.dart';

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
  int _cartCount = 0;
  bool _isCheckingRole = true;
  final GlobalKey<State<CustomerMenuScreen>> _menuScreenKey = GlobalKey<State<CustomerMenuScreen>>();
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _checkStaffRole();
  }

  Future<void> _checkStaffRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      try {
        final profile = await _authService.ensureProfileExists(user: user, isCustomerPortal: true);
        if (profile.role != UserRole.customer && profile.role != UserRole.guest) {
          if (!mounted) return;
          String route = AppRoutes.staffLogin;
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
            default:
              route = AppRoutes.staffLogin;
              break;
          }
          Navigator.pushReplacementNamed(context, route);
          return;
        }
      } catch (e) {
        debugPrint("CustomerMainLayout role check error: $e");
      }
    }
    if (mounted) {
      setState(() => _isCheckingRole = false);
    }
  }

  void _onCartCountChanged(int count) {
    if (mounted && _cartCount != count) {
      setState(() => _cartCount = count);
    }
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      // Cart Tab -> Trigger Order Basket Sheet directly
      setState(() => _currentIndex = 0);
      dynamic state = _menuScreenKey.currentState;
      if (state != null) {
        try {
          state.showBasket();
        } catch (_) {}
      }
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFDFD),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    // On Web OR before login (Guest / Visitor Mode):
    // Render CustomerMenuScreen (Landing Page with Hero section & Login/Sign Up)
    if (kIsWeb || !isAuthenticated) {
      return CustomerMenuScreen(
        key: _menuScreenKey,
        onCartCountChanged: _onCartCountChanged,
      );
    }

    // On Mobile Devices / Narrow Screens, render bottom nav bar layout with 4 tabs
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: IndexedStack(
        index: _currentIndex >= 4 ? 0 : _currentIndex,
        children: [
          CustomerMenuScreen(
            key: _menuScreenKey,
            onAccountTabRequested: () => setState(() => _currentIndex = 3),
            onCartCountChanged: _onCartCountChanged,
          ),
          const CustomerTrackingScreen(),
          const SizedBox.shrink(), // Index 2 is Cart (triggers showBasket sheet)
          const CustomerAccountScreen(),
        ],
      ),
      bottomNavigationBar: CustomerBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        cartItemCount: _cartCount,
      ),
    );
  }
}
