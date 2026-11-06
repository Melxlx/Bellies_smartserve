import 'package:flutter/material.dart';
import '../../core/app_routes.dart';
import 'products_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final GlobalKey<ProductsScreenState> _productsKey = GlobalKey<ProductsScreenState>();
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu Management"),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            tooltip: "Switch View",
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: "Manage Categories",
            onPressed: () => Navigator.pushNamed(context, AppRoutes.categories),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _productsKey.currentState?.refreshData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ProductsScreen(
        key: _productsKey,
        isGridView: _isGridView,
      ),
    );
  }
}
