import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/order_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../services/local_storage_service.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/product_image.dart';
import '../../widgets/app_modals.dart';

enum PosSortOption {
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  priceAsc('Price (Low to High)'),
  priceDesc('Price (High to Low)');

  final String label;
  const PosSortOption(this.label);
}

class PosScreen extends StatefulWidget {
  final bool showAppBar;
  const PosScreen({super.key, this.showAppBar = true});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();
  final _localStorage = LocalStorageService();

  final List<OrderItem> _cart = [];
  bool _isLoading = true;
  String? _error;
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  Map<String, bool> _stockMap = {};
  Timer? _searchDebounce;

  String _searchQuery = '';
  String? _selectedCategoryId;
  ServiceType _selectedServiceType = ServiceType.dineIn;
  PosSortOption _sortOption = PosSortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Show cached data instantly if available
    final cachedProds = _localStorage.getCachedProducts();
    final cachedCats = _localStorage.getCachedCategories();
    if (cachedProds != null && cachedProds.isNotEmpty && _products.isEmpty) {
      setState(() {
        _products = cachedProds;
        _categories = cachedCats ?? [];
        _stockMap = _localStorage.getCachedStockMap();
        _isLoading = false;
      });
    } else if (_products.isEmpty) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final categories = await _categoryRepo.getCategories();
      _localStorage.cacheCategories(categories);

      final products = await _productRepo.getProducts(
        status: ProductStatus.available,
      );

      final stockMap = await _productRepo.getBatchStockAvailability(
        products.map((p) => p.id).toList(),
      );

