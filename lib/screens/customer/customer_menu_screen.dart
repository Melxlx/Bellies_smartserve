import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';

import '../../core/app_routes.dart';
import '../../core/responsive_layout.dart';
import '../../core/utils/input_validators.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/order_model.dart';
import '../../models/customer_checkout_draft.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/tracking_repository.dart';
import '../../services/order_tracking_service.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/product_image.dart';


class CustomerMenuScreen extends StatefulWidget {
  const CustomerMenuScreen({super.key});

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();

  final List<OrderItem> _cart = [];
  final _checkoutDraft = CustomerCheckoutDraft();
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  String? _selectedCategoryId;
  String _sortBy = 'popular';
  String _searchQuery = '';
  double? _maxPrice;
  bool _onlyAvailable = false;
  bool _isLoading = true;
  bool _isCartVisible = false; // Add this to control cart visibility
  String _activeNavTab = 'home';

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _categoriesScrollController = ScrollController();
  final Map<String, ScrollController> _laneControllers = {};

  List<Map<String, dynamic>> _testimonials = [
    {
      'name': 'Hallel S.',
      'comment': 'Best Tapsilog in town! Super fast delivery.',
      'stars': 5,
    },
    {
      'name': 'Juan D.',
      'comment': 'Food is always served hot and fresh upon arrival. Great value!',
      'stars': 5,
    },
    {
      'name': 'Maria K.',
      'comment': 'The Korean noodles is a must try! Great service.',
      'stars': 4,
    },
    {
      'name': 'Ana R.',
      'comment': 'Delicious Silog meals and very friendly riders!',
      'stars': 5,
    },
  ];

