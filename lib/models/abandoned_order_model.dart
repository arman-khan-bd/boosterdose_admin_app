class AbandonedOrderModel {
  final int id;
  final int? bookId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? deliveryAddress;
  final String? deliveryArea;
  final double deliveryCharge;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String recoveryStatus;
  final String? adminNotes;
  final String? ipAddress;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? book;

  AbandonedOrderModel({
    required this.id,
    this.bookId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.deliveryAddress,
    this.deliveryArea,
    required this.deliveryCharge,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.recoveryStatus,
    this.adminNotes,
    this.ipAddress,
    this.createdAt,
    this.updatedAt,
    this.book,
  });

  factory AbandonedOrderModel.fromJson(Map<String, dynamic> json) {
    final total = _toDouble(json['total_amount']);
    final uPrice = _toDouble(json['unit_price'] ?? (json['book'] is Map ? (json['book']['discount_price'] ?? json['book']['price']) : null));
    final qty = json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1;
    double dCharge = _toDouble(json['delivery_charge']);
    if (dCharge <= 0 && total > 0 && uPrice > 0) {
      final diff = total - (uPrice * qty);
      if (diff > 0) dCharge = diff;
    }

    final fullAddress = (json['delivery_address'] ?? json['shipping_address'])?.toString();

    return AbandonedOrderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      bookId: json['book_id'] != null ? int.tryParse(json['book_id'].toString()) : null,
      customerName: json['customer_name'] ?? 'নামহীন লিড',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'],
      deliveryAddress: fullAddress,
      deliveryArea: json['delivery_area'],
      deliveryCharge: dCharge,
      quantity: qty,
      unitPrice: uPrice > 0 ? uPrice : _toDouble(json['unit_price']),
      totalAmount: total,
      recoveryStatus: json['recovery_status'] ?? 'pending',
      adminNotes: json['admin_notes'],
      ipAddress: json['ip_address'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      book: json['book'] is Map<String, dynamic> ? json['book'] : null,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String get bookTitle => book?['title'] ?? 'মাস্টারবুক';
  String? get shippingAddress => deliveryAddress;

  DateTime? get createdDateTime {
    if (createdAt == null || createdAt!.isEmpty) return null;
    final normalized = createdAt!.contains('T') ? createdAt! : createdAt!.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized);
  }

  /// Whether 5 minutes have elapsed since this lead was created without an order being placed
  bool get isOlderThan5Minutes {
    final dt = createdDateTime;
    if (dt == null) return true;
    final now = dt.isUtc ? DateTime.now().toUtc() : DateTime.now();
    return now.difference(dt).inSeconds >= (5 * 60);
  }

  /// Minutes elapsed since creation
  int get minutesSinceCreation {
    final dt = createdDateTime;
    if (dt == null) return 999;
    final now = dt.isUtc ? DateTime.now().toUtc() : DateTime.now();
    return now.difference(dt).inMinutes;
  }

  /// Formatted lead text (name, phone, address, book, amount)
  String get copyableLeadData {
    final sb = StringBuffer();
    sb.writeln('নাম: $customerName');
    sb.writeln('ফোন: $customerPhone');
    if (deliveryAddress != null && deliveryAddress!.trim().isNotEmpty) {
      sb.writeln('ঠিকানা: $deliveryAddress');
    }
    if (deliveryArea != null && deliveryArea!.trim().isNotEmpty) {
      sb.writeln('এরিয়া: $deliveryArea');
    }
    sb.writeln('পণ্য: $bookTitle (x$quantity)');
    sb.writeln('মূল্য: ৳${totalAmount.toStringAsFixed(0)}');
    return sb.toString().trim();
  }
}
