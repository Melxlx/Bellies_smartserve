import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../repositories/review_repository.dart';

class OrderRatingWidget extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String? customerId;

  const OrderRatingWidget({
    super.key,
    required this.orderId,
    required this.customerName,
    this.customerId,
  });

  @override
  State<OrderRatingWidget> createState() => _OrderRatingWidgetState();
}

class _OrderRatingWidgetState extends State<OrderRatingWidget> {
  final _reviewRepo = ReviewRepository();
  final _commentController = TextEditingController();

  int _selectedRating = 5;
  final int _selectedDeliveryRating = 5;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isDismissed = false;
  ReviewModel? _existingReview;

  @override
  void initState() {
    super.initState();
    _checkExistingReview();
  }

  Future<void> _checkExistingReview() async {
    try {
      final review = await _reviewRepo.getReviewForOrder(widget.orderId);
      if (mounted) {
        setState(() {
          _existingReview = review;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await _reviewRepo.submitReview(
        orderId: widget.orderId,
        customerId: widget.customerId,
        customerName: widget.customerName,
        foodRating: _selectedRating,
        deliveryRating: _selectedDeliveryRating,
        comment: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("⭐ Thank you for your feedback! Rating submitted."),
            backgroundColor: Colors.green,
          ),
        );
        _checkExistingReview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to submit rating: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Already reviewed view
    if (_existingReview != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Thank you for rating your order!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF15803D)),
                ),
                const Spacer(),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < _existingReview!.foodRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFD4AF37),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            if (_existingReview!.comment != null && _existingReview!.comment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Your review: \"${_existingReview!.comment!}\"",
                style: const TextStyle(fontSize: 12, color: Color(0xFF166534), fontStyle: FontStyle.italic),
              ),
            ],
            if (_existingReview!.ownerReply != null && _existingReview!.ownerReply!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Store Response:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                    const SizedBox(height: 2),
                    Text(_existingReview!.ownerReply!, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // New Rating Prompt (Optional / Skippable)
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Rate Your Food & Experience",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              IconButton(
                tooltip: "Skip / Dismiss",
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                onPressed: () => setState(() => _isDismissed = true),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "How was your food? Tap stars to rate (Optional)",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // Star Selection Bar
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = starValue),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starValue <= _selectedRating ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFD4AF37),
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),

          // Optional Comment Input
          TextField(
            controller: _commentController,
            enabled: !_isSubmitting,
            maxLines: 2,
            maxLength: 100,
            decoration: InputDecoration(
              hintText: "Add optional comment (max 100 chars)...",
              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE91E63))),
              counterStyle: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isSubmitting ? null : () => setState(() => _isDismissed = true),
                  child: const Text("SKIP FOR NOW", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(_isSubmitting ? "SUBMITTING..." : "SUBMIT RATING"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
