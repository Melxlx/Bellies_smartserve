import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/responsive_layout.dart';
import '../../models/ingredient_model.dart';
import '../../models/inventory_movement_model.dart';
import '../../repositories/ingredient_repository.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/pagination_bar.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _ingredientRepo = IngredientRepository();
  final _searchController = TextEditingController();

  List<IngredientModel> _ingredients = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String _categoryFilter = 'All';
  String _statusFilter = 'All';
  int _currentPage = 1;
  int _itemsPerPage = 10;
  String? _error;

  static String _formatStockQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toStringAsFixed(1);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _ingredientRepo.getIngredients(
        category: _categoryFilter,
      );
      if (mounted) {
        setState(() {
          _ingredients = list;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<IngredientModel> get _filteredIngredients {
    final query = _searchController.text.trim().toLowerCase();
    return _ingredients.where((i) {
      if (query.isNotEmpty) {
        final nameMatch = i.name.toLowerCase().contains(query);
        final codeMatch = i.code.toLowerCase().contains(query);
        if (!nameMatch && !codeMatch) return false;
      }
      if (_statusFilter == 'Good' && i.status != InventoryStatus.available) return false;
      if (_statusFilter == 'Low Stock' && i.status != InventoryStatus.lowStock) return false;
      if (_statusFilter == 'Out of Stock' && i.status != InventoryStatus.outOfStock) return false;
      return true;
    }).toList();
  }

  int get _totalItems => _ingredients.length;
  int get _lowStockCount => _ingredients.where((i) => i.status == InventoryStatus.lowStock).length;
  int get _outOfStockCount => _ingredients.where((i) => i.status == InventoryStatus.outOfStock).length;

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete Selected Items?"),
          ],
        ),
        content: Text(
          "Are you sure you want to delete $count selected inventory item(s)? This action cannot be undone.",
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text("DELETE ($count)"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _ingredientRepo.deleteIngredients(_selectedIds.toList());
      setState(() => _selectedIds.clear());
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$count inventory item(s) deleted successfully."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting items: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showIngredientDialog({IngredientModel? ingredient}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => IngredientDialog(
        ingredient: ingredient,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _recordStockMovement(IngredientModel ingredient, bool initialIsStockIn) async {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    MovementType selectedType = initialIsStockIn ? MovementType.stockIn : MovementType.stockOut;
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Record Stock Movement",
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${ingredient.code} - ${ingredient.name}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFFC2416C)),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<MovementType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Movement Type',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: MovementType.stockIn, child: Text('Stock In (+)')),
                    DropdownMenuItem(value: MovementType.stockOut, child: Text('Stock Out (-)')),
                    DropdownMenuItem(value: MovementType.wastage, child: Text('Wastage (-)')),
                    DropdownMenuItem(value: MovementType.damaged, child: Text('Damaged (-)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedType = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: qtyController,
                  decoration: InputDecoration(
                    labelText: 'Quantity (${ingredient.unit.name.toLowerCase()})',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    final qty = double.tryParse(value ?? '');
                    if (qty == null || qty <= 0) {
                      return 'Enter a quantity greater than zero';
                    }
                    if (selectedType != MovementType.stockIn && qty > ingredient.currentQuantity) {
                      return 'Cannot deduct more than current stock (${_formatStockQuantity(ingredient.currentQuantity)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: 'Reason / Notes (Optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedType == MovementType.stockIn ? Colors.green : Colors.orange,
              ),
              child: const Text('SAVE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      final change = double.parse(qtyController.text);
      final reason = reasonController.text.trim().isEmpty ? null : reasonController.text.trim();

      await _ingredientRepo.recordIngredientMovement(
        ingredientId: ingredient.id,
        movementType: selectedType,
        quantity: change,
        reason: reason,
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Stock movement recorded successfully."), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Unable to Record Stock',
          message: error.toString(),
        );
      }
    } finally {
      qtyController.dispose();
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LoadingState();
    if (_error != null) return ErrorState(error: _error!, onRetry: _loadData);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopMetricCards(),
          const SizedBox(height: 16),
          _buildOverviewSection(),
        ],
      ),
    );
  }

  Widget _buildTopMetricCards() {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    if (!isDesktop) {
      return Column(
        children: [
          _metricCard(
            title: "Total Items",
            value: "$_totalItems",
            icon: Icons.inventory_2_rounded,
            gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
            badgeText: "Active Stock",
            badgeColor: const Color(0xFF10B981),
          ),
          const SizedBox(height: 10),
          _metricCard(
            title: "Low Stock Items",
            value: "$_lowStockCount",
            icon: Icons.warning_amber_rounded,
            gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            badgeText: "Action Needed",
            badgeColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),
          _metricCard(
            title: "Out of Stock",
            value: "$_outOfStockCount",
            icon: Icons.remove_shopping_cart_rounded,
            gradientColors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            badgeText: "Critical",
            badgeColor: const Color(0xFFEF4444),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _metricCard(
            title: "Total Items",
            value: "$_totalItems",
            icon: Icons.inventory_2_rounded,
            gradientColors: [const Color(0xFF10B981), const Color(0xFF059669)],
            badgeText: "Active Stock",
            badgeColor: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _metricCard(
            title: "Low Stock Items",
            value: "$_lowStockCount",
            icon: Icons.warning_amber_rounded,
            gradientColors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            badgeText: "Action Needed",
            badgeColor: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _metricCard(
            title: "Out of Stock",
            value: "$_outOfStockCount",
            icon: Icons.remove_shopping_cart_rounded,
            gradientColors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            badgeText: "Critical",
            badgeColor: const Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    final filtered = _filteredIngredients;
    final totalItems = filtered.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    final paginatedList = filtered.isEmpty ? <IngredientModel>[] : filtered.sublist(start, end > totalItems ? totalItems : end);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar Responsive Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 850;

              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Stock Inventory List",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    "Manage raw ingredients, stock levels and unit costs",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              );

              final searchField = SizedBox(
                width: isNarrow ? double.infinity : 200,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: "Search ingredient...",
                    hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade500),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _currentPage = 1);
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE91E63)),
                    ),
                  ),
                  onChanged: (_) => setState(() {
                    _currentPage = 1;
                  }),
                ),
              );

              final categoryDropdown = SizedBox(
                width: isNarrow ? 140 : 150,
                height: 38,
                child: DropdownButtonFormField<String>(
                  initialValue: _categoryFilter,
                  isDense: true,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Categories', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Grains', child: Text('Grains (Rice)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Meat', child: Text('Meat (Beef/Pork)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Poultry', child: Text('Poultry & Eggs', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Noodles', child: Text('Noodles', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Oil & Fats', child: Text('Oil & Fats', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Seasoning', child: Text('Seasonings', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _categoryFilter = val ?? 'All';
                      _currentPage = 1;
                    });
                    _loadData();
                  },
                ),
              );

              final filterButton = SizedBox(
                height: 38,
                child: PopupMenuButton<String>(
                  initialValue: _statusFilter,
                  onSelected: (val) => setState(() {
                    _statusFilter = val;
                    _currentPage = 1;
                  }),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'All', child: Text('All Status', style: TextStyle(fontSize: 12))),
                    PopupMenuItem(value: 'Good', child: Text('Good Stock', style: TextStyle(fontSize: 12))),
                    PopupMenuItem(value: 'Low Stock', child: Text('Low Stock', style: TextStyle(fontSize: 12))),
                    PopupMenuItem(value: 'Out of Stock', child: Text('Out of Stock', style: TextStyle(fontSize: 12))),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _statusFilter != 'All' ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _statusFilter != 'All' ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          size: 15,
                          color: _statusFilter != 'All' ? const Color(0xFF10B981) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _statusFilter == 'All' ? 'Filter' : _statusFilter,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusFilter != 'All' ? const Color(0xFF047857) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final actionButtons = Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (_selectedIds.isNotEmpty)
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        onPressed: _confirmDeleteSelected,
                        icon: const Icon(Icons.delete_outline_rounded, size: 15),
                        label: Text("Delete (${_selectedIds.length})", style: GoogleFonts.poppins(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () => _showIngredientDialog(),
                      icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      label: Text(
                        "Add Ingredient",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                    ),
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: titleWidget),
                        actionButtons,
                      ],
                    ),
                    const SizedBox(height: 10),
                    searchField,
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: categoryDropdown),
                        const SizedBox(width: 8),
                        filterButton,
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  titleWidget,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        searchField,
                        categoryDropdown,
                        filterButton,
                        actionButtons,
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text("No raw ingredients found matching filters.")),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowHeight: 38,
                      dataRowMinHeight: 46,
                      dataRowMaxHeight: 50,
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      dividerThickness: 0.8,
                      columns: [
                        DataColumn(label: Text('Ingredient Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                        DataColumn(label: Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                        DataColumn(label: Text('Quantity', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                        DataColumn(label: Text('Unit Cost', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                        DataColumn(label: Text('Last Updated', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                        DataColumn(label: Text('Status', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                        DataColumn(label: Text('Action', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 11.5, color: const Color(0xFF475569)))),
                      ],
                      rows: paginatedList.map((ingredient) {
                        final isSelected = _selectedIds.contains(ingredient.id);
                        final lastUpdatedStr = DateFormat('MMM dd, yyyy, HH:mm').format(ingredient.lastUpdated ?? DateTime.now());

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(ingredient.id);
                              } else {
                                _selectedIds.remove(ingredient.id);
                              }
                            });
                          },
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(ingredient.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                  Text(ingredient.code, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  ingredient.category,
                                  style: TextStyle(color: Colors.grey[800], fontSize: 10.5, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${_formatStockQuantity(ingredient.currentQuantity)} ${ingredient.unit.name.toLowerCase()}',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                            ),
                            DataCell(
                              Text(
                                '₱${ingredient.averageUnitCost.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.grey[800], fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                lastUpdatedStr,
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                            ),
                            DataCell(_statusPill(ingredient.status)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: "Stock In (+)",
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _recordStockMovement(ingredient, true),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                        ),
                                        child: const Icon(Icons.add_rounded, color: Color(0xFF047857), size: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: "Stock Out (-)",
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _recordStockMovement(ingredient, false),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFFBEB),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                                        ),
                                        child: const Icon(Icons.remove_rounded, color: Color(0xFFB45309), size: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Tooltip(
                                    message: "Edit Details",
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => _showIngredientDialog(ingredient: ingredient),
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: const Icon(Icons.edit_rounded, color: Color(0xFF475569), size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            PaginationBar(
              currentPage: _currentPage,
              totalPages: totalPages,
              totalItems: totalItems,
              itemsPerPage: _itemsPerPage,
              onPageChanged: (page) => setState(() => _currentPage = page),
              onRowsPerPageChanged: (val) => setState(() {
                _itemsPerPage = val;
                _currentPage = 1;
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPill(InventoryStatus status) {
    Color bg = const Color(0xFFECFDF5);
    Color fg = const Color(0xFF047857);
    Color dot = const Color(0xFF10B981);
    String label = "Good";

    switch (status) {
      case InventoryStatus.available:
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF047857);
        dot = const Color(0xFF10B981);
        label = "Good";
        break;
      case InventoryStatus.lowStock:
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFFB45309);
        dot = const Color(0xFFF59E0B);
        label = "Low Stock";
        break;
      case InventoryStatus.outOfStock:
      case InventoryStatus.expiringSoon:
        bg = const Color(0xFFFEF2F2);
        fg = const Color(0xFFB91C1C);
        dot = const Color(0xFFEF4444);
        label = status == InventoryStatus.outOfStock ? "Out of Stock" : "Expiring Soon";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class IngredientDialog extends StatefulWidget {
  final IngredientModel? ingredient;
  final VoidCallback onSaved;

  const IngredientDialog({
    super.key,
    required this.ingredient,
    required this.onSaved,
  });

  @override
  State<IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<IngredientDialog> {
  static const List<String> _ingredientCategories = [
    'Grains',
    'Meat',
    'Poultry',
    'Noodles',
    'Oil & Fats',
    'Seasoning',
    'Vegetables',
    'Beverages',
    'Packaging',
    'General',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _customCategoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _reorderController;
  late final TextEditingController _costController;
  late String _selectedCategory;
  IngredientUnit _unit = IngredientUnit.kilogram;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.ingredient;
    _codeController = TextEditingController(text: item?.code ?? 'ING-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    _nameController = TextEditingController(text: item?.name ?? '');

    final cat = item?.category ?? 'Grains';
    if (_ingredientCategories.contains(cat)) {
      _selectedCategory = cat;
      _customCategoryController = TextEditingController(text: '');
    } else {
      _selectedCategory = 'Other';
      _customCategoryController = TextEditingController(text: cat);
    }

    _quantityController = TextEditingController(text: item?.currentQuantity.toString() ?? '0');
    _reorderController = TextEditingController(text: item?.reorderLevel.toString() ?? '10');
    _costController = TextEditingController(text: item?.averageUnitCost.toString() ?? '0');
    _unit = item?.unit ?? IngredientUnit.kilogram;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _customCategoryController.dispose();
    _quantityController.dispose();
    _reorderController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final finalCategory = _selectedCategory == 'Other'
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    try {
      final payload = {
        'code': _codeController.text.trim(),
        'name': _nameController.text.trim(),
        'category': finalCategory.isEmpty ? 'General' : finalCategory,
        'unit': _unit.name,
        'current_quantity': double.tryParse(_quantityController.text.trim()) ?? 0.0,
        'reorder_level': double.tryParse(_reorderController.text.trim()) ?? 10.0,
        'average_unit_cost': double.tryParse(_costController.text.trim()) ?? 0.0,
      };

      await IngredientRepository().saveIngredient(payload, id: widget.ingredient?.id);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.ingredient == null ? 'Add Ingredient' : 'Edit Ingredient',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: 'Ingredient Name (e.g., Rice Grains, Beef Tapa) *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Ingredient name is required';
                    if (v.trim().length < 2) return 'Must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _ingredientCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: _saving ? null : (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
                if (_selectedCategory == 'Other') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customCategoryController,
                    enabled: !_saving,
                    decoration: InputDecoration(
                      labelText: 'Custom Category Name *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) {
                      if (_selectedCategory == 'Other' && (v == null || v.trim().isEmpty)) {
                        return 'Please enter category name';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: 'Current Stock *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val < 0) return 'Enter valid stock (>= 0)';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<IngredientUnit>(
                        initialValue: _unit,
                        decoration: InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: IngredientUnit.values
                            .map((u) => DropdownMenuItem(value: u, child: Text(u.name.toUpperCase())))
                            .toList(),
                        onChanged: _saving ? null : (v) => setState(() => _unit = v ?? IngredientUnit.kilogram),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _reorderController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: 'Reorder Level *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final val = double.tryParse(v ?? '');
                          if (val == null || val < 0) return 'Enter valid level (>= 0)';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _costController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: 'Unit Cost (₱)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final val = double.tryParse(v);
                          if (val == null || val < 0) return 'Enter valid cost (>= 0)';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008080),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('SAVE INGREDIENT'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
