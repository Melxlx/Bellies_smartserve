import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/state_widgets.dart';
import 'inventory_dashboard_screen.dart';
import 'inventory_screen.dart';

class InventoryHubScreen extends StatefulWidget {
  const InventoryHubScreen({super.key});

  @override
  State<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _InventoryHubScreenState extends State<InventoryHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && _selectedIndex != _tabController.index) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 700;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF4F6F9),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isMobile ? 135 : 105),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const SmartBackButton(),
                      const SizedBox(width: 12),
                      
                      // High-Tech Icon Badge
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE91E63).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title & Subtitle Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Inventory Management",
                                style: GoogleFonts.poppins(
                                  fontSize: isMobile ? 18 : 22,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 10),
                              // Realtime Live Dot Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "LIVE SYNC",
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Track stock levels, raw ingredients & realtime movement logs",
                            style: GoogleFonts.inter(
                              fontSize: isMobile ? 11 : 12,
                              color: isDark ? Colors.grey.shade400 : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      if (!isMobile) ...[
                        const Spacer(),
                        _buildSegmentedControl(isDark: isDark, isMobile: false),
                      ],
                    ],
                  ),

                  // Mobile Segmented Control (Below Title)
                  if (isMobile) ...[
                    const SizedBox(height: 10),
                    _buildSegmentedControl(isDark: isDark, isMobile: true),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const InventoryScreen(),
          const InventoryDashboardScreen(showHistoryOnly: true, showSummaryOnly: false),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl({required bool isDark, required bool isMobile}) {
    return Container(
      height: 44,
      width: isMobile ? double.infinity : 380,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black38 : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          _buildSegmentTab(
            index: 0,
            label: "Stock Control",
            icon: Icons.inventory_2_outlined,
            activeIcon: Icons.inventory_2_rounded,
            isDark: isDark,
          ),
          _buildSegmentTab(
            index: 1,
            label: "Movement Logs",
            icon: Icons.history_toggle_off_outlined,
            activeIcon: Icons.history_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() => _selectedIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF333336) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFFE91E63)
                    : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.textPrimary)
                      : (isDark ? Colors.grey.shade400 : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