      if (mounted) {
        setState(() {
          _categories = categories;
          _products = products;
          _stockMap = stockMap;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_products.isEmpty) {
            _error = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  List<ProductModel> get _filteredAndSortedProducts {
    final query = _searchQuery.trim().toLowerCase();

    final filtered = _products.where((product) {
      // 1. Filter by category
      if (_selectedCategoryId != null && _selectedCategoryId != 'All') {
        final matchesCatId = product.categoryId == _selectedCategoryId;
        final matchesCatObjId = product.category?.id == _selectedCategoryId;
        final matchesCatName =
            product.category?.name.trim().toLowerCase() == _selectedCategoryId?.toLowerCase() ||
            product.categoryId.trim().toLowerCase() == _selectedCategoryId?.toLowerCase();

        if (!matchesCatId && !matchesCatObjId && !matchesCatName) {
          return false;
        }
      }

      // 2. Filter by search query
      if (query.isNotEmpty) {
        final nameMatch = product.name.toLowerCase().contains(query);
        final skuMatch = product.sku.toLowerCase().contains(query);
        final codeMatch = product.productCode.toLowerCase().contains(query);
        if (!nameMatch && !skuMatch && !codeMatch) {
          return false;
        }
      }

      return true;
    }).toList();

    // 3. Sorting
    switch (_sortOption) {
      case PosSortOption.nameAsc:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case PosSortOption.nameDesc:
        filtered.sort((a, b) => b.name.compareTo(a.name));
        break;
      case PosSortOption.priceAsc:
        filtered.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
        break;
      case PosSortOption.priceDesc:
        filtered.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
        break;
    }

    return filtered;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  double get _subtotal => _cart.fold(0, (sum, item) => sum + item.total);
  double get _total => _subtotal;

  void _runFlyToCartAnimation(BuildContext buttonContext, ProductModel product) {
    try {
      final RenderBox? renderBox = buttonContext.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      final startOffset = renderBox.localToGlobal(Offset.zero);
      final screenSize = MediaQuery.of(context).size;
      final endOffset = Offset(screenSize.width - 60, 80);

      OverlayEntry? overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (context) => _FlyingItemOverlay(
          startOffset: startOffset,
          endOffset: endOffset,
          productName: product.name,
          productImage: product.imagePath ?? '',
          onComplete: () {
            overlayEntry?.remove();
          },
        ),
      );

      Overlay.of(context).insert(overlayEntry);
    } catch (_) {}
  }

  void _addToCart(ProductModel product, [BuildContext? buttonContext]) {
    if (product.status != ProductStatus.available) {
      AppModals.showError(
        context,
        title: "Out of Stock",
        message: "${product.name} is currently Out of Stock.",
      );
      return;
    }

    if (buttonContext != null) {
      _runFlyToCartAnimation(buttonContext, product);
    }

    setState(() {
      final existingIndex = _cart.indexWhere(
        (item) => item.product.id == product.id,
      );
      if (existingIndex >= 0) {
        _cart[existingIndex].quantity++;
      } else {
        _cart.add(OrderItem(product: product, quantity: 1));
      }
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Added ${product.name} to cart",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2E9E6B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _updateQuantity(int index, int delta) {
    FocusScope.of(context).unfocus();
    setState(() {
      _cart[index].quantity += delta;
      if (_cart[index].quantity <= 0) {
        _cart.removeAt(index);
      }
    });
  }

  void _removeItem(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _addInstructions(int index) {
    final controller = TextEditingController(text: _cart[index].instructions);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Special Instructions", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLength: 100,
          decoration: InputDecoration(
            hintText: "e.g. No onions, extra spicy",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cart[index].instructions = controller.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63)),
            child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _processPayment() async {
    if (_cart.isEmpty) {
      AppModals.showError(
        context,
        title: "Cart Empty",
        message: "Please add products to your cart before proceeding to checkout.",
      );
      return;
    }

    setState(() => _isLoading = true);

    List<String> unavailableItems = [];
    for (var item in _cart) {
      final isAvailable = await _productRepo.checkStockAvailability(
        item.product.id,
        item.quantity,
      );
      if (!isAvailable) {
        unavailableItems.add(item.product.name);
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (unavailableItems.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text("Out of Stock"),
            ],
          ),
          content: Text(
            "The following items are out of stock: \n\n${unavailableItems.join(", ")}\n\nPlease revise the order.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("REVISE ORDER"),
            ),
          ],
        ),
      );
      return;
    }

    final tempOrder = OrderModel(
      id: "TEMP",
      queueNumber: "000",
      trackingNumber:
          "TRK-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}",
      items: List.from(_cart),
      timestamp: DateTime.now(),
      subtotal: _subtotal,
      deliveryFee: 0.0,
      totalAmount: _total,
      serviceType: _selectedServiceType,
      customerDetails: null,
    );

    await Navigator.pushNamed(context, AppRoutes.payment, arguments: tempOrder);
    if (mounted) {
      setState(() => _cart.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _isLoading && _products.isEmpty
        ? const LoadingState()
        : _error != null && _products.isEmpty
        ? ErrorState(error: _error!, onRetry: _loadData)
        : ResponsiveLayout(
            mobile: _buildMobileLayout(),
            desktop: _buildDesktopLayout(),
          );

    if (!widget.showAppBar) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: bodyContent,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.ownerDashboard);
            }
          },
        ),
        title: Text("Bellie's POS Terminal", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: bodyContent,
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildProductSection()),
        Container(
          height: 100,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Items: ${_cart.length}", style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    "Total: ₱${_total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFFE91E63),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => _showCartBottomSheet(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
                child: const Text("VIEW CART"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildProductSection()),
        const VerticalDivider(width: 1, color: Colors.black12),
        Container(width: 450, color: Colors.white, child: _buildCartPanel()),
      ],
    );
  }

  Widget _buildProductSection() {
    final displayProducts = _filteredAndSortedProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Search, Sort & Header Bar
        Container(
          padding: const EdgeInsets.all(20.0),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Search menu items...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PosSortOption>(
                    value: _sortOption,
                    icon: const Icon(Icons.sort_rounded, color: Color(0xFFE91E63)),
                    onChanged: (opt) {
                      if (opt != null) setState(() => _sortOption = opt);
                    },
                    items: PosSortOption.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 13))))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Horizontal Category Tabs
        Container(
          height: 55,
          color: Colors.white,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildCategoryTab('All', null),
              ..._categories.map((c) => _buildCategoryTab(c.name, c.id)),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.black12),
        // Product Grid
        Expanded(
          child: displayProducts.isEmpty
              ? const EmptyState(message: "No products available.")
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 235,
                  ),
                  itemCount: displayProducts.length,
                  itemBuilder: (context, index) => _buildProductItem(
                    displayProducts[index],
                    key: ValueKey(displayProducts[index].id),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(String name, String? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ChoiceChip(
        label: Text(name),
        selected: isSelected,
        selectedColor: const Color(0xFFE91E63),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
        backgroundColor: Colors.grey[100],
        onSelected: (selected) {
          setState(() => _selectedCategoryId = categoryId);
        },
      ),
    );
  }

