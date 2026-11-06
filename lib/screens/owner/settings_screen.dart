import 'package:flutter/material.dart';
import '../../repositories/settings_repository.dart';
import '../../widgets/state_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = SettingsRepository();
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final _baseFeeController = TextEditingController();
  final _includedDistController = TextEditingController();
  final _additionalRateController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _repo.getBusinessSettings();
      _storeNameController.text = settings['store_name'] ?? 'Bellie\'s Kitchen';
      _addressController.text = settings['store_address'] ?? 'Sta. Cruz, Laguna';
      _phoneController.text = settings['contact_number'] ?? '09171234567';
      
      _baseFeeController.text = (settings['delivery_base_fee'] ?? settings['default_delivery_fee'] ?? 30.0).toString();
      _includedDistController.text = (settings['delivery_included_distance_km'] ?? 2.0).toString();
      _additionalRateController.text = (settings['delivery_rate_per_km'] ?? 10.0).toString();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final baseFee = double.tryParse(_baseFeeController.text) ?? 30.0;
      final includedDist = double.tryParse(_includedDistController.text) ?? 2.0;
      final addRate = double.tryParse(_additionalRateController.text) ?? 10.0;

      await _repo.updateBusinessSettings({
        'store_name': _storeNameController.text.trim(),
        'store_address': _addressController.text.trim(),
        'contact_number': _phoneController.text.trim(),
        'delivery_base_fee': baseFee,
        'delivery_included_distance_km': includedDist,
        'delivery_rate_per_km': addRate,
        'default_delivery_fee': baseFee,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings updated successfully!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Settings")),
      body: _isLoading 
        ? const LoadingState()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Store Configuration", Icons.storefront),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _storeNameController,
                          decoration: const InputDecoration(labelText: "Store Name", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(labelText: "Store Address", border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: "Contact Number", border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Delivery Fee Pricing Configuration", Icons.local_shipping_outlined),
                const SizedBox(height: 8),
                const Text(
                  "Formula: Delivery Fee = Base Fee + (max(0, Road Distance - Included Distance) × Additional Rate per Km)",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _baseFeeController,
                          decoration: const InputDecoration(
                            labelText: "Base Delivery Fee (₱)",
                            hintText: "30.00",
                            helperText: "Initial fee charged for delivery orders",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _includedDistController,
                          decoration: const InputDecoration(
                            labelText: "Included Base Distance (km)",
                            hintText: "2.0",
                            helperText: "Distance covered by the base fee",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _additionalRateController,
                          decoration: const InputDecoration(
                            labelText: "Rate Per Additional Kilometer (₱/km)",
                            hintText: "10.00",
                            helperText: "Fee added for every kilometer beyond the included distance",
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildSectionHeader("Security", Icons.lock_outline),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.password),
                    title: const Text("Change Admin Password"),
                    subtitle: const Text("Update your dashboard login credentials"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {},
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    child: _isSaving 
                      ? const CircularProgressIndicator()
                      : const Text("SAVE ALL CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFC2416C)),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
