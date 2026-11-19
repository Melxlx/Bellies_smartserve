import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/category_repository.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/product_image.dart';
import '../../widgets/pagination_bar.dart';
import '../../core/responsive_layout.dart';
import 'recipe_management_dialog.dart';

class ProductsScreen extends StatefulWidget {
  final bool isGridView;
  const ProductsScreen({super.key, this.isGridView = true});

  @override
  State<ProductsScreen> createState() => ProductsScreenState();
}

class ProductsScreenState extends State<ProductsScreen> {
  final _productRepo = ProductRepository();
  final _categoryRepo = CategoryRepository();

  bool _isLoading = true;
  String? _error;
  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  
  String _searchQuery = '';
  String? _selectedCategoryId;
  ProductStatus? _statusFilter;
  bool _isOwner = false;

  int _currentPage = 1;
  final int _itemsPerPage = 12;

  int get _totalPages => (_products.length / _itemsPerPage).ceil();
  List<ProductModel> get _paginatedProducts {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (start >= _products.length) return [];
    return _products.sublist(start, end > _products.length ? _products.length : end);
  }

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadData();
  }

  Future<void> _checkRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      if (mounted) {
        setState(() {
          _isOwner = response['role'] == 'OWNER';
        });
      }
    }
  }

  void refreshData() => _loadData();

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final categories = await _categoryRepo.getCategories(activeOnly: false);
      final products = await _productRepo.getProducts(
        searchQuery: _searchQuery,
        categoryId: _selectedCategoryId,
        status: _statusFilter,
      );
      if (mounted) {
        setState(() {
          _categories = categories;
          _products = products;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void showProductForm({ProductModel? product}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductFormDialog(
        product: product,
        categories: _categories.where((c) => c.isActive).toList(),
        onSave: () => _loadData(),
      ),
    );
  }

  void _archiveProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Archive Product"),
        content: Text("Are you sure you want to archive '${product.name}'? It will no longer be visible in the menu."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("ARCHIVE"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _productRepo.updateStatus(product.id, ProductStatus.archived);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: "Search by name or SKU...",
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _loadData();
                  },
                ),
              ),
              if (_isOwner) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => showProductForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("ADD PRODUCT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC2416C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 1,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId ?? 'All',
                  decoration: const InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'All', child: Text("All Categories")),
                    ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedCategoryId = val == 'All' ? null : val);
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ProductStatus?>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: "Status",
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text("All Statuses")),
                    const DropdownMenuItem(value: ProductStatus.available, child: Text("Available")),
                    const DropdownMenuItem(value: ProductStatus.unavailable, child: Text("Unavailable")),
                  ],
                  onChanged: (val) {
                    setState(() => _statusFilter = val);
                    _loadData();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingState();
    if (_error != null) return ErrorState(error: _error!, onRetry: _loadData);
    if (_products.isEmpty) return const EmptyState(message: "No products found.");

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveLayout(
            mobile: widget.isGridView ? _buildGrid(2) : _buildTable(),
            tablet: widget.isGridView ? _buildGrid(3) : _buildTable(),
            desktop: widget.isGridView ? _buildGrid(5) : _buildTable(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: PaginationBar(
              currentPage: _currentPage,
              totalPages: _totalPages,
              totalItems: _products.length,
              itemsPerPage: _itemsPerPage,
              onPageChanged: (page) => setState(() => _currentPage = page),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(int crossAxisCount) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _paginatedProducts.length,
      itemBuilder: (context, index) => _buildCard(_paginatedProducts[index]),
    );
  }

  void _openRecipeDialog(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => RecipeManagementDialog(product: product),
    );
  }

  Widget _buildCard(ProductModel product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              color: const Color(0xFFFAFAFA),
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 0.82,
                  heightFactor: 0.82,
                  child: ProductImage(
                    path: product.imagePath ?? '',
                    productName: product.name,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(product.category?.name ?? "No Category", style: const TextStyle(color: Colors.grey, fontSize: 11.5)),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("₱${product.sellingPrice.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFC2416C), fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          _statusChip(product.status),
                        ],
                      ),
                      if (_isOwner)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            if (value == 'recipe') _openRecipeDialog(product);
                            if (value == 'edit') showProductForm(product: product);
                            if (value == 'archive') _archiveProduct(product);
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'recipe',
                              child: Row(children: [Icon(Icons.kitchen_outlined, size: 18, color: Color(0xFFC2416C)), SizedBox(width: 8), Text('Recipe')]),
                            ),
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Colors.blue), SizedBox(width: 8), Text('Edit')]),
                            ),
                            const PopupMenuItem(
                              value: 'archive',
                              child: Row(children: [Icon(Icons.archive_outlined, size: 18, color: Colors.red), SizedBox(width: 8), Text('Archive')]),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('SKU')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _paginatedProducts.map((product) => DataRow(cells: [
                DataCell(Text(product.sku)),
                DataCell(Text(product.name)),
                DataCell(Text(product.category?.name ?? 'N/A')),
                DataCell(Text("₱${product.sellingPrice.toStringAsFixed(2)}")),
                DataCell(_statusChip(product.status)),
                DataCell(Row(
                  children: [
                    IconButton(icon: const Icon(Icons.visibility_outlined), onPressed: () => _showProductDetails(product)),
                    if (_isOwner) ...[
                      IconButton(
                        icon: const Icon(Icons.kitchen_outlined, color: Color(0xFFC2416C)),
                        tooltip: "Set Recipe / Ingredients",
                        onPressed: () => _openRecipeDialog(product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        tooltip: "Edit Product",
                        onPressed: () => showProductForm(product: product),
                      ),
                      IconButton(
                        icon: const Icon(Icons.archive_outlined, color: Colors.red),
                        tooltip: "Archive Product",
                        onPressed: () => _archiveProduct(product),
                      ),
                    ],
                  ],
                )),
              ])).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(ProductStatus status) {
    Color color = status == ProductStatus.available ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(100))),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  void _showProductDetails(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("SKU: ${product.sku}"),
            Text("Category: ${product.category?.name}"),
            Text("Price: ₱${product.sellingPrice}"),
            const SizedBox(height: 8),
            const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
            Text(product.description ?? "No description"),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))],
      ),
    );
  }
}

