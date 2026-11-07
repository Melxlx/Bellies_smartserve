import 'package:flutter/material.dart';

import '../screens/auth/splash_screen.dart';
import '../screens/auth/customer_login_screen.dart';
import '../screens/auth/staff_login_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/access_denied_screen.dart';
import '../screens/owner/owner_dashboard.dart';
import '../screens/cashier/cashier_dashboard.dart';
import '../screens/kitchen/kitchen_dashboard.dart';
import '../screens/owner/products_screen.dart';
import '../screens/owner/category_management_screen.dart';
import '../screens/owner/inventory_screen.dart';
import '../screens/owner/payroll_management_screen.dart';
import '../screens/owner/online_orders_screen.dart';
import '../screens/owner/settings_screen.dart';
import '../screens/owner/employee_management_screen.dart';
import '../screens/owner/menu_management_screen.dart';
import '../screens/owner/inventory_hub_screen.dart';
import '../screens/owner/system_info_screen.dart';
import '../screens/owner/customer_reviews_screen.dart';
import '../screens/rider/rider_dashboard_screen.dart';
import '../screens/customer/customer_menu_screen.dart';
import '../screens/customer/customer_checkout_screen.dart';
import '../models/customer_checkout_draft.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../screens/delivery/delivery_list_screen.dart';
import '../screens/delivery/customer_tracking_screen.dart';
import '../screens/attendance/rfid_attendance_screen.dart';
import '../screens/owner/analytics_screen.dart';
import '../screens/owner/activity_logs_screen.dart';
import '../screens/owner/delivery_proofs_screen.dart';
import '../screens/cashier/pos_screen.dart';
import '../screens/cashier/payment_screen.dart';
import '../screens/owner/payment_qr_screen.dart';
import '../screens/owner/owner_profile_screen.dart';
import '../screens/auth/staff_profile_screen.dart';
import '../screens/cashier/receipt_screen.dart';
import '../widgets/customer_guard.dart';
import '../widgets/staff_guard.dart';

class AppRoutes {
  // Public & General
  static const String splash = '/';
  static const String resetPassword = '/reset-password';
  static const String accessDenied = '/access-denied';

  // Customer Routes
  static const String customerMenu = '/menu';
  static const String login = '/customer/login';
  static const String customerLogin = '/customer/login';
  static const String customerRegister = '/customer/register';
  static const String customerAccount = '/customer/account';
  static const String customerOrders = '/customer/orders';
  static const String customerCheckout = '/checkout';
  static const String deliveryAddress = '/checkout/delivery-address';
  static const String tracking = '/tracking';

  // Staff Routes
  static const String staffLogin = '/staff/login';
  static const String staffDashboard = '/staff/dashboard';
  static const String staffPos = '/staff/pos';
  static const String staffOnlineOrders = '/staff/online-orders';
  static const String staffKitchen = '/staff/kitchen';
  static const String staffDeliveries = '/staff/deliveries';
  static const String staffInventory = '/staff/inventory';
  static const String staffEmployees = '/staff/employees';
  static const String staffAttendance = '/staff/attendance';
  static const String staffPayroll = '/staff/payroll';
  static const String staffReports = '/staff/reports';
  static const String staffSettings = '/staff/settings';
  static const String customerReviews = '/staff/reviews';

  // Compatibility / Internal naming aliases (used by existing screens)
  static const String ownerDashboard = staffDashboard;
  static const String cashierDashboard = '/staff/pos-dashboard';
  static const String cashierPos = staffPos;
  static const String cashierOnlineOrders = staffOnlineOrders;
  static const String kitchenDashboard = staffKitchen;
  static const String deliveryMgmt = staffDeliveries;
  static const String inventoryHub = staffInventory;
  static const String employees = staffEmployees;
  static const String attendance = staffAttendance;
  static const String payroll = staffPayroll;
  static const String analytics = staffReports;
  static const String settings = staffSettings;
  static const String categories = '/staff/inventory/categories';
  static const String products = '/staff/inventory/products';
  static const String menuManagement = '/staff/menu-management';
  static const String ingredients = '/staff/inventory/items';
  static const String posOrders = '/staff/pos/orders';
  static const String payment = '/staff/payment';
  static const String receipt = '/staff/receipt';
  static const String kitchenQueue = '/staff/kitchen/queue';
  static const String onlineOrders = '/staff/online-orders-management';
  static const String riderDashboard = '/rider/dashboard';
  static const String systemInfo = '/staff/system-info';
  static const String activityLogs = '/staff/logs';
  static const String deliveryProofs = '/staff/delivery-proofs';
  static const String paymentQrs = '/staff/payment-qrs';
  static const String ownerProfile = '/staff/owner-profile';
  static const String staffProfile = '/staff/staff-profile';

