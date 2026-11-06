import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/product_model.dart';
import '../../models/ingredient_model.dart';
import '../../models/recipe_model.dart';
import '../../repositories/ingredient_repository.dart';
import '../../repositories/recipe_repository.dart';
import '../../widgets/state_widgets.dart';

class RecipeManagementDialog extends StatefulWidget {
  final ProductModel product;

  const RecipeManagementDialog({
    super.key,
    required this.product,
  });

  @override
  State<RecipeManagementDialog> createState() => _RecipeManagementDialogState();
}

class _RecipeManagementDialogState extends State<RecipeManagementDialog> {
  final _recipeRepo = RecipeRepository();
  final _ingredientRepo = IngredientRepository();

  List<IngredientModel> _availableIngredients = [];
  List<RecipeItemModel> _initialRecipeItems = [];
  List<RecipeItemModel> _recipeItems = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedIngredientId;
  String _searchQuery = '';
  final _qtyController = TextEditingController(text: '1.0');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final ingredients = await _ingredientRepo.getIngredients();
      
      // Categorize and sort alphabetically by category, then by name
      ingredients.sort((a, b) {
        final catCmp = a.category.toLowerCase().compareTo(b.category.toLowerCase());
        if (catCmp != 0) return catCmp;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      final recipe = await _recipeRepo.getRecipeForProduct(widget.product.id);

      if (mounted) {
        setState(() {
          _availableIngredients = ingredients;
          _initialRecipeItems = recipe.map((item) => item.copyWith()).toList();
          _recipeItems = recipe.map((item) => item.copyWith()).toList();
          final filtered = _filteredIngredients;
          if (filtered.isNotEmpty) {
            _selectedIngredientId = filtered.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<IngredientModel> get _filteredIngredients {
    if (_searchQuery.isEmpty) {
      return _availableIngredients;
    }
    final q = _searchQuery.toLowerCase();
    return _availableIngredients.where((ing) =>
      ing.name.toLowerCase().contains(q) ||
      ing.category.toLowerCase().contains(q) ||
      ing.code.toLowerCase().contains(q)
    ).toList();
  }

  bool get _hasChanges {
    if (_recipeItems.length != _initialRecipeItems.length) return true;
    
    final currentMap = {for (var item in _recipeItems) item.ingredientId: item.quantityRequired};
    final initialMap = {for (var item in _initialRecipeItems) item.ingredientId: item.quantityRequired};

    if (currentMap.length != initialMap.length) return true;

    for (final entry in currentMap.entries) {
      if (!initialMap.containsKey(entry.key)) return true;
      if (initialMap[entry.key] != entry.value) return true;
    }

    return false;
  }

  void _addIngredientToRecipe() {
    if (_selectedIngredientId == null) return;
    final selectedIng = _availableIngredients.firstWhere(
      (ing) => ing.id == _selectedIngredientId,
      orElse: () => _availableIngredients.first,
    );
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid quantity greater than zero")),
      );
      return;
    }

    final existingIdx = _recipeItems.indexWhere(
      (item) => item.ingredientId == selectedIng.id,
    );

    if (existingIdx >= 0) {
      // Update existing ingredient quantity
      final existing = _recipeItems[existingIdx];
      setState(() {
        _recipeItems[existingIdx] = existing.copyWith(
          quantityRequired: existing.quantityRequired + qty,
        );
      });
    } else {
      // Add new ingredient item
      setState(() {
        _recipeItems.add(
          RecipeItemModel(
            id: '',
            productId: widget.product.id,
            ingredientId: selectedIng.id,
            ingredientName: selectedIng.name,
            ingredientCode: selectedIng.code,
            unit: selectedIng.unit.name.toUpperCase(),
            quantityRequired: qty,
          ),
        );
      });
    }
  }

  Future<void> _removeIngredient(int index) async {
    final item = _recipeItems[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Ingredient"),
        content: Text("Are you sure you want to remove '${item.ingredientName}' from this recipe?"),
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
            child: const Text("REMOVE"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _recipeItems.removeAt(index);
      });
    }
  }

  Future<void> _saveRecipe() async {
    setState(() => _isSaving = true);
    try {
      await _recipeRepo.saveRecipeForProduct(widget.product.id, _recipeItems);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Recipe for ${widget.product.name} saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving recipe: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredIngredients = _filteredIngredients;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC2416C).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFFC2416C), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Set Recipe & Ingredients",
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.product.name,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 24),

            if (_isLoading)
              const SizedBox(height: 200, child: LoadingState())
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Add Ingredient Input Section
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Add Ingredient to Recipe",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                            ),
                            const SizedBox(height: 10),
                            // Search Bar
                            TextField(
                              enabled: !_isSaving,
                              decoration: InputDecoration(
                                hintText: "Search ingredient name or category...",
                                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            // Dropdown
                            DropdownButtonFormField<String>(
                              key: ValueKey(_selectedIngredientId),
                              initialValue: filteredIngredients.any((i) => i.id == _selectedIngredientId)
                                  ? _selectedIngredientId
                                  : (filteredIngredients.isNotEmpty ? filteredIngredients.first.id : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: "Select Ingredient",
                                labelStyle: const TextStyle(fontSize: 13),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                              ),
                              items: filteredIngredients
                                  .map((ing) => DropdownMenuItem<String>(
                                        value: ing.id,
                                        child: Text(
                                          "${ing.category} • ${ing.name} (${ing.unit.name.toUpperCase()})",
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: _isSaving ? null : (val) {
                                if (val != null) setState(() => _selectedIngredientId = val);
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _qtyController,
                                    enabled: !_isSaving,
                                    decoration: InputDecoration(
                                      labelText: "Quantity Required",
                                      labelStyle: const TextStyle(fontSize: 13),
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: filteredIngredients.isEmpty ? null : _addIngredientToRecipe,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFC2416C),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text("Add", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current Recipe List Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Recipe Ingredients (${_recipeItems.length})",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                          ),
                          if (_recipeItems.isNotEmpty)
                            Text(
                              "Scroll to view all",
                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Recipe Items List
                      _recipeItems.isEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              alignment: Alignment.center,
                              child: Text(
                                "No ingredients set for this product yet.\nAdd ingredients using the form above.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[500], fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recipeItems.length,
                              itemBuilder: (context, index) {
                                final item = _recipeItems[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFFC2416C).withAlpha(20),
                                      child: const Icon(Icons.kitchen, color: Color(0xFFC2416C), size: 18),
                                    ),
                                    title: Text(item.ingredientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text("Per serving: ${item.quantityRequired} ${item.unit}", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                      onPressed: () => _removeIngredient(index),
                                      tooltip: "Remove Ingredient",
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (!_hasChanges || _isSaving) ? null : _saveRecipe,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 18),
                  label: const Text("SAVE RECIPE", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008080),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