class ProductFormDialog extends StatefulWidget {
  final ProductModel? product;
  final List<CategoryModel> categories;
  final VoidCallback onSave;

  const ProductFormDialog({super.key, this.product, required this.categories, required this.onSave});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  String? _selectedCategoryId;
  ProductStatus _status = ProductStatus.available;
  bool _isSaving = false;
  String? _imagePath;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.sellingPrice.toString();
      _costController.text = widget.product!.estimatedCost.toString();
      _selectedCategoryId = widget.product!.categoryId;
      _status = widget.product!.status;
      _imagePath = widget.product!.imagePath;
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final mime = file.mimeType?.toLowerCase() ?? '';

    // Validate image format: JPG, JPEG, PNG only
    final allowedExts = ['.jpg', '.jpeg', '.png'];
    final hasValidExt = allowedExts.any((ext) => name.endsWith(ext) || path.endsWith(ext));
    final hasValidMime = mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/jpg';

    if (!hasValidExt && !hasValidMime) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid file type! Only image files (JPG, PNG) are allowed."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final fileExt = name.split('.').last;
      final uploadPath = 'products/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await Supabase.instance.client.storage
          .from('employee-avatars')
          .uploadBinary(
            uploadPath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );

      final url = Supabase.instance.client.storage
          .from('employee-avatars')
          .getPublicUrl(uploadPath);