  static ReceiptArguments? receiptArguments(Object? arguments) {
    return arguments is ReceiptArguments ? arguments : null;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    T? getArgs<T>() {
      final args = routeSettings.arguments;
      return args is T ? args : null;
    }

    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: routeSettings);

      case accessDenied:
        return MaterialPageRoute(builder: (_) => const AccessDeniedScreen(), settings: routeSettings);

      // --- CUSTOMER PORTAL ---
      case login:
        final targetRoute = getArgs<String>();
        return MaterialPageRoute<bool>(
          builder: (_) => CustomerLoginScreen(targetRoute: targetRoute),
          settings: routeSettings,
        );

      case customerMenu:
        return MaterialPageRoute(builder: (_) => const CustomerMenuScreen(), settings: routeSettings);

      case customerCheckout:
        final args = routeSettings.arguments;
        if (args is CustomerCheckoutArguments) {
          return _customerRoute(
            CustomerCheckoutScreen(cart: args.cart, draft: args.draft),
            routeSettings,
          );
        } else if (args is List<OrderItem>) {
          return _customerRoute(
            CustomerCheckoutScreen(cart: args, draft: null),
            routeSettings,
          );
        }
        return MaterialPageRoute(builder: (_) => const CustomerMenuScreen(), settings: routeSettings);

      case tracking:
        return _customerRoute(const CustomerTrackingScreen(), routeSettings);

      // --- STAFF PORTAL ---
      case staffLogin:
        return MaterialPageRoute(builder: (_) => const StaffLoginScreen(), settings: routeSettings);

      case staffDashboard:
        return _staffRoute(const OwnerDashboard(), [UserRole.owner], routeSettings);

      case cashierDashboard:
        return _staffRoute(const CashierDashboard(), [UserRole.owner, UserRole.cashier], routeSettings);

      case staffPos:
        return _staffRoute(
          const CashierDashboard(initialSection: CashierSection.pos),
          [UserRole.owner, UserRole.cashier],
          routeSettings,
        );

      case staffOnlineOrders:
        return _staffRoute(
          const CashierDashboard(initialSection: CashierSection.onlineOrders),
          [UserRole.owner, UserRole.cashier],
          routeSettings,
        );

      case staffKitchen:
        return _staffRoute(const KitchenDashboard(), [UserRole.owner, UserRole.kitchen], routeSettings);

      case staffDeliveries:
        return _staffRoute(const DeliveryListScreen(), [UserRole.owner, UserRole.cashier], routeSettings);

      case onlineOrders:
        return _staffRoute(const OnlineOrdersScreen(), [UserRole.owner, UserRole.cashier], routeSettings);

      case staffInventory:
        return _staffRoute(const InventoryHubScreen(), [UserRole.owner], routeSettings);

      case staffEmployees:
        return _staffRoute(const EmployeeManagementScreen(), [UserRole.owner], routeSettings);

      case staffAttendance:
        return _staffRoute(const RFIDAttendanceScreen(), [UserRole.owner, UserRole.cashier], routeSettings);

      case staffPayroll:
        return _staffRoute(const PayrollManagementScreen(), [UserRole.owner], routeSettings);

      case staffReports:
        return _staffRoute(const AnalyticsScreen(), [UserRole.owner], routeSettings);

      case staffSettings:
        return _staffRoute(const SettingsScreen(), [UserRole.owner], routeSettings);

      case customerReviews:
        return _staffRoute(const CustomerReviewsScreen(), [UserRole.owner], routeSettings);

      case riderDashboard:
        return _staffRoute(const RiderDashboardShell(), [UserRole.owner, UserRole.rider], routeSettings);

