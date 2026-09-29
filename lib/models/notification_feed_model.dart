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
    return NotificationItem(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'order',
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
