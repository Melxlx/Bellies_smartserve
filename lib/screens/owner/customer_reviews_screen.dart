import 'package:flutter/material.dart';
import '../../models/review_model.dart';
import '../../repositories/review_repository.dart';
import '../../widgets/state_widgets.dart';

class CustomerReviewsScreen extends StatefulWidget {
  const CustomerReviewsScreen({super.key});

  @override
  State<CustomerReviewsScreen> createState() => _CustomerReviewsScreenState();
}

class _CustomerReviewsScreenState extends State<CustomerReviewsScreen> {
  final _reviewRepo = ReviewRepository();
  int _filterTab = 0; // 0: All, 1: 5 Stars, 2: 4 Stars, 3: 1-3 Stars

  void _showReplyDialog(ReviewModel review) {
    final replyController = TextEditingController(text: review.ownerReply ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Official Owner Reply to ${review.customerName}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Review: \"${review.comment ?? 'No comment text'}\"", style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: replyController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Type your response to the customer...",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await _reviewRepo.replyToReview(review.id, replyController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Reply posted successfully!"), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC2416C),
              foregroundColor: Colors.white,
            ),
            child: const Text("POST REPLY"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customer Reviews & Ratings"),
        backgroundColor: const Color(0xFFC2416C),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<ReviewModel>>(
        stream: _reviewRepo.streamReviews(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return ErrorState(error: snapshot.error.toString(), onRetry: () => setState(() {}));
          if (!snapshot.hasData) return const LoadingState();

          final allReviews = snapshot.data!;
          final double avgRating = allReviews.isEmpty
              ? 5.0
              : allReviews.fold(0.0, (sum, r) => sum + r.foodRating) / allReviews.length;
          final int unreadCount = allReviews.where((r) => !r.isRead).length;

          var filteredList = allReviews;
          if (_filterTab == 1) {
            filteredList = allReviews.where((r) => r.foodRating == 5).toList();
          } else if (_filterTab == 2) {
            filteredList = allReviews.where((r) => r.foodRating == 4).toList();
          } else if (_filterTab == 3) {
            filteredList = allReviews.where((r) => r.foodRating <= 3).toList();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: const Color(0xFFFFF8E7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFFDE68A)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 28),
                                  SizedBox(width: 8),
                                  Text("Average Store Rating", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "${avgRating.toStringAsFixed(1)} / 5.0",
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFB8860B)),
                              ),
                              Text("${allReviews.length} Total Ratings", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Card(
                        color: unreadCount > 0 ? Colors.orange.shade50 : Colors.blue.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: unreadCount > 0 ? Colors.orange.shade200 : Colors.blue.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.mark_email_unread_outlined, color: unreadCount > 0 ? Colors.orange.shade800 : Colors.blue.shade800, size: 28),
                                  const SizedBox(width: 8),
                                  Text("New / Unread", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: unreadCount > 0 ? Colors.orange.shade900 : Colors.blue.shade900)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "$unreadCount Unread",
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: unreadCount > 0 ? Colors.orange.shade900 : Colors.blue.shade900),
                              ),
                              const Text("Real-time customer feedback", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip(
                        0,
                        "ALL REVIEWS (${allReviews.length})",
                        Icons.rate_review_rounded,
                        const Color(0xFFC2416C),
                      ),
                      const SizedBox(width: 10),
                      _filterChip(
                        1,
                        "5 STARS (${allReviews.where((r) => r.foodRating == 5).length})",
                        Icons.star_rounded,
                        const Color(0xFFD4AF37),
                      ),
                      const SizedBox(width: 10),
                      _filterChip(
                        2,
                        "4 STARS (${allReviews.where((r) => r.foodRating == 4).length})",
                        Icons.star_half_rounded,
                        Colors.orange.shade700,
                      ),
                      const SizedBox(width: 10),
                      _filterChip(
                        3,
                        "1-3 STARS (${allReviews.where((r) => r.foodRating <= 3).length})",
                        Icons.warning_amber_rounded,
                        Colors.red.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Reviews List
                filteredList.isEmpty
                    ? const EmptyState(message: "No reviews found for this filter.")
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final review = filteredList[index];
                          return _buildReviewCard(review);
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(int index, String label, IconData icon, Color activeColor) {
    final bool isSelected = _filterTab == index;
    return InkWell(
      onTap: () => setState(() => _filterTab = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFCBD5E1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(50),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : activeColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: review.isRead ? Colors.grey.shade200 : const Color(0xFFFDE68A),
          width: review.isRead ? 1 : 1.5,
        ),
      ),
      color: review.isRead ? Colors.white : const Color(0xFFFFFDF5),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFC2416C).withAlpha(20),
                      child: const Icon(Icons.person, color: Color(0xFFC2416C), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(review.formattedDate, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Food Rating", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < review.foodRating ? Icons.star_rounded : Icons.star_border_rounded,
                          color: const Color(0xFFD4AF37),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  "\"${review.comment!}\"",
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.4),
                ),
              ),
            ],
            if (review.ownerReply != null && review.ownerReply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD1DC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.reply_rounded, size: 14, color: Color(0xFFC2416C)),
                        SizedBox(width: 4),
                        Text("Official Store Reply:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC2416C))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(review.ownerReply!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (review.deliveryRating != null)
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text("Delivery Rating: ${review.deliveryRating}/5 ⭐", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    if (!review.isRead)
                      IconButton(
                        tooltip: "Mark as Read",
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        onPressed: () async {
                          await _reviewRepo.markAsRead(review.id);
                        },
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _showReplyDialog(review),
                      icon: const Icon(Icons.reply_rounded, size: 14),
                      label: Text(review.ownerReply == null ? "REPLY" : "EDIT REPLY", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC2416C),
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
          ],
        ),
      ),
    );
  }
}