  // Global Keys for Navigation
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  RealtimeChannel? _productsRealtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _mainScrollController.addListener(_onMainScroll);
    _loadMenu();
    _loadCart();
    _loadTestimonials();
    _checkActiveUserOrders();
    _subscribeToRealtimeMenu();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        _loadCart();
        _checkActiveUserOrders();
      }
    });
  }

  bool _isProgrammaticScrolling = false;

  void _onMainScroll() {
    if (!_mainScrollController.hasClients || _isProgrammaticScrolling) return;
    final offset = _mainScrollController.offset;

    String newTab = 'home';
    if (offset >= 3200) {
      newTab = 'contact';
    } else if (offset >= 1500) {
      newTab = 'about';
    } else if (offset >= 350) {
      newTab = 'menu';
    }

    if (newTab != _activeNavTab) {
      setState(() {
        _activeNavTab = newTab;
      });
    }
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_user_guest');

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        // No user logged in! Cart MUST be empty.
        if (mounted) {
          setState(() {
            _cart.clear();
          });
        }
        return;
      }

      final jsonString = prefs.getString('cart_user_${user.id}');
      if (jsonString != null && mounted) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        setState(() {
          _cart.clear();
          for (var itemJson in decoded) {
            _cart.add(OrderItem.fromJson(itemJson));
          }
        });
      } else if (mounted) {
        setState(() {
          _cart.clear();
        });
      }
    } catch (e) {
      debugPrint("Error loading cart: $e");
    }
  }

  Future<void> _saveCart() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        // Strictly do NOT save a cart when nobody is logged in
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_cart.map((item) => item.toJson()).toList());
      await prefs.setString('cart_user_${user.id}', encoded);
    } catch (e) {
      debugPrint("Error saving cart: $e");
    }
  }

  void _confirmClearCart(VoidCallback onUpdate) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Clear Basket", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Are you sure you want to remove all items from your basket?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart.clear();
              });
              _saveCart();
              onUpdate();
            },
            child: Text("Clear All", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _subscribeToRealtimeMenu() {
    try {
      _productsRealtimeChannel = Supabase.instance.client
          .channel('public:customer:menu_availability')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'products',
            callback: (payload) {
              if (mounted) {
                _loadMenu();
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ingredients',
            callback: (payload) {
              if (mounted) {
                _loadMenu();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error subscribing to realtime menu: $e");
    }
  }

  Future<void> _checkActiveUserOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final orders = await TrackingRepository().getCustomerOrders();
      if (orders.isNotEmpty) {
        final activeOrder = orders.firstWhere(
          (o) => o.status.toLowerCase() != 'completed' && o.status.toLowerCase() != 'cancelled',
          orElse: () => orders.first,
        );
        OrderTrackingService().setTrackingNumber(activeOrder.trackingNumber);
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _mainScrollController.removeListener(_onMainScroll);
    _mainScrollController.dispose();
    _productsRealtimeChannel?.unsubscribe();
    _authSubscription?.cancel();
    _categoriesScrollController.dispose();
    for (var c in _laneControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() => _isLoading = true);
    try {
      final cats = await _categoryRepo.getCategories(activeOnly: true);
      final prods = await _productRepo.getProducts(
        status: ProductStatus.available,
      );

      if (mounted) {
        setState(() {
          _categories = cats;
          _products = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await showErrorDialog(
          context,
          title: 'Unable to Load Menu',
          message: 'The menu could not be loaded. Please try again: $e',
        );
      }
    }
  }

  final Set<String> _addingProductIds = {};

  Future<void> _addToCart(ProductModel product) async {
    if (_addingProductIds.contains(product.id)) return;
    _addingProductIds.add(product.id);
    if (mounted) setState(() {});

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.isAnonymous) {
        if (!mounted) return;
        final bool? loginSuccess = await Navigator.pushNamed<bool>(
          context,
          AppRoutes.login,
          arguments: AppRoutes.customerMenu,
        );
        if (loginSuccess != true) return;
      }

      final isAvailable = await _productRepo.checkStockAvailability(
        product.id,
        1,
      );
      if (!isAvailable) {
        if (mounted) {
          await showErrorDialog(
            context,
            title: 'Item Unavailable',
            message: 'Sorry, this item is currently sold out.',
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        final index = _cart.indexWhere((item) => item.product.id == product.id);
        if (index >= 0) {
          _cart[index].quantity++;
        } else {
          _cart.add(OrderItem(product: product, quantity: 1));
        }
        _isCartVisible = true;
      });
      await _saveCart();
      if (!mounted) return;

      if (ResponsiveLayout.isMobile(context)) {
        _showBasket();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${product.name} added to basket!"),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFE91E63),
        ),
      );
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Unable to Add Item',
          message: 'The item could not be added to your cart: $error',
        );
      }
    } finally {
      _addingProductIds.remove(product.id);
      if (mounted) setState(() {});
    }
  }

  void _showBasket() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildMobileCartPanel(),
    );
  }

  Widget _buildMobileCartPanel() {
    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Your Order Basket",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_cart.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _confirmClearCart(() => setModalState(() {})),
                            tooltip: 'Clear Basket',
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildCartItemList(onUpdate: () => setModalState(() {})),
              ),
              _buildCartSummarySection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItemList({required VoidCallback onUpdate}) {
    if (_cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined,
                size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              "Your basket is empty",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _cart.length,
      separatorBuilder: (_, index) =>
          Divider(color: Colors.grey[100], height: 32),
      itemBuilder: (context, index) {
        final item = _cart[index];
        return Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 70,
                child: ProductImage(
                  path: item.product.imagePath ?? '',
                  productName: item.product.name,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "₱${item.product.sellingPrice.toStringAsFixed(2)}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _quantityBtn(Icons.remove, () {
                  setState(() {
                    if (item.quantity > 1) {
                      item.quantity--;
                    } else {
                      _cart.removeAt(index);
                    }
                    onUpdate();
                  });
                }),
                SizedBox(
                  width: 40,
                  child: Text(
                    "${item.quantity}",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _quantityBtn(
                  Icons.add,
                  () => _increaseCartQuantity(item, onUpdate),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCartSummarySection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Subtotal",
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: Colors.grey[600]),
                ),
                Text(
                  "₱${_total.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _cart.isEmpty
                    ? null
                    : () {
                        if (ResponsiveLayout.isMobile(context)) {
                          Navigator.pop(context);
                        }
                        Navigator.pushNamed(
                          context,
                          AppRoutes.customerCheckout,
                          arguments: CustomerCheckoutArguments(
                            cart: _cart,
                            draft: _checkoutDraft,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "CHECKOUT SECURELY",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFFE91E63)),
      ),
    );
  }

  double get _total => _cart.fold(0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = !ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: Row(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _mainScrollController,
              slivers: [
                _buildAppBar(),
                _buildHeroSection(),
                _buildFeaturesSection(),
                _buildPopularCategories(),
                SliverToBoxAdapter(
                  key: _menuKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMenuSectionTitle(_selectedCategoryId != null ? _categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => CategoryModel(id: '', name: 'Menu', displayOrder: 0, createdAt: DateTime.now())).name.toUpperCase() : "MENU CATEGORIES"),
                    ],
                  ),
                ),
                _isLoading
                    ? const SliverFillRemaining(child: LoadingState())
                    : (_selectedCategoryId == null && _searchQuery.trim().isEmpty && _maxPrice == null && !_onlyAvailable
                        ? _buildCategorizedLanesSliver()
                        : _buildProductGridSliver()),
                _buildDeliveryHappinessSection(),
                _buildTestimonialsSection(),
                _buildFooter(),
              ],
            ),
          ),
          if (isDesktop && _isCartVisible) _buildDesktopCartPanel(),
        ],
      ),
      bottomNavigationBar: (isDesktop || _cart.isEmpty) ? null : _buildCartBar(),
      floatingActionButton: _buildTrackingFab(),
      floatingActionButtonLocation: (isDesktop && _isCartVisible)
          ? FloatingActionButtonLocation.startFloat
          : (_cart.isNotEmpty
              ? FloatingActionButtonLocation.startFloat
              : FloatingActionButtonLocation.endFloat),
    );
  }

  Widget _buildDesktopCartPanel() {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[100]!)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(-5, 0)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: Color(0xFFE91E63)),
                const SizedBox(width: 12),
                Text(
                  "YOUR CART",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (_cart.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                    onPressed: () => _confirmClearCart(() => setState(() {})),
                    tooltip: 'Clear Cart',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                ],
                Text("${_cart.length} items", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: () => setState(() => _isCartVisible = false),
                  tooltip: 'Close Cart',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildCartItemList(onUpdate: () => setState(() {})),
          ),
          _buildCartSummarySection(),
        ],
      ),
    );
  }

  Widget _buildTrackingFab() {
    final activeTrk = OrderTrackingService().lastTrackingNumber;
    if (activeTrk == null) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: () => Navigator.pushNamed(context, AppRoutes.tracking),
      backgroundColor: const Color(0xFFE91E63),
      elevation: 6,
      icon: const Icon(Icons.motorcycle, color: Colors.white),
      label: Text(
        "TRACK ACTIVE ORDER",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final user = Supabase.instance.client.auth.currentUser;
    final isAuthenticated = user != null && !user.isAnonymous;

    return SliverAppBar(
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      centerTitle: false,
      title: Row(
        children: [
          Image.asset('assets/images/Bellieslogo.png', height: 40, errorBuilder: (ctx, err, stack) => const Icon(Icons.restaurant, color: Color(0xFFE91E63))),
          const Spacer(),
          if (!ResponsiveLayout.isMobile(context)) ...[
            _navLink("Home", isActive: _activeNavTab == 'home', onTap: () => _scrollToSection(_homeKey, 'home')),
            _navLink("Menu", isActive: _activeNavTab == 'menu', onTap: () => _scrollToSection(_menuKey, 'menu')),
            _navLink("About", isActive: _activeNavTab == 'about', onTap: () => _scrollToSection(_aboutKey, 'about')),
            _navLink("Contact", isActive: _activeNavTab == 'contact', onTap: () => _scrollToSection(_contactKey, 'contact')),
          ],
        ],
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.black87),
          tooltip: "Search Menu",
          onPressed: _showSearchDialog,
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                _isCartVisible ? Icons.shopping_cart : Icons.shopping_cart_outlined,
                color: _isCartVisible ? const Color(0xFFE91E63) : Colors.black87,
              ),
              onPressed: () {
                if (ResponsiveLayout.isMobile(context)) {
                  _showBasket();
                } else {
                  setState(() => _isCartVisible = !_isCartVisible);
                }
              },
            ),
            if (_cart.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE91E63),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${_cart.length}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        if (isAuthenticated)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.white,
              elevation: 8,
              tooltip: 'Account Menu',
              onSelected: (value) async {
                final messenger = ScaffoldMessenger.of(context);
                if (value == 'profile') {
                  _showCustomerProfileDialog();
                } else if (value == 'tracking') {
                  Navigator.pushNamed(context, AppRoutes.tracking);
                } else if (value == 'logout') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text("Sign Out Account"),
                        ],
                      ),
                      content: const Text("Are you sure you want to sign out of your account?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text("CANCEL"),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("SIGN OUT"),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('cart_user_guest');
                    if (mounted) {
                      setState(() {
                        _cart.clear(); // Clear cart items from memory on sign out
                      });
                    }
                    await Supabase.instance.client.auth.signOut();
                    messenger.showSnackBar(
                      const SnackBar(content: Text("Signed out successfully.")),
                    );
                  }
                }
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE91E63),
                backgroundImage: user.userMetadata?['avatar_url'] != null
                    ? NetworkImage(user.userMetadata!['avatar_url'])
                    : null,
                child: user.userMetadata?['avatar_url'] == null
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              itemBuilder: (context) {
                final currentUser = Supabase.instance.client.auth.currentUser;
                final name = currentUser?.userMetadata?['full_name'] ?? currentUser?.userMetadata?['name'] ?? currentUser?.email ?? 'Customer';
                final email = currentUser?.email ?? '';

                return [
                  PopupMenuItem<String>(
                    enabled: false,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFE91E63),
                          backgroundImage: currentUser?.userMetadata?['avatar_url'] != null ? NetworkImage(currentUser!.userMetadata!['avatar_url']) : null,
                          child: currentUser?.userMetadata?['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(name.toString(), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                              if (email.isNotEmpty)
                                Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline_rounded, color: Color(0xFFE91E63), size: 20),
                        const SizedBox(width: 12),
                        Text("My Profile", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'tracking',
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, color: Color(0xFFE91E63), size: 20),
                        const SizedBox(width: 12),
                        Text("My Order Tracking", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Text("Sign Out", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red)),
                      ],
                    ),
                  ),
                ];
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE91E63)),
              child: Text("Login / Sign Up", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  void _scrollToSection(GlobalKey key, [String? tabName]) {
    if (tabName != null) {
      setState(() {
        _activeNavTab = tabName;
      });
    }
    if (key.currentContext != null) {
      _isProgrammaticScrolling = true;
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      ).then((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _isProgrammaticScrolling = false;
        });
      }).catchError((_) {
        _isProgrammaticScrolling = false;
      });
    }
  }

  Widget _navLink(String label, {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? const Color(0xFFE91E63) : Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showCustomerProfileDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    Map<String, dynamic>? profileData;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        profileData = res;
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }

    final String emailPrefix = user.email?.split('@').first ?? '';

    String getValidName(dynamic primary, dynamic fallback) {
      final p = primary?.toString().trim();
      if (p != null && p.isNotEmpty) return p;
      final f = fallback?.toString().trim();
      if (f != null && f.isNotEmpty) return f;
      return '';
    }

    final String rawFullName = getValidName(
      profileData?['full_name'],
      getValidName(user.userMetadata?['full_name'], user.userMetadata?['name']),
    );

      String fetchedFirstName = getValidName(profileData?['first_name'], user.userMetadata?['first_name']);
    String fetchedMiddleName = getValidName(profileData?['middle_name'], user.userMetadata?['middle_name']);
    String fetchedLastName = getValidName(profileData?['last_name'], user.userMetadata?['last_name']);

    // Discard emailPrefix if set as first_name or last_name
    if (fetchedFirstName == emailPrefix) {
      fetchedFirstName = '';
    }
    if (fetchedLastName == emailPrefix) {
      fetchedLastName = '';
    }

    // Auto-heal/split name if first_name is empty
    if (fetchedFirstName.isEmpty && rawFullName.isNotEmpty && rawFullName != emailPrefix) {
      final parts = rawFullName.replaceAll(RegExp(r'\s+'), ' ').split(' ');
      if (parts.length == 1) {
        fetchedFirstName = parts[0];
      } else if (parts.length == 2) {
        fetchedFirstName = parts[0];
        if (fetchedLastName.isEmpty) fetchedLastName = parts[1];
      } else if (parts.length >= 3) {
        fetchedFirstName = parts[0];
        if (fetchedMiddleName.isEmpty) fetchedMiddleName = parts.sublist(1, parts.length - 1).join(' ');
        if (fetchedLastName.isEmpty) fetchedLastName = parts.last;
      }
    }

    // If first_name is still empty but last_name holds the name (e.g. "Lovely")
    if (fetchedFirstName.isEmpty && fetchedLastName.isNotEmpty) {
      fetchedFirstName = fetchedLastName;
      fetchedLastName = '';
    }

    // Auto-sync healed profile back to Supabase if first_name was missing in DB
    final dbFirstName = profileData?['first_name']?.toString().trim();
    if (fetchedFirstName.isNotEmpty && (dbFirstName == null || dbFirstName.isEmpty)) {
      try {
        final healedUpdates = {
          'first_name': fetchedFirstName,
          if (fetchedMiddleName.isNotEmpty) 'middle_name': fetchedMiddleName,
          if (fetchedLastName.isNotEmpty) 'last_name': fetchedLastName,
          'full_name': [fetchedFirstName, fetchedMiddleName, fetchedLastName].where((s) => s.isNotEmpty).join(' '),
        };
        Supabase.instance.client.from('profiles').update(healedUpdates).eq('id', user.id);
      } catch (_) {}
    }

    final firstNameController = TextEditingController(text: fetchedFirstName);
    final middleNameController = TextEditingController(text: fetchedMiddleName);
    final lastNameController = TextEditingController(text: fetchedLastName);
    final contactController = TextEditingController(
      text: profileData?['contact_number']?.toString() ?? user.userMetadata?['contact_number']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: profileData?['address']?.toString() ?? user.userMetadata?['address']?.toString() ?? '',
    );

    String? avatarUrl = profileData?['avatar_url'] ?? user.userMetadata?['avatar_url'];
    bool isUploadingPhoto = false;
    final picker = ImagePicker();

    Future<void> pickAndUploadPhoto(StateSetter setDialogState) async {
      try {
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          imageQuality: 85,
        );
        if (file == null) return;

        final bytes = await file.readAsBytes();
        final name = file.name.toLowerCase();
        final path = file.path.toLowerCase();

        // 1. Strict format check: ONLY JPEG and PNG accepted
        final isJpgOrPng = name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') ||
                           path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png');

        bool hasValidHeader = false;
        if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
          hasValidHeader = true; // JPEG
        } else if (bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
          hasValidHeader = true; // PNG
        }

        if (!isJpgOrPng || !hasValidHeader) {
          if (mounted) {
            await showErrorDialog(
              context,
              title: 'Invalid File Format',
              message: 'Only JPEG and PNG image files are accepted for profile pictures.',
            );
          }
          return;
        }

        // 2. File size limit (Max 5MB)
        const maxSizeBytes = 5 * 1024 * 1024; // 5 MB
        if (bytes.length > maxSizeBytes) {
          if (mounted) {
            await showErrorDialog(
              context,
              title: 'File Too Large',
              message: 'File size exceeds the 5MB maximum limit. Please choose a smaller image.',
            );
          }
          return;
        }

        setDialogState(() => isUploadingPhoto = true);

        final storagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await Supabase.instance.client.storage
            .from('employee-avatars')
            .uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
            );

        final url = Supabase.instance.client.storage.from('employee-avatars').getPublicUrl(storagePath);

        setDialogState(() {
          avatarUrl = url;
          isUploadingPhoto = false;
        });

        await Supabase.instance.client.from('profiles').update({
          'avatar_url': url,
        }).eq('id', user.id);

      } catch (e) {
        setDialogState(() => isUploadingPhoto = false);
        if (mounted) {
          await showErrorDialog(
            context,
            title: 'Upload Failed',
            message: 'Could not upload profile picture: $e',
          );
        }
      }
    }

    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool isEditing = false;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Color(0xFFE91E63), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? "Edit Customer Profile" : "My Customer Profile",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 18, color: const Color(0xFF1D1D1F)),
                ),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: isEditing
                    ? Form(
                        key: formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Profile Picture Upload
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.2), width: 2),
                                    ),
                                    child: CircleAvatar(
                                      radius: 46,
                                      backgroundColor: const Color(0xFFFCE4EC),
                                      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                                      child: avatarUrl == null || avatarUrl!.isEmpty
                                          ? const Icon(Icons.person, size: 46, color: Color(0xFFE91E63))
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      radius: 17,
                                      backgroundColor: const Color(0xFFE91E63),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: isUploadingPhoto
                                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : const Icon(Icons.camera_alt, size: 15, color: Colors.white),
                                        onPressed: isUploadingPhoto ? null : () => pickAndUploadPhoto(setDialogState),
                                        tooltip: 'Upload Profile Picture',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                "Accepted: JPEG, PNG only (Max 5MB)",
                                style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8E8E93)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Update your profile details below. Live validation active.",
                              style: GoogleFonts.poppins(color: const Color(0xFF8E8E93), fontSize: 12.5),
                            ),
                            const SizedBox(height: 16),
                            
                            // First Name
                            TextFormField(
                              controller: firstNameController,
                              enabled: !isSaving,
                              inputFormatters: InputValidators.nameFormatters,
                              decoration: _inputDecoration(
                                label: "First Name *",
                                icon: Icons.badge_outlined,
                                hint: "e.g. Hallel",
                              ),
                              validator: (v) => InputValidators.validateName(v, fieldName: "First Name"),
                            ),
                            const SizedBox(height: 12),
                            
                            // Middle Name
                            TextFormField(
                              controller: middleNameController,
                              enabled: !isSaving,
                              inputFormatters: InputValidators.nameFormatters,
                              decoration: _inputDecoration(
                                label: "Middle Name (Optional)",
                                icon: Icons.badge_outlined,
                                hint: "Middle Name",
                              ),
                              validator: (v) => InputValidators.validateName(v, fieldName: "Middle Name", isRequired: false),
                            ),
                            const SizedBox(height: 12),
                            
                            // Last Name
                            TextFormField(
                              controller: lastNameController,
                              enabled: !isSaving,
                              inputFormatters: InputValidators.nameFormatters,
                              decoration: _inputDecoration(
                                label: "Last Name *",
                                icon: Icons.badge_outlined,
                                hint: "e.g. Lovely",
                              ),
                              validator: (v) => InputValidators.validateName(v, fieldName: "Last Name"),
                            ),
                            const SizedBox(height: 12),
                            
                            // Contact Number
                            TextFormField(
                              controller: contactController,
                              enabled: !isSaving,
                              keyboardType: TextInputType.phone,
                              inputFormatters: InputValidators.phoneFormatters,
                              decoration: _inputDecoration(
                                label: "Contact Number *",
                                icon: Icons.phone_outlined,
                                hint: "e.g. 09171234567 or +639171234567",
                              ),
                              validator: (v) => InputValidators.validatePhoneNumber(v),
                            ),
                            const SizedBox(height: 12),
                            
                            // Delivery Address
                            TextFormField(
                              controller: addressController,
                              enabled: !isSaving,
                              maxLines: 2,
                              inputFormatters: InputValidators.addressFormatters,
                              decoration: _inputDecoration(
                                label: "Delivery Address *",
                                icon: Icons.location_on_outlined,
                                hint: "Street, Barangay, City, Province",
                              ),
                              validator: (v) => InputValidators.validateAddress(v),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.2), width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFFFCE4EC),
                                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
                                child: avatarUrl == null || avatarUrl!.isEmpty
                                    ? const Icon(Icons.person, size: 46, color: Color(0xFFE91E63))
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // First Name Card
                          _buildProfileViewItem(
                            icon: Icons.badge_outlined,
                            label: "First Name",
                            value: firstNameController.text.trim().isNotEmpty ? firstNameController.text.trim() : "Not provided",
                          ),
                          const SizedBox(height: 10),

                          // Middle Name Card
                          _buildProfileViewItem(
                            icon: Icons.badge_outlined,
                            label: "Middle Name",
                            value: middleNameController.text.trim().isNotEmpty ? middleNameController.text.trim() : "None",
                          ),
                          const SizedBox(height: 10),

                          // Last Name Card
                          _buildProfileViewItem(
                            icon: Icons.badge_outlined,
                            label: "Last Name",
                            value: lastNameController.text.trim().isNotEmpty ? lastNameController.text.trim() : "Not provided",
                          ),
                          const SizedBox(height: 10),

                          // Contact Number Card
                          _buildProfileViewItem(
                            icon: Icons.phone_outlined,
                            label: "Contact Number",
                            value: contactController.text.trim().isNotEmpty ? contactController.text.trim() : "Not provided",
                          ),
                          const SizedBox(height: 10),

                          // Delivery Address Card
                          _buildProfileViewItem(
                            icon: Icons.location_on_outlined,
                            label: "Delivery Address",
                            value: addressController.text.trim().isNotEmpty ? addressController.text.trim() : "Not provided",
                          ),
                        ],
                      ),
              ),
            ),
            actions: isEditing
                ? [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8E8E93),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onPressed: isSaving ? null : () => setDialogState(() => isEditing = false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFFE91E63).withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setDialogState(() => isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final fName = firstNameController.text.trim();
                                final mName = middleNameController.text.trim();
                                final lName = lastNameController.text.trim();
                                final fullName = [fName, mName, lName].where((s) => s.isNotEmpty).join(' ');
                                final contact = contactController.text.trim();
                                final addr = addressController.text.trim();

                                final profileUpdates = <String, dynamic>{
                                  'first_name': fName,
                                  'middle_name': mName.isNotEmpty ? mName : null,
                                  'last_name': lName,
                                  'full_name': fullName,
                                  'contact_number': contact,
                                  'address': addr,
                                  'avatar_url': avatarUrl,
                                  'updated_at': DateTime.now().toIso8601String(),
                                };

                                try {
                                  await Supabase.instance.client.from('profiles').update(profileUpdates).eq('id', user.id);
                                } on PostgrestException catch (pgError) {
                                  debugPrint("Postgrest update warning: ${pgError.message}");
                                  final safeUpdates = Map<String, dynamic>.from(profileUpdates)
                                    ..remove('address')
                                    ..remove('contact_number');
                                  try {
                                    await Supabase.instance.client.from('profiles').update(safeUpdates).eq('id', user.id);
                                  } catch (_) {}
                                }

                                try {
                                  await Supabase.instance.client.auth.updateUser(
                                    UserAttributes(
                                      data: {
                                        'full_name': fullName,
                                        'first_name': fName,
                                        'middle_name': mName,
                                        'last_name': lName,
                                        'contact_number': contact,
                                        'address': addr,
                                        'avatar_url': avatarUrl,
                                      },
                                    ),
                                  );
                                } catch (authErr) {
                                  debugPrint("User metadata sync warning: $authErr");
                                }

                                setDialogState(() {
                                  isSaving = false;
                                  isEditing = false;
                                });
                                messenger.showSnackBar(
                                  const SnackBar(content: Text("Profile updated successfully!")),
                                );
                                setState(() {});
                              } catch (e) {
                                setDialogState(() => isSaving = false);
                                if (!context.mounted) return;
                                await showErrorDialog(
                                  context,
                                  title: 'Update Failed',
                                  message: 'Failed to update profile: $e',
                                );
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text("Save Changes", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ]
                : [
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8E8E93),
                        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFFE91E63).withValues(alpha: 0.3),
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text("Edit Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      onPressed: () => setDialogState(() => isEditing = true),
                    ),
                  ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF8E8E93), size: 20),
      filled: true,
      fillColor: const Color(0xFFF9F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE5E5EA))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF3B30), width: 1.5)),
      labelStyle: GoogleFonts.poppins(color: const Color(0xFF8E8E93), fontSize: 13),
      floatingLabelStyle: GoogleFonts.poppins(color: const Color(0xFFE91E63), fontWeight: FontWeight.w600, fontSize: 13),
      hintStyle: GoogleFonts.poppins(color: const Color(0xFFC7C7CC), fontSize: 13),
      errorStyle: GoogleFonts.poppins(color: const Color(0xFFFF3B30), fontSize: 11),
      counterStyle: GoogleFonts.poppins(color: const Color(0xFF8E8E93), fontSize: 11),
    );
  }

  Widget _buildProfileViewItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final bool isNotProvided = value == "Not provided" || value == "None";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFE91E63), size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isNotProvided ? const Color(0xFFC7C7CC) : const Color(0xFF1D1D1F),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return SliverToBoxAdapter(
      key: _homeKey,
      child: Container(
        height: ResponsiveLayout.isMobile(context) ? 400 : 550,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFFCE4EC), // Soft pink background fallback
          image: DecorationImage(
            image: AssetImage('assets/images/loginpage.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Darkening gradient only on the left side to make text readable
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withAlpha(150),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Taste the",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFD700), // Gold
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    "BELLIE'S\nKITCHEN",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: ResponsiveLayout.isMobile(context) ? 42 : 64,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Text(
                      "Traditional Filipino comfort food, Silog favorites, and authentic Korean noodles served with love.",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _scrollToSection(_menuKey),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          elevation: 8,
                        ),
                        child: Row(
                          children: [
                            Text("ORDER NOW",
                                style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
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
    );
  }

  Widget _buildFeaturesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            _featureCard(Icons.local_shipping_outlined, "FAST & HOT\nDELIVERY", "Always on time"),
            _featureCard(Icons.savings_outlined, "BEST VALUE\nCOMBOS", "Budget friendly"),
            _featureCard(Icons.favorite_border_rounded, "MADE WITH\nPASSION", "Freshly cooked"),
          ],
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String subtitle) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFFE91E63), size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildScrollButtons(ScrollController controller) {
    return Row(
      children: [
        InkWell(
          onTap: () {
            final offset = controller.offset - 300;
            controller.animateTo(
              offset.clamp(0.0, controller.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () {
            final offset = controller.offset + 300;
            controller.animateTo(
              offset.clamp(0.0, controller.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularCategories() {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "POPULAR CATEGORIES",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
                _buildScrollButtons(_categoriesScrollController),
              ],
            ),
          ),
          SizedBox(
            height: 125,
            child: ListView.builder(
              controller: _categoriesScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                final isAll = index == 0;
                final cat = isAll ? null : _categories[index - 1];
                final isSelected = isAll ? _selectedCategoryId == null : _selectedCategoryId == cat?.id;
                
                String imgPath = 'assets/images/Lugaw.png';
                IconData catIcon = Icons.restaurant_menu_rounded;

                if (!isAll && cat != null) {
                  final name = cat.name.toLowerCase();
                  if (name.contains('drink')) {
                    imgPath = 'assets/images/drinks.png';
                    catIcon = Icons.local_drink_rounded;
                  } else if (name.contains('add') || name.contains('on')) {
                    imgPath = 'assets/images/adds-on.png';
                    catIcon = Icons.add_circle_outline_rounded;
                  } else if (name.contains('pancit') || name.contains('bihon') || name.contains('canton')) {
                    imgPath = 'assets/images/bilao_pancit.png';
                    catIcon = Icons.dinner_dining_rounded;
                  } else if (name.contains('silog')) {
                    imgPath = 'assets/images/Tapsilog.png';
                    catIcon = Icons.egg_outlined;
                  } else if (name.contains('student')) {
                    imgPath = 'assets/images/Fried_Siomai_Silog.png';
                    catIcon = Icons.school_rounded;
                  } else if (name.contains('noodle') || name.contains('ramen') || name.contains('korean')) {
                    imgPath = 'assets/images/korean_noodles.png';
                    catIcon = Icons.ramen_dining_rounded;
                  } else if (name.contains('lugaw') || name.contains('goto')) {
                    imgPath = 'assets/images/Lugaw.png';
                    catIcon = Icons.soup_kitchen_rounded;
                  } else if (name.contains('pares') || name.contains('mami')) {
                    imgPath = 'assets/images/pares_rice.png';
                    catIcon = Icons.rice_bowl_rounded;
                  } else {
                    final catProd = _products.firstWhere((p) => p.categoryId == cat.id, orElse: () => _products.first);
                    imgPath = (catProd.imagePath != null && catProd.imagePath!.trim().isNotEmpty)
                        ? catProd.imagePath!
                        : 'assets/images/bilao_pancit.png';
                  }
                } else {
                  imgPath = 'assets/images/allmenu.png';
                  catIcon = Icons.grid_view_rounded;
                }

                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = isAll ? null : cat?.id),
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE91E63) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? const Color(0xFFE91E63) : Colors.grey[200]!),
                      boxShadow: isSelected ? [BoxShadow(color: const Color(0xFFE91E63).withAlpha(50), blurRadius: 8, offset: const Offset(0, 3))] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(catIcon, size: 12, color: isSelected ? Colors.white70 : Colors.grey),
                            const SizedBox(width: 4),
                          ],
                        ),
                        SizedBox(
                          height: 52,
                          child: ProductImage(path: imgPath, productName: cat?.name),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAll ? "All Menu" : (cat?.name ?? ""),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<ProductModel> get _filteredAndSortedProducts {
    var list = _selectedCategoryId == null
        ? List<ProductModel>.from(_products)
        : _products.where((p) => p.categoryId == _selectedCategoryId).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.description?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    if (_maxPrice != null) {
      list = list.where((p) => p.sellingPrice <= _maxPrice!).toList();
    }

    if (_onlyAvailable) {
      list = list.where((p) => p.status == ProductStatus.available).toList();
    }

    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.sellingPrice.compareTo(b.sellingPrice));
        break;
      case 'price_desc':
        list.sort((a, b) => b.sellingPrice.compareTo(a.sellingPrice));
        break;
      case 'name_asc':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'name_desc':
        list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case 'popular':
      default:
        break;
    }

    return list;
  }

  Widget _buildMenuSectionTitle(String title, {bool showFilter = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
          if (showFilter)
            Row(
              children: [
                _buildSortDropdown(),
                const SizedBox(width: 12),
                _iconFilter(Icons.tune_rounded),
              ],
            )
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    final Map<String, String> sortLabels = {
      'popular': 'Sort by: Popular',
      'price_asc': 'Price: Low to High',
      'price_desc': 'Price: High to Low',
      'name_asc': 'Name: A to Z',
      'name_desc': 'Name: Z to A',
    };

    final currentLabel = sortLabels[_sortBy] ?? 'Sort by: Popular';
    final bool isCustomSort = _sortBy != 'popular';

    return PopupMenuButton<String>(
      initialValue: _sortBy,
      onSelected: (value) {
        setState(() {
          _sortBy = value;
        });
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'popular',
          child: Row(
            children: [
              Icon(Icons.star_outline_rounded, size: 18, color: Color(0xFFE91E63)),
              SizedBox(width: 8),
              Text('Popular'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'price_asc',
          child: Row(
            children: [
              Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.green),
              SizedBox(width: 8),
              Text('Price: Low to High'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'price_desc',
          child: Row(
            children: [
              Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.orange),
              SizedBox(width: 8),
              Text('Price: High to Low'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'name_asc',
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: Colors.blue),
              SizedBox(width: 8),
              Text('Name: A to Z'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'name_desc',
          child: Row(
            children: [
              Icon(Icons.sort_by_alpha_rounded, size: 18, color: Colors.purple),
              SizedBox(width: 8),
              Text('Name: Z to A'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isCustomSort ? const Color(0xFFFFF0F5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCustomSort ? const Color(0xFFE91E63) : Colors.grey[200]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCustomSort ? const Color(0xFFE91E63) : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isCustomSort ? const Color(0xFFE91E63) : Colors.black87,
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFilter(IconData icon) {
    final bool isFilterActive = _searchQuery.isNotEmpty || _maxPrice != null || _onlyAvailable;

    return InkWell(
      onTap: _showFilterModal,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isFilterActive ? const Color(0xFFFFF0F5) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFilterActive ? const Color(0xFFE91E63) : Colors.grey[200]!,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isFilterActive ? const Color(0xFFE91E63) : Colors.black87,
        ),
      ),
    );
  }

  void _showSearchDialog() {
    _scrollToSection(_menuKey);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4), // iOS-like subtle dark overlay
      builder: (context) {
        final controller = TextEditingController(text: _searchQuery);
        final focusNode = FocusNode();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = controller.text.trim().isEmpty
                ? _products
                : _products.where((p) {
                    final q = controller.text.trim().toLowerCase();
                    return p.name.toLowerCase().contains(q) ||
                        (p.description?.toLowerCase().contains(q) ?? false);
                  }).toList();

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Container(
                width: 550,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 10))
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Premium Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Search Menu",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D1D1F), // iOS deep dark gray
                              letterSpacing: -0.5,
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF5F5F7),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF86868B), size: 20),
                              onPressed: () => Navigator.pop(context),
                              splashRadius: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Modern iOS Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 44, // iOS standard search bar height
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7), // iOS grouped background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: true,
                          style: GoogleFonts.poppins(fontSize: 16, color: const Color(0xFF1D1D1F)),
                          decoration: InputDecoration(
                            hintText: "Search food, drinks...",
                            hintStyle: GoogleFonts.poppins(color: const Color(0xFF8E8E93), fontSize: 16),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8E8E93), size: 22),
                            suffixIcon: controller.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      controller.clear();
                                      setState(() => _searchQuery = '');
                                      setDialogState(() {});
                                      focusNode.requestFocus();
                                    },
                                    child: const Icon(Icons.cancel, color: Color(0xFF8E8E93), size: 20),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (val) {
                            setState(() => _searchQuery = val);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ),
                    
                    if (controller.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 16, bottom: 8),
                        child: Text(
                          "FOUND ${filtered.length} ITEM${filtered.length == 1 ? '' : 'S'}",
                          style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF86868B), fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        ),
                      )
                    else
                      const SizedBox(height: 16),
                    
                    // Clean Divider
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7)),
                    
                    // Elegant List View
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                      child: filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                                    const SizedBox(height: 16),
                                    Text(
                                      "No dishes found matching\n'${controller.text}'",
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(color: const Color(0xFF86868B), fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const Padding(
                                padding: EdgeInsets.only(left: 80), // Aligned with text
                                child: Divider(height: 12, color: Color(0xFFF2F2F7)),
                              ),
                              itemBuilder: (context, index) {
                                final product = filtered[index];
                                final isOutOfStock = product.status != ProductStatus.available;

                                return InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _scrollToSection(_menuKey);
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Row(
                                      children: [
                                        // Product Image with iOS squircle look
                                        Container(
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14), // Squircle-like
                                            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                                            color: const Color(0xFFF5F5F7),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: ProductImage(
                                            path: product.imagePath ?? '',
                                            productName: product.name,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        
                                        // Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                product.name,
                                                style: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600, 
                                                  fontSize: 15,
                                                  color: const Color(0xFF1D1D1F),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "₱${product.sellingPrice.toStringAsFixed(2)}",
                                                style: GoogleFonts.poppins(
                                                  color: const Color(0xFF86868B), 
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 12),
                                        
                                        // Premium iOS style "Get / Add" button (App Store vibe)
                                        SizedBox(
                                          height: 32,
                                          child: ElevatedButton(
                                            onPressed: isOutOfStock
                                                ? null
                                                : () {
                                                    Navigator.pop(context);
                                                    _addToCart(product);
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isOutOfStock ? const Color(0xFFF2F2F7) : const Color(0xFFFCE4EC), // Soft pink background for iOS vibe
                                              foregroundColor: isOutOfStock ? const Color(0xFFC7C7CC) : const Color(0xFFE91E63), // Pink text
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Pill shape
                                            ),
                                            child: Text(
                                              isOutOfStock ? "SOLD OUT" : "ADD",
                                              style: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w700, 
                                                fontSize: 12,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterModal() {
    final searchController = TextEditingController(text: _searchQuery);
    double tempMaxPrice = _maxPrice ?? 500;
    bool hasMaxPriceFilter = _maxPrice != null;
    bool tempOnlyAvailable = _onlyAvailable;
    String? tempCategoryId = _selectedCategoryId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Filter Menu",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search food or drinks...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  searchController.clear();
                                  setModalState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE91E63)),
                        ),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Category",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text("All"),
                          selected: tempCategoryId == null,
                          selectedColor: const Color(0xFFE91E63),
                          labelStyle: TextStyle(
                            color: tempCategoryId == null ? Colors.white : Colors.black87,
                          ),
                          onSelected: (_) {
                            setModalState(() => tempCategoryId = null);
                          },
                        ),
                        ..._categories.map((cat) => ChoiceChip(
                          label: Text(cat.name),
                          selected: tempCategoryId == cat.id,
                          selectedColor: const Color(0xFFE91E63),
                          labelStyle: TextStyle(
                            color: tempCategoryId == cat.id ? Colors.white : Colors.black87,
                          ),
                          onSelected: (_) {
                            setModalState(() => tempCategoryId = cat.id);
                          },
                        )),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Max Price: ₱${tempMaxPrice.toInt()}",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Switch(
                          value: hasMaxPriceFilter,
                          activeThumbColor: const Color(0xFFE91E63),
                          onChanged: (val) {
                            setModalState(() => hasMaxPriceFilter = val);
                          },
                        ),
                      ],
                    ),
                    if (hasMaxPriceFilter)
                      Slider(
                        value: tempMaxPrice,
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        activeColor: const Color(0xFFE91E63),
                        label: "₱${tempMaxPrice.toInt()}",
                        onChanged: (val) {
                          setModalState(() => tempMaxPrice = val);
                        },
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "In Stock Only",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      activeThumbColor: const Color(0xFFE91E63),
                      value: tempOnlyAvailable,
                      onChanged: (val) {
                        setModalState(() => tempOnlyAvailable = val);
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                                _maxPrice = null;
                                _onlyAvailable = false;
                                _selectedCategoryId = null;
                              });
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Reset All"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _searchQuery = searchController.text;
                                _maxPrice = hasMaxPriceFilter ? tempMaxPrice : null;
                                _onlyAvailable = tempOnlyAvailable;
                                _selectedCategoryId = tempCategoryId;
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text("Apply Filters"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProductGridSliver() {
    final filtered = _filteredAndSortedProducts;

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                "No meals found",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Try adjusting your search or filters.",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedCategoryId = null;
                    _searchQuery = '';
                    _maxPrice = null;
                    _onlyAvailable = false;
                    _sortBy = 'popular';
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text("Reset Filters"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveLayout.isMobile(context) ? 2 : (ResponsiveLayout.isTablet(context) ? 3 : 4),
          crossAxisSpacing: 20,
          mainAxisSpacing: 24,
          childAspectRatio: 0.72,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildProductCard(filtered[index]),
          childCount: filtered.length,
        ),
      ),
    );
  }

  Widget _buildCategorizedLanesSliver() {
    if (_categories.isEmpty || _products.isEmpty) {
      return _buildProductGridSliver();
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final cat = _categories[index];
          final catProducts = _products.where((p) => p.categoryId == cat.id).toList();
          if (catProducts.isEmpty) return const SizedBox.shrink();

          final controller = _laneControllers.putIfAbsent(cat.id, () => ScrollController());

          return Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        cat.name.toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      Row(
                        children: [
                          _buildScrollButtons(controller),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategoryId = cat.id;
                              });
                            },
                            child: const Text("See More >", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 290,
                  child: ListView.builder(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: catProducts.length > 6 ? 6 : catProducts.length,
                    itemBuilder: (context, pIndex) {
                      final product = catProducts[pIndex];
                      return Container(
                        width: 200,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildProductCard(product),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        childCount: _categories.length,
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final isOutOfStock = product.status != ProductStatus.available;
    final isBestSeller = product.name.contains("Tapsilog") || product.name.contains("Korean");

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: ProductImage(
                        path: product.imagePath ?? '',
                        productName: product.name,
                      ),
                    ),
                  ),
                ),
                if (isBestSeller)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text("BEST SELLER", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8)),
                        ],
                      ),
                    ),
                  ),
                if (isOutOfStock)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    alignment: Alignment.center,
                    child: const Text("SOLD OUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  product.description ?? "Freshly prepared meal",
                  style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "₱${product.sellingPrice.toStringAsFixed(0)}",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 16),
                    ),
                    InkWell(
                      onTap: (isOutOfStock || _addingProductIds.contains(product.id)) ? null : () => _addToCart(product),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: (isOutOfStock || _addingProductIds.contains(product.id)) ? Colors.grey[300] : const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_addingProductIds.contains(product.id))
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                              )
                            else ...[
                              Text("Add", style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                              const SizedBox(width: 4),
                              const Icon(Icons.add_rounded, color: Colors.black87, size: 16),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDeliveryHappinessSection() {
    return SliverToBoxAdapter(
      key: _aboutKey,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF2B1A22),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            if (!ResponsiveLayout.isMobile(context))
              Expanded(
                child: Image.asset('assets/images/Bellieslogo.png', height: 180),
              ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("ORDER HAPPINESS", style: GoogleFonts.poppins(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text("WE DELIVER TO YOUR DOOR", style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 24),
                  _happinessItem(Icons.location_searching_rounded, "LIVE TRACKING", "Monitor your Silog in real-time"),
                  _happinessItem(Icons.verified_user_outlined, "SAFE & SECURE", "Hygienic prep & contactless delivery"),
                  _happinessItem(Icons.map_outlined, "WIDE COVERAGE", "We deliver to Pila, Pagsanjan, & Sta. Cruz, Laguna"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _happinessItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFFD700), size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ],
          )
        ],
      ),
    );
  }

  // --- Testimonials & Review Logic ---
  Future<void> _loadTestimonials() async {
    try {
      final response = await Supabase.instance.client
          .from('order_reviews')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      final responseList = response as List;
      if (responseList.isNotEmpty) {
        final loaded = responseList.map((item) {
          return {
            'name': item['customer_name']?.toString() ?? 'Customer',
            'comment': item['comment']?.toString() ?? '',
            'stars': (item['food_rating'] as num?)?.toInt() ?? 5,
          };
        }).toList();

        if (mounted && loaded.isNotEmpty) {
          setState(() {
            _testimonials = [
              ...loaded,
              ..._testimonials.where((t) => !loaded.any((l) => l['comment'] == t['comment'])),
            ];
          });
        }
      }
    } catch (_) {
      // Fallback to initial reviews if DB table doesn't exist yet
    }
  }

  Future<void> _showAddReviewDialog() async {
    final user = Supabase.instance.client.auth.currentUser;
    final nameController = TextEditingController(
      text: user?.userMetadata?['full_name'] as String? ??
          user?.email?.split('@').first ??
          '',
    );
    final commentController = TextEditingController();
    int selectedStars = 5;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.rate_review, color: Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  Text(
                    "Leave a Review",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Your rating:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starVal = index + 1;
                        return IconButton(
                          icon: Icon(
                            starVal <= selectedStars ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 32,
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedStars = starVal;
                                  });
                                },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      enabled: !isSubmitting,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: "Your Name",
                        hintText: "E.g. John D.",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: commentController,
                      enabled: !isSubmitting,
                      maxLength: 50,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Review / Feedback",
                        hintText: "How was your food and overall experience?",
                        helperText: "Min: 5 chars | Max: 50 chars",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.chat_bubble_outline),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final comment = commentController.text.trim();
                          if (name.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Name must be at least 2 characters long.")),
                            );
                            return;
                          }
                          if (comment.length < 5) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Review must be at least 5 characters long.")),
                            );
                            return;
                          }
                          if (comment.length > 50) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Review must not exceed 50 characters.")),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final newRev = {
                            'customer_name': name,
                            'comment': comment,
                            'food_rating': selectedStars,
                            'created_at': DateTime.now().toIso8601String(),
                          };

                          try {
                            await Supabase.instance.client
                                .from('order_reviews')
                                .insert(newRev);
                          } catch (_) {
                            // Fallback to local insertion if DB table missing
                          }

                          if (mounted) {
                            setState(() {
                              _testimonials.insert(0, {
                                'name': name,
                                'comment': comment,
                                'stars': selectedStars,
                              });
                            });
                          }

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text("Thank you so much for your review!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Submit Review"),
                ),
              ],
            );
          },
        );
      },
    );
  }



  Future<void> _launchSocialUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not open link: $urlString")),
          );
        }
      }
    }
  }

  // --- Help & Support Dialogs ---
  void _showFaqsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: Color(0xFFE91E63)),
            const SizedBox(width: 10),
            Text("Frequently Asked Questions (FAQs)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _faqTile("How do I place an order?", "Browse our Menu, tap 'Add to Cart' on your favorite items, and proceed to Checkout to enter your delivery details."),
                _faqTile("What payment options are accepted?", "Currently, GCash is our sole accepted payment option for fast and secure transactions."),
                _faqTile("How long does delivery take?", "Our estimated delivery time is 20 to 40 minutes depending on distance and order volume."),
                _faqTile("What are your operating hours?", "We are open daily from 8:00 AM to 9:00 PM."),
                _faqTile("How can I track my order?", "Go to 'Active Orders' in navigation or use our real-time order tracking feature in the app."),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(answer, style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5)),
          ),
        ],
      ),
    );
  }

  void _showDeliveryInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.local_shipping_outlined, color: Color(0xFFE91E63)),
            const SizedBox(width: 10),
            Text("Delivery Information", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ListTile(
                leading: Icon(Icons.timer_outlined, color: Colors.orange),
                title: Text("Estimated Delivery Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("20 - 40 minutes depending on distance and traffic."),
              ),
              ListTile(
                leading: Icon(Icons.map_outlined, color: Colors.blue),
                title: Text("Coverage Area", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Serving Pila, Pagsanjan, & Sta. Cruz, Laguna."),
              ),
              ListTile(
                leading: Icon(Icons.payments_outlined, color: Colors.green),
                title: Text("Delivery Fee", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Affordable rates starting at ₱30 - ₱50! Free on special promos."),
              ),
              ListTile(
                leading: Icon(Icons.sanitizer_outlined, color: Colors.purple),
                title: Text("Safe & Hygienic", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("Riders use thermal insulated bags to ensure hot and fresh food."),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReturnPolicyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: Color(0xFFE91E63)),
            const SizedBox(width: 10),
            Text("Return & Refund Policy", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("100% Customer Satisfaction Guarantee", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 12),
                Text(
                  "At Bellie's SmartServe, we prioritize meal quality and customer satisfaction. If your order is incomplete, incorrect, or damaged:\n\n"
                  "1. Please notify us within 1 hour of receiving your order.\n"
                  "2. Send a photo or details to our customer support.\n"
                  "3. We will dispatch a free replacement meal or process a full refund via GCash.\n",
                  style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Got it", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.gavel_outlined, color: Color(0xFFE91E63)),
            const SizedBox(width: 10),
            Text("Terms & Conditions", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Bellie’s SmartServe Terms of Service & Store Policies", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFFE91E63))),
                const SizedBox(height: 12),
                
                _termsSectionTitle("1. Acceptance of Terms & Account Integrity"),
                _termsParagraph(
                  "By registering an account, accessing, or placing an order through the Bellie’s SmartServe web and mobile platform, you agree to comply with and be bound by these Terms and Conditions. Users must ensure that all profile information provided—including full name, active Philippine mobile number, and accurate delivery address—is truthful and up to date."
                ),

                _termsSectionTitle("2. Order Placement, Modifications & Cancellation"),
                _termsParagraph(
                  "• Order Finalization: All orders submitted through the app are considered pending until acknowledged by cashiering staff.\n"
                  "• Cancellation Window: Customers may freely cancel an order ONLY BEFORE the kitchen staff begins order preparation. Once the order status changes to 'Preparing' or 'Ready', cancellations and refunds are strictly not permitted.\n"
                  "• Store Rejection: Bellie’s Kitchen reserves the right to decline or cancel an order in cases of ingredient stock unavailability, delivery location outside coverage area, or invalid contact details."
                ),

                _termsSectionTitle("3. Pricing, Delivery Fees & Distance Rates"),
                _termsParagraph(
                  "• Clear Itemization: All meal prices, add-ons, taxes, and calculated delivery fees are displayed prior to order confirmation.\n"
                  "• Delivery Calculation: Delivery fees are dynamically calculated based on road distance (₱50 base rate + distance rate per kilometer). Prices and rates are subject to change without prior notice, but confirmed orders will honor the rate at checkout."
                ),

                _termsSectionTitle("4. Payment Methods & Fraud Prevention"),
                _termsParagraph(
                  "• Cash on Delivery (COD): Customers selecting COD must prepare exact cash or indicate change requirements in the checkout notes.\n"
                  "• Online / GCash Payments: All e-wallet payments require a valid reference number and genuine receipt screenshot. Submitting fake, altered, or reused reference numbers constitutes financial fraud, resulting in immediate order cancellation, account suspension, and blacklisting."
                ),

                _termsSectionTitle("5. Delivery & Customer Responsibilities"),
                _termsParagraph(
                  "• Availability: Customers or designated recipients must be reachable via phone and present at the specified delivery address upon rider arrival.\n"
                  "• Waiting Protocol: Delivery riders will attempt to contact the customer and wait for up to 10 minutes at the location. If unreachable, the order will be marked as 'Failed Delivery', and the customer may remain liable for food and delivery costs."
                ),

                _termsSectionTitle("6. Refunds, Returns & Food Quality Claims"),
                _termsParagraph(
                  "• Inspection: Customers must inspect delivered food items immediately upon receipt.\n"
                  "• Complaints: Any concerns regarding wrong items, missing items, or food quality issues must be reported to Bellie’s SmartServe support within 1 hour of delivery with clear photo evidence.\n"
                  "• Remedies: Valid claims will be remedied via replacement, store credit, or GCash refund within 1–3 business days."
                ),

                _termsSectionTitle("7. Service Revisions & System Rights"),
                _termsParagraph(
                  "Bellie’s SmartServe reserves the right to update these terms, modify operational hours, or discontinue promotional offers at any time to improve service standards."
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _termsSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
      ),
    );
  }

  Widget _termsParagraph(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 12, height: 1.5, color: Colors.black54),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.security_outlined, color: Color(0xFFE91E63)),
            const SizedBox(width: 10),
            Text("Privacy Policy", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("Data Protection & Privacy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                SizedBox(height: 10),
                Text(
                  "Bellie's SmartServe respects and protects your privacy.\n\n"
                  "• Your name, phone number, and address are strictly used to process and deliver your orders.\n"
                  "• We never sell or share your personal data with third parties.\n"
                  "• All transactions and customer data remain secure and protected.",
                  style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.contact_phone_outlined, color: Color(0xFFE91E63)),
            const SizedBox(width: 10),
            Text("Contact Us", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.phone_outlined, color: Color(0xFFE91E63)),
                title: const Text("Hotline / Phone"),
                subtitle: const Text("0928 732 2030"),
                onTap: () => _launchSocialUrl("tel:09287322030"),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined, color: Color(0xFFE91E63)),
                title: const Text("Email"),
                subtitle: const Text("jubileealfonnn@gmail.com"),
                onTap: () => _launchSocialUrl("mailto:jubileealfonnn@gmail.com"),
              ),
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: Color(0xFFE91E63)),
                title: const Text("Address"),
                subtitle: const Text("Pedro Guevara Ave, Santa Cruz, 4009 Laguna"),
              ),
              ListTile(
                leading: const Icon(Icons.access_time_outlined, color: Color(0xFFE91E63)),
                title: const Text("Store Hours"),
                subtitle: const Text("Monday - Sunday: 8:00 AM - 9:00 PM"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close", style: TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- UI Section Builders ---
  Widget _buildTestimonialsSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "WHAT OUR CUSTOMERS SAY",
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddReviewDialog,
                  icon: const Icon(Icons.rate_review, size: 16),
                  label: const Text("Write a Review"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _testimonials.map((t) {
                  return _testimonialCard(
                    t['name'] as String,
                    t['comment'] as String,
                    t['stars'] as int,
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _testimonialCard(String name, String comment, int stars) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE91E63).withAlpha(30),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(color: Color(0xFFE91E63), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "\"$comment\"",
            style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                Icons.star,
                size: 16,
                color: i < stars ? Colors.orange : Colors.grey[300],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return SliverToBoxAdapter(
      key: _contactKey,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E12),
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          children: [
            Wrap(
              spacing: 48,
              runSpacing: 36,
              alignment: WrapAlignment.spaceAround,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: [
                // Brand Column
                SizedBox(
                  width: 270,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Image.asset(
                              'assets/images/Bellieslogo.png',
                              height: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "BELLIE'S",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  "SMARTSERVE",
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFFE91E63),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Kitchen Active & Accepting Orders",
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF34D399),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Freshly cooked meals, traditional Silog, and comfort food delivered directly to your doorstep with speed and warmth.",
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12.5,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _socialPillButton(
                            icon: Icons.facebook,
                            label: "Facebook",
                            url: "https://www.facebook.com/profile.php?id=61591278277020",
                          ),
                          _socialPillButton(
                            icon: Icons.email_outlined,
                            label: "Support",
                            url: "mailto:jubileealfonnn@gmail.com",
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                // Quick Links Column
                _footerColumn("QUICK LINKS", [
                  {'title': "Home", 'icon': Icons.home_outlined, 'onTap': () => _scrollToSection(_homeKey)},
                  {'title': "Menu", 'icon': Icons.restaurant_menu_outlined, 'onTap': () => _scrollToSection(_menuKey)},
                  {'title': "About Us", 'icon': Icons.info_outline_rounded, 'onTap': () => _scrollToSection(_aboutKey)},
                  {'title': "Contact Us", 'icon': Icons.phone_in_talk_outlined, 'onTap': () => _showContactDialog()},
                ]),

                // Help & Support Column
                _footerColumn("HELP & SUPPORT", [
                  {'title': "FAQs", 'icon': Icons.help_outline_rounded, 'onTap': () => _showFaqsDialog()},
                  {'title': "Delivery Info", 'icon': Icons.local_shipping_outlined, 'onTap': () => _showDeliveryInfoDialog()},
                  {'title': "Return Policy", 'icon': Icons.assignment_return_outlined, 'onTap': () => _showReturnPolicyDialog()},
                  {'title': "Terms & Conditions", 'icon': Icons.gavel_outlined, 'onTap': () => _showTermsDialog()},
                  {'title': "Privacy Policy", 'icon': Icons.privacy_tip_outlined, 'onTap': () => _showPrivacyPolicyDialog()},
                ]),

                // Store Info Column
                SizedBox(
                  width: 210,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _footerColumnHeader("STORE INFO"),
                      const SizedBox(height: 16),
                      _footerInfoItem(
                        icon: Icons.access_time_rounded,
                        title: "Opening Hours",
                        subtitle: "Mon - Sun: 8:00 AM - 10:00 PM",
                      ),
                      const SizedBox(height: 14),
                      _footerInfoItem(
                        icon: Icons.location_on_outlined,
                        title: "Service Area",
                        subtitle: "Local Community Delivery",
                      ),
                      const SizedBox(height: 14),
                      _footerInfoItem(
                        icon: Icons.verified_user_outlined,
                        title: "Quality Guarantee",
                        subtitle: "100% Freshly Prepared Food",
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 36),
            Container(
              height: 1,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "© 2026 Bellie's SmartServe • All Rights Reserved.",
                    style: GoogleFonts.poppins(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11.5,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _scrollToSection(_homeKey),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Back to top",
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerColumnHeader(String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3.5,
          height: 13,
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _footerColumn(String title, List<Map<String, dynamic>> items) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _footerColumnHeader(title),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: item['onTap'] as VoidCallback?,
                borderRadius: BorderRadius.circular(8),
                hoverColor: const Color(0xFFE91E63).withValues(alpha: 0.1),
                splashColor: const Color(0xFFE91E63).withValues(alpha: 0.2),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item['icon'] != null) ...[
                        Icon(
                          item['icon'] as IconData,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        item['title'] as String,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _footerInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Icon(
            icon,
            size: 14,
            color: const Color(0xFFE91E63),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _socialPillButton({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return InkWell(
      onTap: () => _launchSocialUrl(url),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _increaseCartQuantity(
    OrderItem item,
    VoidCallback onUpdate,
  ) async {
    try {
      final isAvailable = await _productRepo.checkStockAvailability(
        item.product.id,
        item.quantity + 1,
      );
      if (!isAvailable) {
        if (mounted) {
          await showErrorDialog(
            context,
            title: 'Stock Limit Reached',
            message:
                'There is not enough stock available for ${item.product.name}.',
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() => item.quantity++);
      onUpdate();
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Unable to Check Stock',
          message: 'Could not verify the available stock: $error',
        );
      }
    }
  }

  Widget _buildCartBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE91E63),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withAlpha(100),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_cart.length} ITEMS",
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Text(
                  "₱${_total.toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _showBasket,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE91E63),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Row(
                children: [
                  Text("VIEW BASKET", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
