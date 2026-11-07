import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AlertType { success, error, warning, info }

class TopAlertBanner {
  static void show(
    BuildContext context, {
    required String message,
    String title = "Notification",
    AlertType type = AlertType.info,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    Color bg;
    Color border;
    Color textColor;
    IconData icon;

    switch (type) {
      case AlertType.success:
        bg = const Color(0xFFE8F8F0);
        border = const Color(0xFF2E9E6B);
        textColor = const Color(0xFF1B5E3F);
        icon = Icons.check_circle_rounded;
        break;
      case AlertType.error:
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFD32F2F);
        textColor = const Color(0xFFB71C1C);
        icon = Icons.error_rounded;
        break;
      case AlertType.warning:
        bg = const Color(0xFFFFF8E1);
        border = const Color(0xFFF08A24);
        textColor = const Color(0xFFE65100);
        icon = Icons.warning_rounded;
        break;
      case AlertType.info:
        bg = const Color(0xFFFFF0F5);
        border = const Color(0xFFE91E63);
        textColor = const Color(0xFF880E4F);
        icon = Icons.info_rounded;
        break;
    }

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1.0 - value) * -60),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: border.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: border, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.black87,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      try {
                        overlayEntry.remove();
                      } catch (_) {}
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      try {
        overlayEntry.remove();
      } catch (_) {}
    });
  }
}