  Widget _buildProductItem(ProductModel product, {Key? key}) {
    final isAvailable = _stockMap[product.id] ?? true;

    return Stack(
      key: key,
      children: [
        Opacity(
          opacity: isAvailable ? 1 : 0.6,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 125,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: ProductImage(
                      path: product.imagePath ?? '',
                      productName: product.name,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "₱${product.sellingPrice.toStringAsFixed(2)}",
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFE91E63),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Builder(
                            builder: (btnContext) => SizedBox(
                              height: 32,
                              child: ElevatedButton(
                                onPressed: isAvailable ? () => _addToCart(product, btnContext) : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE91E63),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  isAvailable ? "ADD" : "OUT",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isAvailable)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withAlpha((0.9 * 255).toInt()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "OUT OF STOCK",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCartPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Order Header Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Current Order",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.withAlpha(15),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  if (_cart.isEmpty) return;
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text("Clear Current Order"),
                      content: const Text("Are you sure you want to remove all items from this order?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("CANCEL"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          onPressed: () {
                            Navigator.pop(ctx);
                            FocusScope.of(context).unfocus();
                            setState(() => _cart.clear());
                          },
                          child: const Text("CLEAR ALL"),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text("Clear", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        // Cart Items List
        Expanded(
          child: _cart.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text("No items added yet", style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Container(
                      key: ValueKey('${item.product.id}_$index'),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: ProductImage(
                                path: item.product.imagePath ?? '',
                                productName: item.product.name,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.product.name,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "₱${item.product.sellingPrice.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Color(0xFFE91E63),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item.instructions != null && item.instructions!.isNotEmpty)
                                  Text(
                                    "Note: ${item.instructions}",
                                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.note_add_outlined, size: 18, color: Colors.grey),
                                tooltip: "Special Note",
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _addInstructions(index),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _updateQuantity(index, -1),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.remove, size: 16),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              InkWell(
                                onTap: () => _updateQuantity(index, 1),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.add, size: 16),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                tooltip: "Remove Item",
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                onPressed: () => _removeItem(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Order Summary & Checkout Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<ServiceType>(
                initialValue: _selectedServiceType,
                decoration: InputDecoration(
                  labelText: "Service Type",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [ServiceType.dineIn, ServiceType.takeout]
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedServiceType = value!),
              ),
              const SizedBox(height: 16),
              _summaryRow("Subtotal", "₱${_subtotal.toStringAsFixed(2)}"),
              const Divider(height: 24),
              _summaryRow(
                "Total",
                "₱${_total.toStringAsFixed(2)}",
                isTotal: true,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    "PROCEED TO PAYMENT",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Colors.black87 : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTotal ? 20 : 14,
              color: isTotal ? const Color(0xFFE91E63) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollController) => Column(
              children: [
                Expanded(child: _buildCartPanel()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FlyingItemOverlay extends StatefulWidget {
  final Offset startOffset;
  final Offset endOffset;
  final String productName;
  final String productImage;
  final VoidCallback onComplete;

  const _FlyingItemOverlay({
    required this.startOffset,
    required this.endOffset,
    required this.productName,
    required this.productImage,
    required this.onComplete,
  });

  @override
  State<_FlyingItemOverlay> createState() => _FlyingItemOverlayState();
}

class _FlyingItemOverlayState extends State<_FlyingItemOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animation = Tween<Offset>(
      begin: widget.startOffset,
      end: widget.endOffset,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _animation.value;
        final scale = _scaleAnimation.value;

        return Positioned(
          left: offset.dx,
          top: offset.dy,
          child: Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE91E63), width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ProductImage(
                    path: widget.productImage,
                    productName: widget.productName,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
