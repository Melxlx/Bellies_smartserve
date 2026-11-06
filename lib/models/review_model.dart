class ReviewModel {
  final String id;
  final String orderId;
  final String? customerId;
  final String customerName;
  final int foodRating;
  final int? deliveryRating;
  final String? comment;
  final String? ownerReply;
  final bool isRead;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.orderId,
    this.customerId,
    required this.customerName,
    required this.foodRating,
    this.deliveryRating,
    this.comment,
    this.ownerReply,
    this.isRead = false,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString() ?? 'Customer',
      foodRating: (json['food_rating'] as num? ?? 5).toInt(),
      deliveryRating: (json['delivery_rating'] as num?)?.toInt(),
      comment: json['comment']?.toString(),
      ownerReply: json['owner_reply']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'order_id': orderId,
      if (customerId != null) 'customer_id': customerId,
      'customer_name': customerName,
      'food_rating': foodRating,
      if (deliveryRating != null) 'delivery_rating': deliveryRating,
      if (comment != null) 'comment': comment,
      if (ownerReply != null) 'owner_reply': ownerReply,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedDate {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
