import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/ingredient_model.dart';
import '../../repositories/ingredient_repository.dart';
import '../../widgets/state_widgets.dart';

class IngredientManagementScreen extends StatefulWidget {
  const IngredientManagementScreen({super.key});

  @override
  State<IngredientManagementScreen> createState() =>
      _IngredientManagementScreenState();
}

class _IngredientManagementScreenState
    extends State<IngredientManagementScreen> {
  final _repository = IngredientRepository();
  List<IngredientModel> _ingredients = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final bool _isOwner = true; // Assume owner or check permissions

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _repository.getIngredients(searchQuery: _searchQuery);
      if (mounted) {
        setState(() {
          _ingredients = items;
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

  void _showIngredientForm({IngredientModel? ingredient}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IngredientFormDialog(
        ingredient: ingredient,
        onSave: _loadIngredients,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIngredients,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: "Search stock items...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
                _loadIngredients();
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _showIngredientForm(),
              icon: const Icon(Icons.add),
              label: const Text("Add Stock Item"),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState();
    }
    if (_error != null) {
      return ErrorState(error: _error!, onRetry: _loadIngredients);
    }
    if (_ingredients.isEmpty) {
      return const EmptyState(message: "No stock items found.");
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _ingredients.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _ingredients[index];
        return Card(
          child: ListTile(
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${item.category} • ${item.currentQuantity} ${item.unit.name.toUpperCase()}",
            ),
            trailing: _isOwner
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showIngredientForm(ingredient: item),
                      ),
                      Switch(
                        value: item.isActive,
                        onChanged: (val) async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await _repository.toggleActive(item.id, val);
                            if (mounted) _loadIngredients();
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(content: Text("Error: ${e.toString()}")),
                            );
                          }
                        },
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}

class IngredientFormDialog extends StatefulWidget {
  final IngredientModel? ingredient;
  final VoidCallback onSave;

  const IngredientFormDialog({
    super.key,
    this.ingredient,
    required this.onSave,
  });

  @override
  State<IngredientFormDialog> createState() => _IngredientFormDialogState();
}

class _IngredientFormDialogState extends State<IngredientFormDialog> {
  static const List<String> _categories = [
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
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _catController = TextEditingController();
  final _reorderController = TextEditingController();
  String _selectedCategory = 'Grains';
  IngredientUnit _unit = IngredientUnit.piece;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.ingredient != null) {
      _codeController.text = widget.ingredient!.code;
      _nameController.text = widget.ingredient!.name;
      final cat = widget.ingredient!.category;
      if (_categories.contains(cat)) {
        _selectedCategory = cat;
      } else {
        _selectedCategory = 'Other';
        _catController.text = cat;
      }
      _reorderController.text = widget.ingredient!.reorderLevel.toString();
      _unit = widget.ingredient!.unit;
    }

    _codeController.addListener(_onFieldChanged);
    _nameController.addListener(_onFieldChanged);
    _catController.addListener(_onFieldChanged);
    _reorderController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _catController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool get _isFormValid {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();

    if (widget.ingredient == null) {
      // Adding new: both stock code and name must not be empty
      return code.isNotEmpty && name.isNotEmpty;
    } else {
      // Editing: must have changes AND code/name not empty
      if (code.isEmpty || name.isEmpty) return false;

      final origCode = widget.ingredient!.code;
      final origName = widget.ingredient!.name;
      final origCat = widget.ingredient!.category;
      final origReorder = widget.ingredient!.reorderLevel.toString();
      final origUnit = widget.ingredient!.unit;

      final currentCat = _selectedCategory == 'Other' ? _catController.text.trim() : _selectedCategory;

      return code != origCode ||
             name != origName ||
             currentCat != origCat ||
             _reorderController.text.trim() != origReorder ||
             _unit != origUnit;
    }
  }

  String _handleError(dynamic e) {
    if (e is PostgrestException) {
      return "Supabase Error [${e.code}]: ${e.message}\nDetails: ${e.details}";
    }
    return e.toString();
  }

  Future<void> _save() async {
    // 1. Form Validation
    if (!_formKey.currentState!.validate()) return;

    // 2. Local Validation for specific constraints
    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final reorderStr = _reorderController.text.trim();

    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Stock code is required")));
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Name is required")));
      return;
    }

    final reorderLevel = double.tryParse(reorderStr);
    if (reorderLevel == null || reorderLevel < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reorder level must be a non-negative number"),
        ),
      );
      return;
    }

    final categoryVal = _selectedCategory == 'Other'
        ? _catController.text.trim()
        : _selectedCategory;

    // 3. Create Payload exactly as requested
    final payload = <String, dynamic>{
      'code': code,
      'name': name,
      'category': categoryVal.isEmpty ? 'General' : categoryVal,
      'unit': _unit.name.toUpperCase(),
      'reorder_level': reorderLevel,
      'current_quantity': widget.ingredient?.currentQuantity ?? 0,
      'average_unit_cost': widget.ingredient?.averageUnitCost ?? 0,
      'is_active': widget.ingredient?.isActive ?? true,
    };

    debugPrint('Stock payload: $payload');

    setState(() => _isSaving = true);
    try {
      final repo = IngredientRepository();
      // Use the payload for saving
      await repo.saveIngredient(payload, id: widget.ingredient?.id);

      if (!mounted) return;
      widget.onSave();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        // Display exact PostgrestException message and code
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_handleError(e)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.ingredient == null ? "Add Stock Item" : "Edit Stock Item",
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: "Stock Code",
                  hintText: "e.g. CHICKEN-001",
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Stock code is required";
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return "Required";
                  }
                  if (val.length < 2 || val.length > 100) {
                    return "2-100 characters";
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: "Category"),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedCategory = val);
                  }
                },
              ),
              if (_selectedCategory == 'Other')
                TextFormField(
                  controller: _catController,
                  decoration: const InputDecoration(
                    labelText: "Custom Category Name",
                  ),
                ),
              DropdownButtonFormField<IngredientUnit>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: "Unit"),
                items: IngredientUnit.values
                    .map(
                      (u) => DropdownMenuItem(
                        value: u,
                        child: Text(u.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _unit = val);
                  }
                },
              ),
              TextFormField(
                controller: _reorderController,
                decoration: const InputDecoration(labelText: "Reorder Level"),
                keyboardType: TextInputType.number,
                validator: (val) {
                  final n = double.tryParse(val ?? '');
                  if (n == null || n < 0) return "Invalid";
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("CANCEL"),
        ),
        ElevatedButton(
          onPressed: (!_isFormValid || _isSaving) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF008080),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
          ),
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(widget.ingredient == null ? "SAVE INGREDIENT" : "UPDATE INGREDIENT", style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
