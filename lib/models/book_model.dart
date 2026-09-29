import '../widgets/app_network_image.dart';

class BookModel {
  final int id;
  final String title;
  final String? subtitle;
  final String? slug;
  final String author;
  final String? category;
  final String? description;
  final double price;
  final double discountPrice;
  final double effectivePrice;
  final int stockCount;
  final String stockStatus; // 'in_stock', 'limited_stock', 'out_of_stock'
  final bool isActive;
  final int pages;
  final String? edition;
  final String? badge;
  final String? paperQuality;
  final String? bindingType;
  final bool freeDelivery;
  final bool isCombo;
  final bool isFeatured;
  final String? coverImage;
  final String? coverImageRaw;
  final List<String> galleryImages;
  final List<String> galleryImagesRaw;
  final String? samplePdfUrl;
  final List<String> features;
  final List<String> packageItems;
  final List<String> freeGifts;
  final int ordersCount;
  final int totalSold;
  final String? createdAt;
  final String? updatedAt;

  // Compatibility getter for legacy code
  int get stock => stockCount;

  bool get isInStock => stockStatus == 'in_stock' && stockCount > 0;
  bool get isLimitedStock => stockStatus == 'limited_stock';
  bool get isOutOfStock => stockStatus == 'out_of_stock' || stockCount <= 0;

  String? fullCoverUrl([String? baseUrl]) {
    final raw = coverImage ?? coverImageRaw;
    if (raw == null || raw.trim().isEmpty) return null;
    return AppNetworkImage.normalizeUrl(raw, baseUrl: baseUrl);
  }

  List<String> fullGalleryUrls([String? baseUrl]) {
    final list = galleryImages.isNotEmpty ? galleryImages : galleryImagesRaw;
    return list
        .map((url) => AppNetworkImage.normalizeUrl(url, baseUrl: baseUrl))
        .whereType<String>()
        .toList();
  }

  BookModel({
    required this.id,
    required this.title,
    this.subtitle,
    this.slug,
    this.author = 'মো. সুমন হাসান',
    this.category,
    this.description,
    required this.price,
    required this.discountPrice,
    double? effectivePrice,
    required this.stockCount,
    this.stockStatus = 'in_stock',
    required this.isActive,
    this.pages = 0,
    this.edition,
    this.badge,
    this.paperQuality,
    this.bindingType,
    this.freeDelivery = false,
    this.isCombo = false,
    required this.isFeatured,
    this.coverImage,
    this.coverImageRaw,
    this.galleryImages = const [],
    this.galleryImagesRaw = const [],
    this.samplePdfUrl,
    this.features = const [],
    this.packageItems = const [],
    this.freeGifts = const [],
    required this.ordersCount,
    required this.totalSold,
    this.createdAt,
    this.updatedAt,
  }) : effectivePrice = effectivePrice ?? (discountPrice > 0 ? discountPrice : price);

  factory BookModel.fromJson(Map<String, dynamic> json) {
    final rawPrice = _toDouble(json['price']);
    final rawDiscount = _toDouble(json['discount_price']);

    int stockVal = 0;
    if (json['stock_count'] != null) {
      stockVal = json['stock_count'] is int ? json['stock_count'] : int.tryParse(json['stock_count'].toString()) ?? 0;
    } else if (json['stock'] != null) {
      stockVal = json['stock'] is int ? json['stock'] : int.tryParse(json['stock'].toString()) ?? 0;
    }

    String status = json['stock_status']?.toString() ?? (stockVal > 0 ? 'in_stock' : 'out_of_stock');
    bool active = json['is_active'] == true || json['is_active'] == 1 || status != 'out_of_stock';

    return BookModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      slug: json['slug'],
      author: json['author'] ?? 'মো. সুমন হাসান',
      category: json['category'],
      description: json['description'],
      price: rawPrice,
      discountPrice: rawDiscount,
      effectivePrice: _toDouble(json['effective_price']) > 0
          ? _toDouble(json['effective_price'])
          : (rawDiscount > 0 ? rawDiscount : rawPrice),
      stockCount: stockVal,
      stockStatus: status,
      isActive: active,
      pages: json['pages'] is int ? json['pages'] : int.tryParse(json['pages']?.toString() ?? '0') ?? 0,
      edition: json['edition'],
      badge: json['badge'],
      paperQuality: json['paper_quality'],
      bindingType: json['binding_type'],
      freeDelivery: json['free_delivery'] == true || json['free_delivery'] == 1 || json['free_delivery'] == '1',
      isCombo: json['is_combo'] == true || json['is_combo'] == 1 || json['is_combo'] == '1',
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1 || json['is_featured'] == '1',
      coverImage: json['cover_image'],
      coverImageRaw: json['cover_image_raw'],
      galleryImages: _toStringList(json['gallery_images']),
      galleryImagesRaw: _toStringList(json['gallery_images_raw']),
      samplePdfUrl: json['sample_pdf_url'],
      features: _toStringList(json['features']),
      packageItems: _toStringList(json['package_items']),
      freeGifts: _toStringList(json['free_gifts']),
      ordersCount: json['orders_count'] is int ? json['orders_count'] : int.tryParse(json['orders_count']?.toString() ?? '0') ?? 0,
      totalSold: json['total_sold'] is int ? json['total_sold'] : int.tryParse(json['total_sold']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subtitle': subtitle,
      'slug': slug,
      'author': author,
      'category': category,
      'description': description,
      'price': price,
      'discount_price': discountPrice,
      'stock_count': stockCount,
      'stock_status': stockStatus,
      'pages': pages,
      'edition': edition,
      'badge': badge,
      'paper_quality': paperQuality,
      'binding_type': bindingType,
      'free_delivery': freeDelivery,
      'is_combo': isCombo,
      'is_featured': isFeatured,
      'cover_image': coverImage,
      'gallery_images': galleryImages,
      'sample_pdf_url': samplePdfUrl,
      'features': features,
      'package_items': packageItems,
      'free_gifts': freeGifts,
    };
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static List<String> _toStringList(dynamic v) {
    if (v == null) return [];
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }
}
