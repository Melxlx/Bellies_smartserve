import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_routes.dart';

class TutorialStep {
  final String title;
  final String description;
  final IconData? icon;
  final String? assetImagePath;
  final Color color;
  final String? targetActionHint;
  final String? routeName; // Navigation route to actually take the user there

  const TutorialStep({
    required this.title,
    required this.description,
    this.icon,
    this.assetImagePath,
    required this.color,
    this.targetActionHint,
    this.routeName,
  });
}

class TutorialGuideModal extends StatefulWidget {
  final String roleTitle;
  final List<TutorialStep> steps;
  final VoidCallback? onFinished;

  const TutorialGuideModal({
    super.key,
    required this.roleTitle,
    required this.steps,
    this.onFinished,
  });

  static void show(BuildContext context, {required String roleTitle, required List<TutorialStep> steps}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TutorialGuideModal(
        roleTitle: roleTitle,
        steps: steps,
        onFinished: () => Navigator.pop(context),
      ),
    );
  }

  /// Interactive Owner Tour Steps that actually navigate to each screen
  static List<TutorialStep> get ownerTourSteps => [
        const TutorialStep(
          title: "1. Owner Dashboard 📊",
          description: "Let's start here! This is where you monitor daily sales, order queues, and overall restaurant performance in real time.",
          assetImagePath: 'assets/images/Bellieslogo.png',
          color: Color(0xFFE91E63),
          targetActionHint: "👉 Proceeding to Dashboard Overview",
          routeName: AppRoutes.ownerDashboard,
        ),
        const TutorialStep(
          title: "2. Live RFID Attendance 🏷️",
          description: "Now let's check Attendance! Here you view live logs and assign RFID UIDs to your kitchen staff and cashiers instantly.",
          icon: Icons.badge_rounded,
          color: Color(0xFF3B82F6),
          targetActionHint: "👉 Proceeding to Live RFID Attendance & Staff Cards",
          routeName: AppRoutes.attendance,
        ),
        const TutorialStep(
          title: "3. Daily Wage Payroll 💵",
          description: "Finally, let's view Payroll! Here you calculate hours worked and process daily staff wage payouts with 1 tap.",
          icon: Icons.payments_rounded,
          color: Color(0xFF10B981),
          targetActionHint: "👉 Proceeding to Daily Wage Payroll Management",
          routeName: AppRoutes.payroll,
        ),
      ];

  static List<TutorialStep> get ownerSteps => ownerTourSteps;

  /// Customer Tour Steps
  static List<TutorialStep> get customerSteps => [
        const TutorialStep(
          title: "Welcome to Bellie's SmartServe! 🍜",
          description: "Enjoy fast, freshly prepared meals delivered right to your doorstep or ready for pickup.",
          assetImagePath: 'assets/images/Bellieslogo.png',
          color: Color(0xFFE91E63),
          targetActionHint: "👉 Let's take a quick 1-minute tour of your ordering portal",
        ),
        const TutorialStep(
          title: "Search, Filter & Sort 🔍",
          description: "Use our search bar, category filters, and sorting options to instantly find your favorite Lugaw, Silog, or Ulam.",
          icon: Icons.search_rounded,
          color: Color(0xFF3B82F6),
          targetActionHint: "👉 Tap the Search bar at the top to search meals",
        ),
        const TutorialStep(
          title: "Secure Checkout & GCash 💳",
          description: "Add items to your cart, review your delivery address, and pay securely via GCash reference or Cash on Delivery (COD).",
          icon: Icons.payment_rounded,
          color: Color(0xFF10B981),
          targetActionHint: "👉 Tap the Cart icon, then tap 'Proceed to Checkout'",
        ),
        const TutorialStep(
          title: "Live Order Tracking 🛵",
          description: "Track your delivery rider in real time on our interactive map from kitchen to doorstep.",
          icon: Icons.two_wheeler_rounded,
          color: Color(0xFFF59E0B),
          targetActionHint: "👉 Check 'My Orders' tab to track active deliveries",
        ),
      ];

  @override
  State<TutorialGuideModal> createState() => _TutorialGuideModalState();
}

class _TutorialGuideModalState extends State<TutorialGuideModal> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    final currentStep = widget.steps[_currentIndex];

    if (currentStep.routeName != null) {
      Navigator.pop(context); // Close modal
      Navigator.pushReplacementNamed(context, currentStep.routeName!);
      return;
    }

    if (_currentIndex < widget.steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (widget.onFinished != null) {
        widget.onFinished!();
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = widget.steps[_currentIndex];
    final isLastStep = _currentIndex == widget.steps.length - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Container(
        width: 450,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Color(0xFFE91E63), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      widget.roleTitle,
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Skip", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final step = widget.steps[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: step.color.withAlpha(25),
                            shape: BoxShape.circle,
                            border: Border.all(color: step.color.withAlpha(60), width: 2),
                          ),
                          child: step.assetImagePath != null
                              ? Image.asset(
                                  step.assetImagePath!,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.contain,
                                )
                              : Icon(step.icon ?? Icons.star, size: 56, color: step.color),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          step.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        if (step.targetActionHint != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: step.color.withAlpha(15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: step.color.withAlpha(50)),
                            ),
                            child: Text(
                              step.targetActionHint!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: step.color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Footer / Dots & Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    widget.steps.length,
                    (index) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: _currentIndex == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index ? const Color(0xFFE91E63) : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    currentStep.routeName != null ? "GO THERE NOW" : (isLastStep ? "GET STARTED" : "NEXT"),
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