      if (mounted) {
        setState(() {
          _imagePath = url;
          _isUploadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImagePickerModal() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final presetImages = [
            'https://images.unsplash.com/photo-1544025162-d76694265947?w=300&auto=format&fit=crop&q=80',
            'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=300&auto=format&fit=crop&q=80',
            'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=300&auto=format&fit=crop&q=80',
            'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=300&auto=format&fit=crop&q=80',
            'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=300&auto=format&fit=crop&q=80',
            'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop&q=80',
          ];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFFFF1F5), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.photo_library_rounded, color: Color(0xFFE91E63), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text("Select Product Image", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Choose from preset food gallery:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: presetImages.length,
                      itemBuilder: (context, index) {
                        final imgUrl = presetImages[index];
                        final isSelected = _imagePath == imgUrl;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _imagePath = imgUrl);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade300,
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.network(imgUrl, fit: BoxFit.cover),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _pickAndUploadImage();
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text("Upload Custom Image from PC"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Category is required")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ProductRepository();
      final product = ProductModel(
        id: widget.product?.id ?? '',
        sku: widget.product?.sku ?? 'PRD-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        sellingPrice: double.parse(_priceController.text),
        estimatedCost: double.parse(_costController.text),
        categoryId: _selectedCategoryId!,
        status: _status,
        imagePath: _imagePath,
        createdAt: widget.product?.createdAt ?? DateTime.now(),
      );
      await repo.saveProduct(product);
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _hasChanges {
    if (widget.product == null) {
      return _nameController.text.trim().isNotEmpty && _priceController.text.trim().isNotEmpty;
    }
    final p = widget.product!;
    final nameChanged = _nameController.text.trim() != p.name;
    final descChanged = _descController.text.trim() != (p.description ?? '');
    final priceChanged = double.tryParse(_priceController.text) != p.sellingPrice;
    final costChanged = double.tryParse(_costController.text) != p.estimatedCost;
    final catChanged = _selectedCategoryId != p.categoryId;
    final statusChanged = _status != p.status;
    final imageChanged = _imagePath != p.imagePath;

    return nameChanged || descChanged || priceChanged || costChanged || catChanged || statusChanged || imageChanged;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFE91E63), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                widget.product == null ? "Add New Product" : "Edit Product Details",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1E293B)),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product Image Picker (Professional Upload Card)
                Center(
                  child: GestureDetector(
                    onTap: _isSaving || _isUploadingImage ? null : _showImagePickerModal,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isUploadingImage
                            ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE91E63)))
                            : (_imagePath != null && _imagePath!.isNotEmpty
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.network(
                                        _imagePath!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          color: Colors.black.withValues(alpha: 0.6),
                                          child: const Text(
                                            "Change",
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFF1F5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.add_a_photo_rounded, color: Color(0xFFE91E63), size: 24),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Add Photo",
                                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  )),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Product Name
                TextFormField(
                  controller: _nameController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Product Name *",
                    hintText: "e.g. Special Pork Sisig",
                    prefixIcon: const Icon(Icons.fastfood_outlined, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Product name is required";
                    if (val.length < 2 || val.length > 100) return "Must be 2-100 characters";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: "Category *",
                    prefixIcon: const Icon(Icons.category_outlined, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                    ),
                  ),
                  items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: _isSaving ? null : (val) => setState(() => _selectedCategoryId = val),
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Description (Optional)",
                    hintText: "Brief summary of ingredients or serving size",
                    prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                    ),
                  ),
                  maxLines: 2,
                  maxLength: 500,
                ),
                const SizedBox(height: 8),

                // Price & Cost Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        enabled: !_isSaving,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: "Selling Price (₱) *",
                          prefixText: "₱ ",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          final n = double.tryParse(val ?? '');
                          if (n == null || n <= 0 || n > 1000000) return "Invalid price";
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        enabled: !_isSaving,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: "Estimated Cost (₱)",
                          prefixText: "₱ ",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          final n = double.tryParse(val ?? '');
                          if (n == null || n < 0) return "Invalid cost";
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Status Dropdown
                DropdownButtonFormField<ProductStatus>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText: "Availability Status",
                    prefixIcon: const Icon(Icons.toggle_on_outlined, color: Color(0xFF64748B)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE91E63), width: 1.8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: ProductStatus.available, child: Text("Available")),
                    DropdownMenuItem(value: ProductStatus.unavailable, child: Text("Unavailable")),
                  ],
                  onChanged: (val) => setState(() => _status = val!),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF64748B),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          onPressed: (_isSaving || !_hasChanges) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(widget.product == null ? "SAVE PRODUCT" : "UPDATE CHANGES", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
