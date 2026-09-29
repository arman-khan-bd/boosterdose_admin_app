class DashboardStats {
  final int totalOrders;
  final double totalRevenue;
  final int todayOrders;
  final double todayRevenue;
  final int pendingOrders;
  final int processingOrders;
  final int shippedOrders;
  final int completedOrders;
  final int cancelledOrders;
  final int abandonedCount;
  final int recoveredCount;
  final double aov;

  DashboardStats({
    required this.totalOrders,
    required this.totalRevenue,
    required this.todayOrders,
    required this.todayRevenue,
    required this.pendingOrders,
    required this.processingOrders,
    required this.shippedOrders,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.abandonedCount,
    required this.recoveredCount,
    required this.aov,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalOrders: _toInt(json['total_orders']),
      totalRevenue: _toDouble(json['total_revenue']),
      todayOrders: _toInt(json['today_orders']),
      todayRevenue: _toDouble(json['today_revenue']),
      pendingOrders: _toInt(json['pending_orders']),
      processingOrders: _toInt(json['processing_orders']),
      shippedOrders: _toInt(json['shipped_orders']),
      completedOrders: _toInt(json['completed_orders']),
      cancelledOrders: _toInt(json['cancelled_orders']),
      abandonedCount: _toInt(json['abandoned_count']),
      recoveredCount: _toInt(json['recovered_count']),
      aov: _toDouble(json['aov']),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class DailyChartPoint {
  final String date;
  final String rawDate;
  final int orders;
  final double revenue;
  final int abandoned;

  DailyChartPoint({
    required this.date,
    required this.rawDate,
    required this.orders,
    required this.revenue,
    required this.abandoned,
  });

  factory DailyChartPoint.fromJson(Map<String, dynamic> json) {
    return DailyChartPoint(
      date: json['date'] ?? '',
      rawDate: json['raw_date'] ?? '',
      orders: DashboardStats._toInt(json['orders']),
      revenue: DashboardStats._toDouble(json['revenue']),
      abandoned: DashboardStats._toInt(json['abandoned']),
    );
  }
}

class StatusDistributionItem {
  final String status;
  final String label;
  final int count;
  final String colorHex;
  final double percent;

  StatusDistributionItem({
    required this.status,
    required this.label,
    required this.count,
    required this.colorHex,
    required this.percent,
  });

  factory StatusDistributionItem.fromJson(Map<String, dynamic> json) {
    return StatusDistributionItem(
      status: json['status'] ?? '',
      label: json['label'] ?? '',
      count: DashboardStats._toInt(json['count']),
      colorHex: json['color'] ?? '#3B82F6',
      percent: DashboardStats._toDouble(json['percent']),
    );
  }
}

class TopSellingBook {
  final int id;
  final String title;
  final String? coverImage;
  final double price;
  final double discountPrice;
  final int stock;
  final int totalSold;
  final double totalRevenue;

  TopSellingBook({
    required this.id,
    required this.title,
    this.coverImage,
    required this.price,
    required this.discountPrice,
    required this.stock,
    required this.totalSold,
    required this.totalRevenue,
  });

  factory TopSellingBook.fromJson(Map<String, dynamic> json) {
    return TopSellingBook(
      id: DashboardStats._toInt(json['id']),
      title: json['title'] ?? '',
      coverImage: json['cover_image'],
      price: DashboardStats._toDouble(json['price']),
      discountPrice: DashboardStats._toDouble(json['discount_price']),
      stock: DashboardStats._toInt(json['stock']),
      totalSold: DashboardStats._toInt(json['total_sold']),
      totalRevenue: DashboardStats._toDouble(json['total_revenue']),
    );
  }
}

class OverviewData {
  final DashboardStats stats;
  final List<DailyChartPoint> chartData;
  final List<StatusDistributionItem> statusDistribution;
  final List<TopSellingBook> topBooks;
  final List<Map<String, dynamic>> recentOrders;

  OverviewData({
    required this.stats,
    required this.chartData,
    required this.statusDistribution,
    required this.topBooks,
    required this.recentOrders,
  });

  factory OverviewData.fromJson(Map<String, dynamic> json) {
    return OverviewData(
      stats: DashboardStats.fromJson(json['stats'] ?? {}),
      chartData: (json['chart_data'] as List? ?? [])
          .map((e) => DailyChartPoint.fromJson(e))
          .toList(),
      statusDistribution: (json['status_distribution'] as List? ?? [])
          .map((e) => StatusDistributionItem.fromJson(e))
          .toList(),
      topBooks: (json['top_books'] as List? ?? [])
          .map((e) => TopSellingBook.fromJson(e))
          .toList(),
      recentOrders: (json['recent_orders'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
