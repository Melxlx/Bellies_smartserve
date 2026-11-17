import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/customer_bottom_nav_bar.dart';
import '../delivery/customer_tracking_screen.dart';
import 'customer_account_screen.dart';
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
  int _cartCount = 0;
  final GlobalKey<State<CustomerMenuScreen>> _menuScreenKey = GlobalKey<State<CustomerMenuScreen>>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    // On Web OR before login (Guest / Visitor Mode):
    // Render CustomerMenuScreen (Landing Page with Hero section & Login/Sign Up)
    if (kIsWeb || !isAuthenticated) {
      return const CustomerMenuScreen();
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
