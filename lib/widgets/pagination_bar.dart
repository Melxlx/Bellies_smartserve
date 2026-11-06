import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onRowsPerPageChanged;
  final List<int> rowsPerPageOptions;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
    this.onRowsPerPageChanged,
    this.rowsPerPageOptions = const [10, 25, 50],
  });

  List<int?> _getPageNumbers() {
    final List<int?> pages = [];
    final safeTotalPages = totalPages > 0 ? totalPages : 1;

    if (safeTotalPages <= 7) {
      for (int i = 1; i <= safeTotalPages; i++) {
        pages.add(i);
      }
    } else {
      pages.add(1);
      if (currentPage > 3) {
        pages.add(null); // Ellipsis
      }

      int start = (currentPage - 1).clamp(2, safeTotalPages - 1);
      int end = (currentPage + 1).clamp(2, safeTotalPages - 1);

      if (currentPage <= 3) {
        start = 2;
        end = 4;
      } else if (currentPage >= safeTotalPages - 2) {
        start = safeTotalPages - 3;
        end = safeTotalPages - 1;
      }

      for (int i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }

      if (currentPage < safeTotalPages - 2) {
        pages.add(null); // Ellipsis
      }
      if (!pages.contains(safeTotalPages)) {
        pages.add(safeTotalPages);
      }
    }
    return pages;
  }

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) return const SizedBox.shrink();

    final startIndex = ((currentPage - 1) * itemsPerPage) + 1;
    final endIndex = (currentPage * itemsPerPage < totalItems) ? (currentPage * itemsPerPage) : totalItems;
    final safeTotalPages = totalPages > 0 ? totalPages : 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        final countText = Text(
          "Showing $startIndex–$endIndex of $totalItems records",
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        );

        final rowsDropdown = onRowsPerPageChanged != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Rows per page:", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<int>(
                      value: itemsPerPage,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: rowsPerPageOptions.map((opt) {
                        return DropdownMenuItem<int>(
                          value: opt,
                          child: Text(opt.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && onRowsPerPageChanged != null) {
                          onRowsPerPageChanged!(val);
                        }
                      },
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink();

        final navControls = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous button
              OutlinedButton(
                onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: currentPage > 1 ? Colors.grey.shade300 : Colors.grey.shade200),
                ),
                child: const Text("Previous", style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),

              // Numbered pages with ellipses (only show if safeTotalPages > 1)
              if (safeTotalPages > 1) ..._getPageNumbers().map((p) {
                if (p == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text("...", style: TextStyle(color: Colors.grey)),
                  );
                }
                final isSelected = p == currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => onPageChanged(p),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE91E63) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade300),
                      ),
                      child: Text(
                        p.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(width: 6),
              // Next button
              OutlinedButton(
                onPressed: currentPage < safeTotalPages ? () => onPageChanged(currentPage + 1) : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(36, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: currentPage < safeTotalPages ? Colors.grey.shade300 : Colors.grey.shade200),
                ),
                child: const Text("Next", style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );

        if (isSmallScreen) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                countText,
                const SizedBox(height: 8),
                if (onRowsPerPageChanged != null) ...[
                  rowsDropdown,
                  const SizedBox(height: 8),
                ],
                navControls,
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  countText,
                  if (onRowsPerPageChanged != null) ...[
                    const SizedBox(width: 16),
                    rowsDropdown,
                  ],
                ],
              ),
              navControls,
            ],
          ),
        );
      },
    );
  }
}
