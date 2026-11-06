import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';

class ReviewRepository {
  final SupabaseClient _supabase;

  ReviewRepository({SupabaseClient? client})
      : _supabase = client ?? Supabase.instance.client;

  static List<ReviewModel> _cachedReviews = [];
  static final StreamController<List<ReviewModel>> _reviewsController =
      StreamController<List<ReviewModel>>.broadcast();
  static RealtimeChannel? _realtimeChannel;
  static bool _subscribed = false;

  void _ensureRealtimeSubscribed() {
    if (_subscribed) return;
    _subscribed = true;

    try {
      _realtimeChannel = _supabase
          .channel('public:order_reviews:repo')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'order_reviews',
            callback: (payload) async {
              try {
                final latest = await getAllReviews();
                _cachedReviews = latest;
                _notifyListeners();
              } catch (e) {
                debugPrint("Error in realtime reviews callback: $e");
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint("Error subscribing to realtime order_reviews: $e");
    }
  }

  static void _notifyListeners() {
    if (!_reviewsController.isClosed) {
      _reviewsController.add(List.unmodifiable(_cachedReviews));
    }
  }

  static void dispose() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    _subscribed = false;
  }

  /// Checks if a review already exists for a specific order
  Future<ReviewModel?> getReviewForOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('order_reviews')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();

      if (response != null) {
        return ReviewModel.fromJson(response);
      }
    } catch (e) {
      debugPrint("Error fetching review for order $orderId: $e");
    }
    return null;
  }

  /// Submits a new customer review
  Future<void> submitReview({
    required String orderId,
    String? customerId,
    required String customerName,
    required int foodRating,
    int? deliveryRating,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      'order_id': orderId,
      if (customerId != null && customerId.isNotEmpty) 'customer_id': customerId,
      'customer_name': customerName.trim().isNotEmpty ? customerName.trim() : 'Customer',
      'food_rating': foodRating,
      if (deliveryRating != null && deliveryRating > 0) 'delivery_rating': deliveryRating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    };

    final res = await _supabase.from('order_reviews').insert(payload).select().single();
    final model = ReviewModel.fromJson(res);
    _cachedReviews.insert(0, model);
    _notifyListeners();
  }

  /// Fetches all reviews for Owner Dashboard
  Future<List<ReviewModel>> getAllReviews() async {
    try {
      final response = await _supabase
          .from('order_reviews')
          .select()
          .order('created_at', ascending: false);

      final List list = response as List;
      final remoteList = list.map((json) => ReviewModel.fromJson(json)).toList();
      _cachedReviews = remoteList;
      return remoteList;
    } catch (e) {
      debugPrint("Error fetching all reviews: $e");
      return _cachedReviews;
    }
  }

  /// Safe real-time stream of all customer reviews with fallback
  Stream<List<ReviewModel>> streamReviews() async* {
    _ensureRealtimeSubscribed();

    // 1. Immediately yield cached reviews if present
    if (_cachedReviews.isNotEmpty) {
      yield List.unmodifiable(_cachedReviews);
    }

    // 2. Fetch fresh list from Supabase DB and yield
    try {
      final latest = await getAllReviews();
      _cachedReviews = latest;
      yield List.unmodifiable(_cachedReviews);
    } catch (e) {
      debugPrint("Error fetching DB reviews in streamReviews: $e");
      yield List.unmodifiable(_cachedReviews);
    }

    // 3. Yield any subsequent updates from broadcast controller
    yield* _reviewsController.stream;
  }

  /// Marks a review as read by Owner
  Future<void> markAsRead(String reviewId) async {
    try {
      await _supabase
          .from('order_reviews')
          .update({'is_read': true})
          .eq('id', reviewId);
    } catch (e) {
      debugPrint("Error marking review as read: $e");
    } finally {
      final idx = _cachedReviews.indexWhere((r) => r.id == reviewId);
      if (idx >= 0) {
        _cachedReviews[idx] = ReviewModel(
          id: _cachedReviews[idx].id,
          orderId: _cachedReviews[idx].orderId,
          customerId: _cachedReviews[idx].customerId,
          customerName: _cachedReviews[idx].customerName,
          foodRating: _cachedReviews[idx].foodRating,
          deliveryRating: _cachedReviews[idx].deliveryRating,
          comment: _cachedReviews[idx].comment,
          ownerReply: _cachedReviews[idx].ownerReply,
          isRead: true,
          createdAt: _cachedReviews[idx].createdAt,
        );
        _notifyListeners();
      }
    }
  }

  /// Owner reply to customer review
  Future<void> replyToReview(String reviewId, String replyText) async {
    await _supabase
        .from('order_reviews')
        .update({
          'owner_reply': replyText.trim(),
          'is_read': true,
        })
        .eq('id', reviewId);

    final idx = _cachedReviews.indexWhere((r) => r.id == reviewId);
    if (idx >= 0) {
      _cachedReviews[idx] = ReviewModel(
        id: _cachedReviews[idx].id,
        orderId: _cachedReviews[idx].orderId,
        customerId: _cachedReviews[idx].customerId,
        customerName: _cachedReviews[idx].customerName,
        foodRating: _cachedReviews[idx].foodRating,
        deliveryRating: _cachedReviews[idx].deliveryRating,
        comment: _cachedReviews[idx].comment,
        ownerReply: replyText.trim(),
        isRead: true,
        createdAt: _cachedReviews[idx].createdAt,
      );
      _notifyListeners();
    }
  }
}