      case payment:
        final order = getArgs<OrderModel>();
        if (order == null) return _errorRoute("Payment state lost.");
        return _staffRoute(PaymentScreen(order: order), [UserRole.owner, UserRole.cashier], routeSettings);

      case receipt:
        final receiptArgs = receiptArguments(routeSettings.arguments);
        if (receiptArgs != null) {
          final screen = ReceiptScreen(
            order: receiptArgs.order,
            customerOrder: receiptArgs.customerOrder,
          );
          return receiptArgs.customerOrder
              ? _customerRoute(screen, routeSettings)
              : _staffRoute(screen, [UserRole.owner, UserRole.cashier], routeSettings);
        }
        final order = getArgs<OrderModel>();
        if (order == null) return _errorRoute("Receipt data lost.");
        return _staffRoute(ReceiptScreen(order: order), [UserRole.owner, UserRole.cashier], routeSettings);

      case menuManagement:
        return _staffRoute(const MenuManagementScreen(), [UserRole.owner], routeSettings);

      case categories:
        return _staffRoute(const CategoryManagementScreen(), [UserRole.owner], routeSettings);
      case products:
        return _staffRoute(const ProductsScreen(), [UserRole.owner], routeSettings);
      case ingredients:
        return _staffRoute(const InventoryScreen(), [UserRole.owner], routeSettings);
      case posOrders:
        return _staffRoute(
          const CashierDashboard(initialSection: CashierSection.orderHistory),
          [UserRole.owner, UserRole.cashier],
          routeSettings,
        );
      case '/staff/receipts':
        return _staffRoute(
          const CashierDashboard(initialSection: CashierSection.receipts),
          [UserRole.owner, UserRole.cashier],
          routeSettings,
        );
      case '/staff/notifications':
        return _staffRoute(
          const CashierDashboard(initialSection: CashierSection.notifications),
          [UserRole.owner, UserRole.cashier],
          routeSettings,
        );
      case systemInfo:
        return _staffRoute(const SystemInfoScreen(), [UserRole.owner], routeSettings);
      case activityLogs:
        return _staffRoute(const ActivityLogsScreen(), [UserRole.owner], routeSettings);
      case deliveryProofs:
        return _staffRoute(const DeliveryProofsScreen(), [UserRole.owner, UserRole.cashier], routeSettings);
      case paymentQrs:
        return _staffRoute(const PaymentQrScreen(), [UserRole.owner], routeSettings);
      case ownerProfile:
        return _staffRoute(const OwnerProfileScreen(), [UserRole.owner], routeSettings);
      case staffProfile:
        return _staffRoute(const StaffProfileScreen(), [UserRole.cashier, UserRole.kitchen, UserRole.rider, UserRole.owner], routeSettings);

      case resetPassword:
        return MaterialPageRoute(builder: (_) => const ResetPasswordScreen(), settings: routeSettings);

      default:
        // Fallback for direct URL entry or unknown routes
        if (routeSettings.name == '/staff' || routeSettings.name == '/staff/') {
          return MaterialPageRoute(builder: (_) => const StaffLoginScreen(), settings: routeSettings);
        }
        if (routeSettings.name?.startsWith('/customer/login') == true || routeSettings.name?.startsWith('/login') == true) {
             final targetRoute = getArgs<String>();
             return MaterialPageRoute<bool>(
                builder: (_) => CustomerLoginScreen(targetRoute: targetRoute),
                settings: routeSettings,
            );
        }
        if (routeSettings.name?.startsWith('/menu') == true) {
            return MaterialPageRoute(builder: (_) => const CustomerMenuScreen(), settings: routeSettings);
        }

        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: routeSettings);
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text("Navigation Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: Checkbox.width > 0 ? MainAxisAlignment.center : MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed(splash),
                child: const Text("Return to Home"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Route<dynamic> _staffRoute(Widget child, List<UserRole> allowedRoles, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => StaffGuard(allowedRoles: allowedRoles, child: child),
      settings: settings,
    );
  }

  static Route<dynamic> _customerRoute(Widget child, RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => CustomerGuard(child: child),
      settings: settings,
    );
  }
}

class ReceiptArguments {
  final OrderModel order;
  final bool customerOrder;

  const ReceiptArguments({required this.order, this.customerOrder = false});
}


