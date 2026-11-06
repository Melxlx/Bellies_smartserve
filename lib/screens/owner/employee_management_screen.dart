import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_model.dart';
import '../../repositories/employee_repository.dart';
import '../../widgets/state_widgets.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final _repo = EmployeeRepository();
  final _searchController = TextEditingController();

  List<UserModel> _employees = [];
  List<UserModel> _customers = [];
  List<Map<String, dynamic>> _customerTrustData = [];
  bool _isLoading = true;
  bool _isGridView = true;
  String _roleFilter = 'All';
  String _statusFilter = 'All';
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final staff = await _repo.getAllEmployees();
      final customers = await _repo.getAllCustomers();
      final trustData = await _repo.getCustomerTrustData();
      if (mounted) {
        setState(() {
          _employees = staff;
          _customers = customers;
          _customerTrustData = trustData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        await showErrorDialog(
          context,
          title: 'Unable to Load Records',
          message: 'Staff/Customer records could not be loaded: $e',
        );
      }
    }
  }

  List<UserModel> get _filteredEmployees {
    return _employees.where((emp) {
      if (emp.accountStatus == AccountStatus.archived) return false;
      // Role filter
      if (_roleFilter != 'All' && emp.role.name.toLowerCase() != _roleFilter.toLowerCase()) {
        return false;
      }
      // Status filter
      if (_statusFilter == 'Active' && emp.accountStatus != AccountStatus.active) {
        return false;
      }
      if (_statusFilter == 'Inactive' && emp.accountStatus == AccountStatus.active) {
        return false;
      }
      // Search filter
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        final matchName = emp.fullName.toLowerCase().contains(q);
        final matchEmail = emp.email.toLowerCase().contains(q);
        final matchContact = emp.contactNumber?.toLowerCase().contains(q) ?? false;
        if (!matchName && !matchEmail && !matchContact) return false;
      }
      return true;
    }).toList();
  }

  List<UserModel> get _archivedUsers {
    final staffArchived = _employees.where((e) => e.accountStatus == AccountStatus.archived);
    final custArchived = _customers.where((c) => c.accountStatus == AccountStatus.archived);
    final combined = [...staffArchived, ...custArchived];
    if (_searchController.text.trim().isEmpty) return combined;
    final q = _searchController.text.trim().toLowerCase();
    return combined.where((u) {
      final nameMatch = u.fullName.toLowerCase().contains(q);
      final emailMatch = u.email.toLowerCase().contains(q);
      final contactMatch = u.contactNumber?.toLowerCase().contains(q) ?? false;
      return nameMatch || emailMatch || contactMatch;
    }).toList();
  }

  Future<void> _restoreUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Restore Account?"),
        content: Text("Are you sure you want to restore the account for ${user.fullName}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2416C), foregroundColor: Colors.white),
            child: const Text("RESTORE ACCOUNT"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _repo.restoreEmployeeProfile(user.id);
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${user.fullName} restored successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, title: "Error Restoring Account", message: e.toString());
      }
    }
  }

  Future<void> _permanentlyDeleteUser(UserModel user) async {
    final confirmController = TextEditingController();
    bool canDelete = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text("Permanently Delete Account?"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "WARNING: This will permanently delete ${user.fullName}'s profile and data. This action CANNOT be undone.",
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  children: [
                    const TextSpan(text: "To confirm, please type "),
                    TextSpan(text: "DELETE", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
                    const TextSpan(text: " in the field below:"),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmController,
                autofocus: true,
                onChanged: (val) {
                  setDialogState(() {
                    canDelete = val.trim().toUpperCase() == 'DELETE';
                  });
                },
                decoration: InputDecoration(
                  hintText: "Type 'DELETE' here",
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.red, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: canDelete ? () => Navigator.pop(context, true) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canDelete ? Colors.red : Colors.grey.shade300,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("PERMANENTLY DELETE"),
            ),
          ],
        ),
      ),
    );

    confirmController.dispose();
    if (confirmed != true) return;
    try {
      await _repo.permanentlyDeleteProfile(user.id);
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${user.fullName} deleted permanently."), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, title: "Error Deleting Account", message: e.toString());
      }
    }
  }

  void _editEmployee(UserModel emp) {
    showDialog(
      context: context,
      builder: (context) =>
          EmployeeFormDialog(employee: emp, onSave: _loadEmployees),
    );
  }

  void _viewProfile(UserModel employee) {
    showDialog(
      context: context,
      builder: (_) => EmployeeProfileDialog(
        employee: employee,
        onSave: _loadEmployees,
        onEdit: () => _editEmployee(employee),
      ),
    );
  }



  Future<void> _deleteStaff(UserModel emp) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Archive Staff Account?"),
        content: Text("Are you sure you want to archive/remove staff profile for ${emp.fullName}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text("ARCHIVE STAFF"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _repo.deleteEmployeeProfile(emp.id);
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${emp.fullName} archived successfully."), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorDialog(context, title: "Error Archiving Staff", message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: const SmartBackButton(),
        title: const Text("Staff Management"),
        backgroundColor: const Color(0xFFC2416C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderAndTabs(),
                  const SizedBox(height: 20),
                  if (_selectedTab == 0) ...[
                    _buildFilterControlBar(),
                    const SizedBox(height: 24),
                    _filteredEmployees.isEmpty
                        ? const EmptyState(message: "No staff members found matching filters.")
                        : (_isGridView ? _buildStaffGrid() : _buildStaffList()),
                  ] else if (_selectedTab == 1) ...[
                    _buildCustomerTrustView(),
                  ] else if (_selectedTab == 2) ...[
                    _buildArchivedView(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderAndTabs() {
    final activeCount = _employees.where((e) => e.accountStatus == AccountStatus.active).length;
    final trustedCount = _customers.where((c) => c.isTrustedCustomer).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Staff & Customer Management",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 10),
                        const SizedBox(width: 6),
                        Text(
                          "$activeCount Staff · $trustedCount Trusted COD",
                          style: GoogleFonts.poppins(color: const Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Staff & Customer Management",
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.green, size: 10),
                      const SizedBox(width: 6),
                      Text(
                        "$activeCount Staff · $trustedCount Trusted COD",
                        style: GoogleFonts.poppins(color: const Color(0xFF2E7D32), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        // Tabs Header Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabBadgeItem(0, "Staff Directory", _filteredEmployees.length),
              const SizedBox(width: 12),
              _tabBadgeItem(1, "Customers", _customers.where((c) => c.accountStatus != AccountStatus.archived).length),
              const SizedBox(width: 12),
              _tabBadgeItem(2, "Archive", _archivedUsers.length),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabBadgeItem(int index, String label, int count) {
    final bool isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = index;
          if (index == 0) _roleFilter = 'All';
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC2416C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFC2416C) : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withAlpha(60) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerTrustView() {
    final filteredCustomers = _customerTrustData.where((c) {
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        final nameMatch = (c['full_name'] ?? '').toString().toLowerCase().contains(q);
        final emailMatch = (c['email'] ?? '').toString().toLowerCase().contains(q);
        return nameMatch || emailMatch;
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Customer Management", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                "Track customer order frequency (3-5 completed orders qualifies as Suki) & manage COD access",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: "Search customer name or email...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          ),
        ),
        const SizedBox(height: 20),
        filteredCustomers.isEmpty
            ? const EmptyState(message: "No customer profiles found.")
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  final c = filteredCustomers[index];
                  final String customerId = (c['id'] ?? c['user_id'] ?? '').toString();
                  final String fullName = (c['full_name'] ?? 'Customer').toString();
                  final String email = (c['email'] ?? '').toString();
                  final bool isTrusted = c['is_trusted_customer'] == true;
                  final String accountStatus = (c['account_status'] ?? 'ACTIVE').toString().toUpperCase();
                  final bool isLocked = accountStatus == 'LOCKED';
                  final int completedOrders = (c['completed_orders'] as num? ?? 0).toInt();
                  final double totalSpent = (c['total_spent'] as num? ?? 0).toDouble();

                  // Suki qualification check (3 to 5+ completed orders)
                  final bool isSukiQualified = completedOrders >= 3;

                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isLocked
                            ? Colors.red.shade200
                            : (isSukiQualified ? const Color(0xFFD4AF37) : (isTrusted ? Colors.green.shade200 : Colors.grey.shade200)),
                        width: isSukiQualified || isLocked ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isLocked
                                    ? Colors.red.shade50
                                    : (isSukiQualified ? const Color(0xFFFFF8E7) : (isTrusted ? const Color(0xFFE8F5E9) : Colors.grey.shade100)),
                                child: Icon(
                                  isLocked
                                      ? Icons.lock_rounded
                                      : (isSukiQualified ? Icons.stars_rounded : (isTrusted ? Icons.verified_rounded : Icons.person_outline)),
                                  color: isLocked
                                      ? Colors.red
                                      : (isSukiQualified ? const Color(0xFFD4AF37) : (isTrusted ? Colors.green : Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                onSelected: (value) async {
                                  if (value == 'lock') {
                                    final newStatus = isLocked ? 'ACTIVE' : 'LOCKED';
                                    await _repo.updateCustomerTrustStatus(
                                      customerId,
                                      accountStatus: newStatus,
                                      isTrusted: isLocked ? isTrusted : false,
                                    );
                                    _loadEmployees();
                                  } else if (value == 'archive') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: const Text("Archive Customer"),
                                        content: Text("Are you sure you want to archive $fullName?"),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text("ARCHIVE"),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await _repo.updateCustomerTrustStatus(
                                        customerId,
                                        accountStatus: 'ARCHIVED',
                                      );
                                      _loadEmployees();
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'lock',
                                    child: Row(
                                      children: [
                                        Icon(isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 18, color: isLocked ? Colors.green : Colors.orange),
                                        const SizedBox(width: 8),
                                        Text(isLocked ? 'Unlock Account' : 'Lock Account / Block COD'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'archive',
                                    child: Row(
                                      children: [
                                        Icon(Icons.archive_outlined, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Archive Customer'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (isLocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: const Text(
                                    "🔒 ACCOUNT LOCKED / BLOCKED",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isTrusted
                                        ? const Color(0xFFE8F5E9)
                                        : (isSukiQualified ? const Color(0xFFFFF8E7) : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isTrusted
                                          ? Colors.green
                                          : (isSukiQualified ? const Color(0xFFD4AF37) : Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Text(
                                    isTrusted
                                        ? "⭐ TRUSTED (COD ALLOWED)"
                                        : (isSukiQualified ? "🎯 SUKI QUALIFIED ($completedOrders ORDERS)" : "REGULAR (PAYMENT FIRST)"),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isTrusted
                                          ? Colors.green.shade800
                                          : (isSukiQualified ? const Color(0xFFB8860B) : Colors.grey.shade700),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFF0F172A)),
                                const SizedBox(width: 4),
                                Text(
                                  "$completedOrders Completed",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(width: 6),
                                const Text("•", style: TextStyle(color: Colors.grey)),
                                const SizedBox(width: 6),
                                Text(
                                  "₱${totalSpent.toStringAsFixed(2)} Spent",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text("Allow COD:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  Switch(
                                    value: isTrusted && !isLocked,
                                    activeTrackColor: const Color(0xFFC2416C),
                                    onChanged: isLocked
                                        ? null
                                        : (newVal) async {
                                            await _repo.updateCustomerTrustStatus(customerId, isTrusted: newVal);
                                            _loadEmployees();
                                          },
                                  ),
                                ],
                              ),
                              if (isSukiQualified && !isTrusted && !isLocked)
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await _repo.updateCustomerTrustStatus(
                                      customerId,
                                      isTrusted: true,
                                      ownerNotes: "Auto-qualified suki ($completedOrders completed orders)",
                                    );
                                    _loadEmployees();
                                  },
                                  icon: const Icon(Icons.stars_rounded, size: 14),
                                  label: const Text("UNLOCK COD", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD4AF37),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  Widget _buildArchivedView() {
    final archived = _archivedUsers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Archived Accounts", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("View and restore archived staff and customer accounts", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: "Search archived user by name, email, or contact...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
          ),
        ),
        const SizedBox(height: 20),
        archived.isEmpty
            ? const EmptyState(message: "No archived accounts found.")
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: archived.length,
                itemBuilder: (context, index) {
                  final user = archived[index];
                  final isCustomer = user.role == UserRole.customer || user.role == UserRole.guest;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: const Color(0xFFFFF0F5),
                            backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty ? NetworkImage(user.avatarUrl!) : null,
                            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                                ? Icon(isCustomer ? Icons.person_outline : Icons.badge_outlined, color: const Color(0xFFE91E63))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isCustomer ? Colors.blue.shade50 : Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isCustomer ? "CUSTOMER" : (user.position.isNotEmpty ? user.position : user.role.name.toUpperCase()),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isCustomer ? Colors.blue.shade700 : Colors.purple.shade700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "ARCHIVED",
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email.isNotEmpty ? user.email : (user.contactNumber ?? 'No contact info'),
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFC2416C),
                              side: const BorderSide(color: Color(0xFFC2416C)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _restoreUser(user),
                            icon: const Icon(Icons.unarchive_outlined, size: 16),
                            label: const Text("RESTORE"),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                            tooltip: "Permanently Delete",
                            onPressed: () => _permanentlyDeleteUser(user),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }





  Widget _buildFilterControlBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;

          final searchField = SizedBox(
            width: isNarrow ? double.infinity : null,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search staff name, email, or phone...",
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          );

          final roleDropdown = SizedBox(
            width: isNarrow ? 125 : 140,
            child: DropdownButtonFormField<String>(
              initialValue: _roleFilter,
              isDense: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Roles', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'cashier', child: Text('Cashier', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'kitchen', child: Text('Kitchen', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'rider', child: Text('Rider', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (val) => setState(() => _roleFilter = val ?? 'All'),
            ),
          );

          final statusDropdown = SizedBox(
            width: isNarrow ? 125 : 130,
            child: DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              isDense: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Status', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Active', child: Text('Active', style: TextStyle(fontSize: 12))),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive', style: TextStyle(fontSize: 12))),
              ],
              onChanged: (val) => setState(() => _statusFilter = val ?? 'All'),
            ),
          );

          final toggleViewBtn = Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.grid_view_rounded, color: _isGridView ? const Color(0xFFC2416C) : Colors.grey, size: 20),
                  onPressed: () => setState(() => _isGridView = true),
                ),
                IconButton(
                  icon: Icon(Icons.format_list_bulleted_rounded, color: !_isGridView ? const Color(0xFFC2416C) : Colors.grey, size: 20),
                  onPressed: () => setState(() => _isGridView = false),
                ),
              ],
            ),
          );

          final addStaffBtn = ElevatedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => NewEmployeeDialog(onSave: _loadEmployees),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Add Staff"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008080),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          );

          if (isNarrow) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      roleDropdown,
                      const SizedBox(width: 8),
                      statusDropdown,
                      const SizedBox(width: 8),
                      toggleViewBtn,
                      const SizedBox(width: 8),
                      addStaffBtn,
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 12),
              roleDropdown,
              const SizedBox(width: 8),
              statusDropdown,
              const SizedBox(width: 12),
              toggleViewBtn,
              const SizedBox(width: 12),
              addStaffBtn,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStaffGrid() {
    final list = _filteredEmployees;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 220,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) => _buildStaffCard(list[index]),
        );
      },
    );
  }

  Widget _buildStaffList() {
    final list = _filteredEmployees;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final emp = list[index];
        final roleColor = _getRoleColor(emp.role);

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: roleColor.withAlpha(30),
              backgroundImage: emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty ? NetworkImage(emp.avatarUrl!) : null,
              child: emp.avatarUrl == null || emp.avatarUrl!.isEmpty
                  ? Text(_initials(emp.fullName), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(emp.fullName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text("${emp.email} • ${emp.contactNumber ?? 'No phone'}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _roleChip(emp.role),
                const SizedBox(width: 8),
                _statusChip(emp.accountStatus),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _editEmployee(emp),
                ),
              ],
            ),
            onTap: () => _viewProfile(emp),
          ),
        );
      },
    );
  }

  Widget _buildStaffCard(UserModel emp) {
    final roleColor = _getRoleColor(emp.role);
    final bool isActive = emp.accountStatus == AccountStatus.active;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row Status Indicator & Options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isActive ? "Online now" : "Inactive",
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'edit') _editEmployee(emp);
                  if (val == 'profile') _viewProfile(emp);
                  if (val == 'delete') _deleteStaff(emp);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit Details')])),
                  PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person, size: 16), SizedBox(width: 8), Text('View Profile')])),
                  PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Archive Staff')])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Avatar + Name + Role
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: roleColor.withAlpha(25),
                    foregroundImage: emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty ? NetworkImage(emp.avatarUrl!) : null,
                    onForegroundImageError: emp.avatarUrl != null && emp.avatarUrl!.isNotEmpty
                        ? (e, s) {}
                        : null,
                    child: Text(
                      _initials(emp.fullName),
                      style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emp.fullName,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    _roleChip(emp.role),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          const Divider(height: 16),
          // Contact Details & Salary
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  emp.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    emp.contactNumber?.isNotEmpty == true ? emp.contactNumber! : "No contact",
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
              Text(
                "₱${emp.dailyRate.toStringAsFixed(0)}/day",
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFC2416C)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleChip(UserRole role) {
    Color color = _getRoleColor(role);
    IconData icon = Icons.work_outline;

    switch (role) {
      case UserRole.cashier:
        icon = Icons.point_of_sale_rounded;
        break;
      case UserRole.kitchen:
        icon = Icons.restaurant_rounded;
        break;
      case UserRole.rider:
        icon = Icons.local_shipping_rounded;
        break;
      case UserRole.owner:
        icon = Icons.stars_rounded;
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            role.name.toUpperCase(),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(AccountStatus status) {
    Color color = status == AccountStatus.active ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.cashier:
        return Colors.blue;
      case UserRole.kitchen:
        return Colors.orange;
      case UserRole.rider:
        return Colors.green;
      case UserRole.owner:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class EmployeeFormDialog extends StatefulWidget {
  final UserModel employee;
  final VoidCallback onSave;

  const EmployeeFormDialog({
    super.key,
    required this.employee,
    required this.onSave,
  });

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _picker = ImagePicker();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _positionController;
  late final TextEditingController _rateController;
  late String? _avatarUrl;
  late UserRole _selectedRole;
  late AccountStatus _selectedStatus;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final parts = widget.employee.fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final fName = widget.employee.firstName?.trim().isNotEmpty == true ? widget.employee.firstName! : (parts.isNotEmpty ? parts.first : '');
    final mName = widget.employee.middleName?.trim() ?? '';
    final lName = widget.employee.lastName?.trim().isNotEmpty == true ? widget.employee.lastName! : (parts.length > 1 ? parts.sublist(1).join(' ') : '');

    _firstNameController = TextEditingController(text: fName);
    _middleNameController = TextEditingController(text: mName);
    _lastNameController = TextEditingController(text: lName);
    _contactController = TextEditingController(text: widget.employee.contactNumber ?? '');
    _positionController = TextEditingController(text: widget.employee.position);
    _rateController = TextEditingController(
      text: widget.employee.dailyRate > 0
          ? widget.employee.dailyRate.toStringAsFixed(0)
          : '0',
    );
    _avatarUrl = widget.employee.avatarUrl;
    const validRoles = [UserRole.cashier, UserRole.kitchen, UserRole.rider, UserRole.owner];
    _selectedRole = validRoles.contains(widget.employee.role)
        ? widget.employee.role
        : UserRole.cashier;
    _selectedStatus = widget.employee.accountStatus;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _contactController.dispose();
    _positionController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }



  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final mime = file.mimeType?.toLowerCase() ?? '';

    // 1. Format validation: JPEG or PNG ONLY
    final allowedExts = ['.jpg', '.jpeg', '.png'];
    final hasValidExt = allowedExts.any((ext) => name.endsWith(ext) || path.endsWith(ext));
    final hasValidMime = mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/jpg';

    if (!hasValidExt && !hasValidMime) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid file format. Only JPEG (.jpg, .jpeg) and PNG (.png) images are accepted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2. File size validation: Maximum 5MB
    final bytes = await file.readAsBytes();
    const maxSizeBytes = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxSizeBytes) {
      if (mounted) {
        final mbSize = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File size ($mbSize MB) exceeds the 5 MB maximum limit. Please choose a smaller image.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    try {
      final uploadPath = '${widget.employee.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _supabase.storage
          .from('employee-avatars')
          .uploadBinary(
            uploadPath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = _supabase.storage.from('employee-avatars').getPublicUrl(uploadPath);
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload photo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final computedFullName = "${_firstNameController.text.trim()} ${_middleNameController.text.trim()} ${_lastNameController.text.trim()}".replaceAll(RegExp(r'\s+'), ' ').trim();

      await EmployeeRepository().updateEmployee(widget.employee.id, {
        'full_name': computedFullName,
        'first_name': _firstNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'contact_number': _contactController.text.trim(),
        'position': _positionController.text.trim(),
        'daily_rate': double.parse(_rateController.text),
        'role': _selectedRole.name.toUpperCase(),
        'account_status': _selectedStatus.name.toUpperCase(),
        if (_avatarUrl != null) 'avatar_url': _avatarUrl,
      });
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating staff: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool get _hasChanges {
    final originalRate = widget.employee.dailyRate > 0
        ? widget.employee.dailyRate.toStringAsFixed(0)
        : '0';

    final parts = widget.employee.fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final fName = widget.employee.firstName?.trim().isNotEmpty == true ? widget.employee.firstName! : (parts.isNotEmpty ? parts.first : '');
    final mName = widget.employee.middleName?.trim() ?? '';
    final lName = widget.employee.lastName?.trim().isNotEmpty == true ? widget.employee.lastName! : (parts.length > 1 ? parts.sublist(1).join(' ') : '');

    final fNameChanged = _firstNameController.text.trim() != fName;
    final mNameChanged = _middleNameController.text.trim() != mName;
    final lNameChanged = _lastNameController.text.trim() != lName;
    final contactChanged = _contactController.text.trim() != (widget.employee.contactNumber ?? '').trim();
    final posChanged = _positionController.text.trim() != widget.employee.position.trim();
    final rateChanged = _rateController.text.trim() != originalRate;
    final roleChanged = _selectedRole != widget.employee.role;
    final statusChanged = _selectedStatus != widget.employee.accountStatus;
    final avatarChanged = _avatarUrl != widget.employee.avatarUrl;

    return fNameChanged || mNameChanged || lNameChanged || contactChanged || posChanged || rateChanged || roleChanged || statusChanged || avatarChanged;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("Edit Staff Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Stack(
                    children: [
                      _avatarUrl == null || _avatarUrl!.isEmpty
                          ? CircleAvatar(
                              radius: 40,
                              backgroundColor: const Color(0xFFFCE4EC),
                              child: Text(
                                _initials("${_firstNameController.text} ${_lastNameController.text}"),
                                style: const TextStyle(color: Color(0xFFC2416C), fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            )
                          : CircleAvatar(
                              radius: 40,
                              backgroundImage: NetworkImage(_avatarUrl!),
                            ),
                      if (_isUploading)
                        const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isUploading ? null : _pickPhoto,
                  icon: const Icon(Icons.upload_outlined, size: 16),
                  label: Text(_avatarUrl == null ? 'UPLOAD PHOTO' : 'REPLACE PHOTO', style: const TextStyle(fontSize: 12)),
                ),
                const Divider(height: 20),
                TextFormField(
                  controller: _firstNameController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "First Name",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'First name is required';
                    if (v.trim().length < 2) return 'Must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _middleNameController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Middle Name (Optional)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Last Name",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Last name is required';
                    if (v.trim().length < 2) return 'Must be at least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: "Email Address (Read-only)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  child: Text(widget.employee.email.isEmpty ? 'No email' : widget.employee.email, style: const TextStyle(color: Colors.grey)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Contact Number",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Assigned Role",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: UserRole.cashier, child: Text("CASHIER")),
                    DropdownMenuItem(value: UserRole.kitchen, child: Text("KITCHEN")),
                    DropdownMenuItem(value: UserRole.rider, child: Text("RIDER")),
                    DropdownMenuItem(value: UserRole.owner, child: Text("OWNER / MANAGER")),
                  ],
                  onChanged: _isSaving ? null : (v) => setState(() => _selectedRole = v ?? UserRole.cashier),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _positionController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Position Title",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Position is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountStatus>(
                  initialValue: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: "Account Status",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: AccountStatus.active, child: Text("ACTIVE")),
                    DropdownMenuItem(value: AccountStatus.archived, child: Text("ARCHIVED")),
                    DropdownMenuItem(value: AccountStatus.locked, child: Text("LOCKED")),
                  ],
                  onChanged: _isSaving ? null : (v) => setState(() => _selectedStatus = v ?? AccountStatus.active),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rateController,
                  enabled: !_isSaving,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Daily Rate (₱)",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter valid rate > 0';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: (_isSaving || !_hasChanges) ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC2416C),
            foregroundColor: Colors.white,
          ),
          child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SAVE CHANGES"),
        ),
      ],
    );
  }
}

class EmployeeProfileDialog extends StatelessWidget {
  final UserModel employee;
  final VoidCallback onSave;
  final VoidCallback? onEdit;

  const EmployeeProfileDialog({
    super.key,
    required this.employee,
    required this.onSave,
    this.onEdit,
  });

  List<String> get _nameParts {
    final parts = employee.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    return [
      employee.firstName?.trim().isNotEmpty == true
          ? employee.firstName!.trim()
          : (parts.isNotEmpty ? parts.first : ''),
      employee.middleName?.trim() ?? '',
      employee.lastName?.trim().isNotEmpty == true
          ? employee.lastName!.trim()
          : (parts.length > 1 ? parts.sublist(1).join(' ') : ''),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final parts = _nameParts;
    final avatarUrl = employee.avatarUrl;

    return AlertDialog(
      title: Text('Employee Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 440,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? CircleAvatar(
                        radius: 46,
                        backgroundColor: const Color(0xFFFCE4EC),
                        child: Text(
                          _initials(employee.fullName),
                          style: const TextStyle(
                            color: Color(0xFFC2416C),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : CircleAvatar(
                        radius: 46,
                        backgroundImage: NetworkImage(avatarUrl),
                      ),
              ),
              const Divider(height: 24),
              _profileField('First Name', parts[0]),
              _profileField(
                'Middle Name',
                parts[1].isEmpty ? 'Not provided' : parts[1],
              ),
              _profileField('Last Name', parts[2]),
              _profileField('Email Address', employee.email),
              _profileField(
                'Contact Number',
                employee.contactNumber?.isNotEmpty == true
                    ? employee.contactNumber!
                    : 'No contact number',
              ),
              _profileField(
                'Assigned Role',
                employee.role.name.toUpperCase(),
              ),
              _profileField('Position/Title', employee.position),
              _profileField(
                'Account Status',
                employee.accountStatus.name.toUpperCase(),
              ),
              const SizedBox(height: 12),
              const Text(
                'PAYROLL DETAILS',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              _profileField(
                'Daily Rate',
                '₱${employee.dailyRate.toStringAsFixed(2)}/day',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CLOSE', style: TextStyle(color: Colors.grey)),
        ),
        if (onEdit != null)
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              onEdit!();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('EDIT DETAILS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2416C),
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _profileField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
        child: Text(
          value.isEmpty ? 'Not provided' : value,
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'ST';
    if (parts.length == 1) return parts.first.substring(0, 2).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class NewEmployeeDialog extends StatefulWidget {
  final VoidCallback onSave;
  const NewEmployeeDialog({super.key, required this.onSave});

  @override
  State<NewEmployeeDialog> createState() => _NewEmployeeDialogState();
}

class _NewEmployeeDialogState extends State<NewEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _rateController = TextEditingController(text: '500');

  UserRole _selectedRole = UserRole.cashier;
  String _employmentType = 'Full Time';
  String _gender = 'Prefer not to say';
  int _currentStep = 0;
  bool _isSaving = false;
  bool _passwordVisible = false;
  String? _avatarUrl;
  bool _isUploading = false;
  bool _isStepTransitioning = false;
  final _picker = ImagePicker();

  void _nextStep() {
    if (_isStepTransitioning || _isSaving || _isUploading) return;
    if (_validateCurrentStep()) {
      setState(() {
        _isStepTransitioning = true;
        _currentStep++;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isStepTransitioning = false);
      });
    }
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    final name = file.name.toLowerCase();
    final path = file.path.toLowerCase();
    final mime = file.mimeType?.toLowerCase() ?? '';

    // 1. Format validation: JPEG or PNG ONLY
    final allowedExts = ['.jpg', '.jpeg', '.png'];
    final hasValidExt = allowedExts.any((ext) => name.endsWith(ext) || path.endsWith(ext));
    final hasValidMime = mime == 'image/jpeg' || mime == 'image/png' || mime == 'image/jpg';

    if (!hasValidExt && !hasValidMime) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid file format. Only JPEG (.jpg, .jpeg) and PNG (.png) images are accepted.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // 2. File size validation: Maximum 5MB
    final bytes = await file.readAsBytes();
    const maxSizeBytes = 5 * 1024 * 1024; // 5 MB
    if (bytes.length > maxSizeBytes) {
      if (mounted) {
        final mbSize = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File size ($mbSize MB) exceeds the 5 MB maximum limit. Please choose a smaller image.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    try {
      final uploadPath = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await Supabase.instance.client.storage
          .from('employee-avatars')
          .uploadBinary(
            uploadPath,
            bytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
          );
      final url = Supabase.instance.client.storage.from('employee-avatars').getPublicUrl(uploadPath);
      if (mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not upload photo: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await EmployeeRepository().createEmployee(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _buildFullName(),
        firstName: _normalizeNamePart(_firstNameController.text),
        middleName: _normalizeNamePart(_middleNameController.text),
        lastName: _normalizeNamePart(_lastNameController.text),
        role: _selectedRole,
        position: _positionController.text.trim().isNotEmpty
            ? _positionController.text.trim()
            : _selectedRole.name.toUpperCase(),
        dailyRate: double.parse(_rateController.text),
      );

      // Save contact number and avatar url if provided
      final updates = <String, dynamic>{};
      if (_phoneController.text.trim().isNotEmpty) updates['contact_number'] = _phoneController.text.trim();
      if (_avatarUrl != null && _avatarUrl!.isNotEmpty) updates['avatar_url'] = _avatarUrl;

      if (updates.isNotEmpty) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await Supabase.instance.client
              .from('profiles')
              .update(updates)
              .eq('email', _emailController.text.trim());
        }
      }

      if (!mounted) return;
      widget.onSave();
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        final rawMessage = error.toString();
        final message =
            rawMessage.contains('FunctionsFetchException') ||
                rawMessage.contains('status: 0') ||
                rawMessage.contains('status code: 404')
            ? 'The employee service is unavailable. Deploy the create-employee Edge Function in Supabase, then try again.'
            : 'Could not create employee: $error';
        await showErrorDialog(
          context,
          title: 'Employee Creation Failed',
          message: message,
        );
      }
    }
  }

  String _buildFullName() {
    final first = _firstNameController.text.trim();
    final middle = _middleNameController.text.trim();
    final last = _lastNameController.text.trim();

    final parts = [first, middle, last].where((p) => p.isNotEmpty).toList();
    return parts.join(' ');
  }

  String? _normalizeNamePart(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _validateCurrentStep() {
    final emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');
    final phoneRegex = RegExp(r'^(09|\+639)\d{9}$');

    if (_currentStep == 0) {
      final fname = _firstNameController.text.trim();
      final lname = _lastNameController.text.trim();
      if (fname.isEmpty) {
        _showStepError('First Name is required.');
        return false;
      }
      if (_firstNameController.text.startsWith(' ')) {
        _showStepError('First Name cannot start with a space.');
        return false;
      }
      if (fname.length < 2) {
        _showStepError('First Name must be at least 2 letters.');
        return false;
      }
      if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(fname)) {
        _showStepError('First Name cannot contain numbers or symbols.');
        return false;
      }
      if (lname.isEmpty) {
        _showStepError('Last Name is required.');
        return false;
      }
      if (_lastNameController.text.startsWith(' ')) {
        _showStepError('Last Name cannot start with a space.');
        return false;
      }
      if (lname.length < 2) {
        _showStepError('Last Name must be at least 2 letters.');
        return false;
      }
      if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(lname)) {
        _showStepError('Last Name cannot contain numbers or symbols.');
        return false;
      }
    } else if (_currentStep == 1) {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim().replaceAll(RegExp(r'[\s()\-]'), '');
      if (email.isEmpty) {
        _showStepError('Work Email Address is required.');
        return false;
      }
      if (!emailRegex.hasMatch(email)) {
        _showStepError('Please enter a valid email address (e.g. name@domain.com).');
        return false;
      }
      if (phone.isNotEmpty && !phoneRegex.hasMatch(phone)) {
        _showStepError('Please enter a valid 11-digit PH mobile number (e.g. 09171234567).');
        return false;
      }
    } else if (_currentStep == 2) {
      final rate = double.tryParse(_rateController.text.trim());
      if (rate == null || rate <= 0) {
        _showStepError('Please enter a valid positive daily salary rate (e.g. 500).');
        return false;
      }
    }
    return true;
  }

  void _showStepError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Add New Employee",
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stepper Progress Bar
              _buildStepProgress(),
              const SizedBox(height: 20),
              // Step Content Area
              Flexible(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              const SizedBox(height: 24),
              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _currentStep--),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text("Back"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    onPressed: (_isSaving || _isUploading || _isStepTransitioning)
                        ? null
                        : () {
                            if (_currentStep < 3) {
                              _nextStep();
                            } else {
                              _save();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC2416C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_currentStep < 3 ? "Next ➔" : "CREATE STAFF"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepProgress() {
    final steps = [
      "Basic Information",
      "Contact Details",
      "Employment Details",
      "Account Setup",
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final bool isActive = _currentStep == index;
        final bool isCompleted = _currentStep > index;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted || isActive ? const Color(0xFFC2416C) : Colors.grey[300],
                      ),
                    ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? const Color(0xFFC2416C)
                          : (isCompleted ? const Color(0xFFC2416C) : Colors.grey[300]),
                      border: Border.all(
                        color: isActive ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isCompleted ? const Color(0xFFC2416C) : Colors.grey[300],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[index],
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? const Color(0xFFC2416C) : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0BasicInfo();
      case 1:
        return _buildStep1ContactDetails();
      case 2:
        return _buildStep2EmploymentDetails();
      case 3:
      default:
        return _buildStep3AccountSetup();
    }
  }

  Widget _buildStep0BasicInfo() {
    return Column(
      children: [
        // Photo Avatar Placeholder
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFFCE4EC),
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!) : null,
                child: _isUploading
                    ? const CircularProgressIndicator(color: Color(0xFFC2416C))
                    : (_avatarUrl == null || _avatarUrl!.isEmpty
                        ? const Icon(Icons.person_outline_rounded, size: 40, color: Color(0xFFC2416C))
                        : null),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickPhoto,
                icon: Icon(_isUploading ? Icons.hourglass_empty : Icons.upload_outlined, size: 16),
                label: Text(_avatarUrl == null ? "Upload Photo" : "Replace Photo"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _firstNameController,
                enabled: !_isSaving,
                maxLength: 30,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                  DenyLeadingSpaceFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: "First Name *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.trim().length < 2 ? 'Required (min 2 chars)' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lastNameController,
                enabled: !_isSaving,
                maxLength: 30,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
                  DenyLeadingSpaceFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: "Last Name *",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.trim().length < 2 ? 'Required (min 2 chars)' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _middleNameController,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: "Middle Name (Optional)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: InputDecoration(
                  labelText: "Gender",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
                ],
                onChanged: _isSaving ? null : (v) => setState(() => _gender = v ?? 'Prefer not to say'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep1ContactDetails() {
    return Column(
      children: [
        TextFormField(
          controller: _emailController,
          enabled: !_isSaving,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: "Work Email Address *",
            hintText: "e.g. cashier@bellies.com",
            prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFC2416C)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phoneController,
          enabled: !_isSaving,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: "Mobile Contact Number",
            hintText: "0917 123 4567",
            prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFFC2416C)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _employmentType,
          decoration: InputDecoration(
            labelText: "Employment Type",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'Full Time', child: Text('Full Time')),
            DropdownMenuItem(value: 'Part Time', child: Text('Part Time')),
            DropdownMenuItem(value: 'Contract', child: Text('Contract')),
            DropdownMenuItem(value: 'Shift Basis', child: Text('Shift Basis')),
          ],
          onChanged: _isSaving ? null : (v) => setState(() => _employmentType = v ?? 'Full Time'),
        ),
      ],
    );
  }

  Widget _buildStep2EmploymentDetails() {
    return Column(
      children: [
        DropdownButtonFormField<UserRole>(
          initialValue: _selectedRole,
          decoration: InputDecoration(
            labelText: "Assigned Role *",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: UserRole.cashier, child: Text("CASHIER (POS & Orders)")),
            DropdownMenuItem(value: UserRole.kitchen, child: Text("KITCHEN (Food Preparation)")),
            DropdownMenuItem(value: UserRole.rider, child: Text("RIDER (Delivery Logistics)")),
          ],
          onChanged: _isSaving ? null : (v) {
            setState(() {
              _selectedRole = v ?? UserRole.cashier;
              if (_positionController.text.isEmpty) {
                _positionController.text = _selectedRole == UserRole.cashier
                    ? 'Cashier Staff'
                    : (_selectedRole == UserRole.kitchen ? 'Kitchen Cook' : 'Delivery Rider');
              }
            });
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _positionController,
          enabled: !_isSaving,
          decoration: InputDecoration(
            labelText: "Job Position Title",
            hintText: "e.g. Senior Cashier, Head Cook",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Position is required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _rateController,
          enabled: !_isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: "Daily Salary Rate (₱)",
            hintText: "500",
            prefixText: "₱ ",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Enter valid rate > 0';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStep3AccountSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Account Summary:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text("Name: ${_buildFullName()}", style: const TextStyle(fontSize: 12)),
              Text("Email: ${_emailController.text.trim()}", style: const TextStyle(fontSize: 12)),
              Text("Role: ${_selectedRole.name.toUpperCase()} (₱${_rateController.text}/day)", style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          enabled: !_isSaving,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            labelText: "Login Password *",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: Icon(_passwordVisible ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
            ),
          ),
          validator: (v) => v == null || v.length < 6 ? 'Min 6 characters required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _confirmPasswordController,
          enabled: !_isSaving,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            labelText: "Confirm Password *",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (v != _passwordController.text) return 'Passwords do not match';
            return null;
          },
        ),
      ],
    );
  }
}

class DenyLeadingSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }
    return newValue;
  }
}
