class OrderModel {
  final int id;
  final String orderNumber;
  final int? bookId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String deliveryAddress;
  final String? deliveryArea;
  final double deliveryCharge;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String status;
  final String? courierName;
  final String? trackingCode;
  final String? courierStatus;
  final String? notes;
  final String? ipAddress;
  final String? createdAt;
  final Map<String, dynamic>? book;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.bookId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.deliveryAddress,
    this.deliveryArea,
    required this.deliveryCharge,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.status,
    this.courierName,
    this.trackingCode,
    this.courierStatus,
    this.notes,
    this.ipAddress,
    this.createdAt,
    this.book,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final total = _toDouble(json['total_amount']);
    final uPrice = _toDouble(json['unit_price'] ?? (json['book'] is Map ? (json['book']['discount_price'] ?? json['book']['price']) : null));
    final qty = json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1;
    double dCharge = _toDouble(json['delivery_charge']);
    if (dCharge <= 0 && total > 0 && uPrice > 0) {
      final diff = total - (uPrice * qty);
      if (diff > 0) dCharge = diff;
    }

    final fullAddress = (json['delivery_address'] ?? json['shipping_address'] ?? '').toString();

    return OrderModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderNumber: json['order_number'] ?? '',
      bookId: json['book_id'] != null ? int.tryParse(json['book_id'].toString()) : null,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      customerEmail: json['customer_email'],
      deliveryAddress: fullAddress,
      deliveryArea: json['delivery_area'],
      deliveryCharge: dCharge,
      quantity: qty,
      unitPrice: uPrice > 0 ? uPrice : _toDouble(json['unit_price']),
      totalAmount: total,
      paymentMethod: json['payment_method'] ?? 'cod',
      paymentStatus: json['payment_status'] ?? 'pending',
      status: json['status'] ?? 'pending',
      courierName: json['courier_name'],
      trackingCode: json['tracking_code'] ?? json['consignment_id'],
      courierStatus: json['courier_status'],
      notes: json['notes'],
      ipAddress: json['ip_address'],
      createdAt: json['created_at'],
      book: json['book'] is Map<String, dynamic> ? json['book'] : null,
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String get bookTitle => book?['title'] ?? 'বই';
  String get shippingAddress => deliveryAddress;

  /// Formatted order text including customer name, phone, address, product, total and order number
  String get copyableOrderData {
    final sb = StringBuffer();
    sb.writeln('নাম: $customerName');
    sb.writeln('ফোন: $customerPhone');
    if (deliveryAddress.trim().isNotEmpty) {
      sb.writeln('ঠিকানা: $deliveryAddress');
    }
    if (deliveryArea != null && deliveryArea!.trim().isNotEmpty) {
      sb.writeln('এরিয়া: $deliveryArea');
    }
    sb.writeln('পণ্য: $bookTitle (x$quantity)');
    sb.writeln('মূল্য: ৳${totalAmount.toStringAsFixed(0)}');
    if (orderNumber.isNotEmpty) {
      sb.writeln('অর্ডার নম্বর: #$orderNumber');
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      sb.writeln('নোট: $notes');
    }
    return sb.toString().trim();
  }

  /// Compact customer-only details (name, phone, address)
  String get copyableCustomerInfo {
    final sb = StringBuffer();
    sb.writeln('নাম: $customerName');
    sb.writeln('ফোন: $customerPhone');
    if (deliveryAddress.trim().isNotEmpty) {
      sb.writeln('ঠিকানা: $deliveryAddress');
    }
    return sb.toString().trim();
  }
}
