import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/category_model.dart';
import '../../repositories/category_repository.dart';
import '../../widgets/state_widgets.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final _repository = CategoryRepository();
  bool _isLoading = true;
  String? _error;
  List<CategoryModel> _categories = [];
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
    _loadCategories();
  }

  Future<void> _checkRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      setState(() {
        _isOwner = response['role'] == 'OWNER';
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _repository.getCategories(activeOnly: !_isOwner);
      setState(() {
        _categories = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCategoryForm({CategoryModel? category}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoryFormDialog(
        category: category,
        onSave: () => _loadCategories(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Category Management"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCategories,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isOwner
          ? FloatingActionButton(
              onPressed: () => _showCategoryForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingState();
    if (_error != null) return ErrorState(error: _error!, onRetry: _loadCategories);
    if (_categories.isEmpty) return const EmptyState(message: "No categories found.");

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          child: ListTile(
            title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(category.description ?? "No description"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isOwner && !category.isActive)
                   const Icon(Icons.visibility_off, color: Colors.grey),
                if (_isOwner) ...[
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showCategoryForm(category: category),
                  ),
                  Switch(
                    value: category.isActive,
                    onChanged: (val) async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _repository.toggleCategoryActive(category.id, val);
                        if (mounted) _loadCategories();
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text("Error: ${e.toString()}")),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class CategoryFormDialog extends StatefulWidget {
  final CategoryModel? category;
  final VoidCallback onSave;

  const CategoryFormDialog({super.key, this.category, required this.onSave});

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _orderController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _descController.text = widget.category!.description ?? '';
      _orderController.text = widget.category!.displayOrder.toString();
    } else {
      _orderController.text = '0';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = CategoryRepository();
      final category = CategoryModel(
        id: widget.category?.id ?? '',
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        displayOrder: int.tryParse(_orderController.text) ?? 0,
        isActive: widget.category?.isActive ?? true,
        createdAt: widget.category?.createdAt ?? DateTime.now(),
      );
      await repo.saveCategory(category);
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? "Add Category" : "Edit Category"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_isSaving,
              maxLength: 50,
              decoration: const InputDecoration(labelText: "Category Name *"),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Category name is required";
                if (val.trim().length < 2) return "Category name must be at least 2 characters";
                return null;
              },
            ),
            TextFormField(
              controller: _descController,
              enabled: !_isSaving,
              maxLength: 150,
              decoration: const InputDecoration(labelText: "Description (Optional)"),
              maxLines: 2,
            ),
            TextFormField(
              controller: _orderController,
              enabled: !_isSaving,
              maxLength: 5,
              decoration: const InputDecoration(labelText: "Display Order"),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Display order required";
                if (int.tryParse(val.trim()) == null) return "Enter a valid number";
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("SAVE"),
        ),
      ],
    );
  }
}
