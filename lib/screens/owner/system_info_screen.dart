import 'package:flutter/material.dart';

class SystemInfoScreen extends StatelessWidget {
  const SystemInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Information")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Image.asset('assets/images/Bellieslogo.png', height: 150),
                  const SizedBox(height: 20),
                  const Text(
                    "Bellie’s SmartServe",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Version 1.0.0",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionTitle("Project Description"),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "An Integrated Mobile POS, Order Queue, Inventory Monitoring, Sales Analytics, and RFID Attendance Management System specifically designed for Bellie's Kitchen to automate daily operations and improve business efficiency.",
                  style: TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle("Key Modules"),
            _moduleItem(Icons.point_of_sale, "Mobile POS", "Cross-platform point of sale for cashier and online orders."),
            _moduleItem(Icons.kitchen, "Order Queue", "Real-time Kitchen Display System (KDS) for production management."),
            _moduleItem(Icons.inventory_2_outlined, "Inventory Hub", "Stock tracking with automatic deduction and reorder alerts."),
            _moduleItem(Icons.bar_chart, "Sales Analytics", "Data-driven insights and financial performance tracking."),
            _moduleItem(Icons.badge, "RFID Attendance", "Secure employee log-in/out via RFID technology."),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                "© 2026 Bellie's Kitchen. All rights reserved.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _moduleItem(IconData icon, String title, String desc) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFC2416C).withAlpha(30),
        child: Icon(icon, color: const Color(0xFFC2416C)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }
}
