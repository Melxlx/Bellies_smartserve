import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class PremiumPinkHeader extends StatelessWidget {
  final String currentLocation;
  final VoidCallback? onLocationTap;
  final String searchQuery;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchTap;
  final VoidCallback? onFilterTap;
  final Widget? notificationWidget;
  final VoidCallback? onAvatarTap;
  final String? avatarUrl;

  const PremiumPinkHeader({
    super.key,
    this.currentLocation = "Isabela",
    this.onLocationTap,
    this.searchQuery = "",
    this.onSearchChanged,
    this.onSearchTap,
    this.onFilterTap,
    this.notificationWidget,
    this.onAvatarTap,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF4FA0), Color(0xFFF72585)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Foodpanda Location Selector + BK HD Badge & Profile Avatar
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onLocationTap,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Current Location, $currentLocation",
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                if (notificationWidget != null) ...[notificationWidget!],

                const SizedBox(width: 8),

                // BK HD Brand Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "BK HD",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Avatar
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white24,
                      backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                          ? NetworkImage(avatarUrl!)
                          : null,
                      child: avatarUrl == null || avatarUrl!.isEmpty
                          ? const Icon(Icons.person_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Search Bar Row (Foodpanda Style White Pill Search Input)
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onSearchTap,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(21),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              searchQuery.isNotEmpty ? searchQuery : "Search Bellie's Kitchen...",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: searchQuery.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (searchQuery.isNotEmpty)
                            const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Filter Icon Button
                GestureDetector(
                  onTap: onFilterTap ?? onSearchTap,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
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
