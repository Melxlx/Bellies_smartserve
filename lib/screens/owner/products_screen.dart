import 'package:flutter/material.dart';
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

    return Column(
      children: [
        Expanded(
          child: ResponsiveLayout(
            mobile: widget.isGridView ? _buildGrid(2) : _buildTable(),
            tablet: widget.isGridView ? _buildGrid(3) : _buildTable(),
            desktop: widget.isGridView ? _buildGrid(5) : _buildTable(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
          child: PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            totalItems: _products.length,
            itemsPerPage: _itemsPerPage,
            onPageChanged: (page) => setState(() => _currentPage = page),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(int crossAxisCount) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.65,
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
          Container(
            height: 120,
            width: double.infinity,
            color: const Color(0xFFFAFAFA),
            child: Center(
              child: SizedBox(
                height: 100,
                width: 100,
                child: ProductImage(
                  path: product.imagePath ?? '',
                  productName: product.name,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(product.category?.name ?? "No Category", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Text("₱${product.sellingPrice.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFC2416C), fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statusChip(product.status),
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
  final _skuController = TextEditingController();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  String? _selectedCategoryId;
  ProductStatus _status = ProductStatus.available;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _skuController.text = widget.product!.sku;
      _nameController.text = widget.product!.name;
      _descController.text = widget.product!.description ?? '';
      _priceController.text = widget.product!.sellingPrice.toString();
      _costController.text = widget.product!.estimatedCost.toString();
      _selectedCategoryId = widget.product!.categoryId;
      _status = widget.product!.status;
    }
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
        sku: _skuController.text.trim(),
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        sellingPrice: double.parse(_priceController.text),
        estimatedCost: double.parse(_costController.text),
        categoryId: _selectedCategoryId!,
        status: _status,
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
    final skuChanged = _skuController.text.trim() != p.sku;
    final nameChanged = _nameController.text.trim() != p.name;
    final descChanged = _descController.text.trim() != (p.description ?? '');
    final priceChanged = double.tryParse(_priceController.text) != p.sellingPrice;
    final costChanged = double.tryParse(_costController.text) != p.estimatedCost;
    final catChanged = _selectedCategoryId != p.categoryId;
    final statusChanged = _status != p.status;

    return skuChanged || nameChanged || descChanged || priceChanged || costChanged || catChanged || statusChanged;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? "Add Product" : "Edit Product"),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _skuController,
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: "SKU", border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: "Product Name", border: OutlineInputBorder()),
                validator: (val) {
                  if (val == null || val.isEmpty) return "Required";
                  if (val.length < 2 || val.length > 100) return "Must be 2-100 chars";
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
                items: widget.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                onChanged: _isSaving ? null : (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                maxLines: 2,
                maxLength: 500,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: "Price (₱)", border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n <= 0 || n > 1000000) return "Invalid";
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: "Cost (₱)", border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        final n = double.tryParse(val ?? '');
                        if (n == null || n < 0) return "Invalid";
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProductStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: "Status", border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: ProductStatus.available, child: Text("Available")),
                  const DropdownMenuItem(value: ProductStatus.unavailable, child: Text("Unavailable")),
                ],
                onChanged: (val) => setState(() => _status = val!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: (_isSaving || !_hasChanges) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2416C),
            foregroundColor: Colors.white,
          ),
          child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SAVE PRODUCT"),
        ),
      ],
    );
  }
}
