class NotificationCounts {
  final int pendingOrders;
  final int pendingAbandoned;
  final int pendingReviews;
  final int totalUnread;

  NotificationCounts({
    required this.pendingOrders,
    required this.pendingAbandoned,
    required this.pendingReviews,
    required this.totalUnread,
  });

  factory NotificationCounts.fromJson(Map<String, dynamic> json) {
    return NotificationCounts(
      pendingOrders: _toInt(json['pending_orders']),
      pendingAbandoned: _toInt(json['pending_abandoned']),
      pendingReviews: _toInt(json['pending_reviews']),
      totalUnread: _toInt(json['total_unread']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

class NotificationItem {
  final String id;
  final String type; // 'order', 'abandoned_order', 'review'
  final int? orderId;
  final int? abandonedOrderId;
  final int? reviewId;
  final String title;
  final String customerName;
  final String customerPhone;
  final double amount;
  final String bookTitle;
  final String status;
  final int? rating;
  final String? comment;
  final String? createdAt;
  final String? timeAgo;

  NotificationItem({
    required this.id,
    required this.type,
    this.orderId,
    this.abandonedOrderId,
    this.reviewId,
    required this.title,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.bookTitle,
    required this.status,
    this.rating,
    this.comment,
    this.createdAt,
    this.timeAgo,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    int? parseId(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      return int.tryParse(val.toString());
    }

    final type = json['type']?.toString() ?? 'order';
    final rawId = json['id']?.toString() ?? '';

    // Extract ID if not explicitly provided in order_id
    int? ordId = parseId(json['order_id']);
    int? abId = parseId(json['abandoned_order_id']);
    int? revId = parseId(json['review_id']);

    if (ordId == null && type == 'order' && rawId.startsWith('order-')) {
      ordId = int.tryParse(rawId.replaceFirst('order-', ''));
    }
    if (abId == null && type == 'abandoned_order' && rawId.startsWith('abandoned-')) {
      abId = int.tryParse(rawId.replaceFirst('abandoned-', ''));
    }
    if (revId == null && type == 'review' && rawId.startsWith('review-')) {
      revId = int.tryParse(rawId.replaceFirst('review-', ''));
    }

    return NotificationItem(
      id: rawId,
      type: type,
      orderId: ordId,
      abandonedOrderId: abId,
      reviewId: revId,
      title: json['title'] ?? '',
      customerName: json['customer_name'] ?? json['reviewer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      amount: json['amount'] != null ? (double.tryParse(json['amount'].toString()) ?? 0.0) : 0.0,
      bookTitle: json['book_title'] ?? '',
      status: json['status']?.toString() ?? '',
      rating: json['rating'] != null ? int.tryParse(json['rating'].toString()) : null,
      comment: json['comment'],
      createdAt: json['created_at'],
      timeAgo: json['time_ago'],
    );
  }
}
