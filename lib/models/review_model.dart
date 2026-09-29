import '../widgets/app_network_image.dart';

class ReviewModel {
  final int id;
  final int? bookId;
  final String reviewerName;
  final String? designation;
  final int rating;
  final String? comment;
  final String? screenshotUrl;
  final bool isActive;
  final bool isFeatured;
  final String? source;
  final String? sourceLabel;
  final bool hasScreenshot;
  final String? createdAt;
  final Map<String, dynamic>? book;

  ReviewModel({
    required this.id,
    this.bookId,
    required this.reviewerName,
    this.designation,
    required this.rating,
    this.comment,
    this.screenshotUrl,
    required this.isActive,
    required this.isFeatured,
    this.source,
    this.sourceLabel,
    this.hasScreenshot = false,
    this.createdAt,
    this.book,
  });

  String get bookTitle {
    if (book != null && book!['title'] != null) {
      return book!['title'].toString();
    }
    return '';
  }

  String? fullScreenshotUrl([String? baseUrl]) {
    if (screenshotUrl == null || screenshotUrl!.trim().isEmpty) return null;
    return AppNetworkImage.normalizeUrl(screenshotUrl, baseUrl: baseUrl);
  }

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final rawScreenshot = json['screenshot_url']?.toString();
    final hasImg = (rawScreenshot != null && rawScreenshot.isNotEmpty) || json['has_screenshot'] == true;

    return ReviewModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      bookId: json['book_id'] != null ? int.tryParse(json['book_id'].toString()) : null,
      reviewerName: json['reviewer_name'] != null && json['reviewer_name'].toString().trim().isNotEmpty
          ? json['reviewer_name'].toString().trim()
          : 'সম্মানিত শিক্ষার্থী',
      designation: json['designation']?.toString(),
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating']?.toString() ?? '5') ?? 5,
      comment: json['comment']?.toString(),
      screenshotUrl: rawScreenshot,
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      isFeatured: json['is_featured'] == true || json['is_featured'] == 1 || json['is_featured'] == '1',
      source: json['source']?.toString(),
      sourceLabel: json['source_label']?.toString(),
      hasScreenshot: hasImg,
      createdAt: json['created_at']?.toString(),
      book: json['book'] is Map<String, dynamic> ? json['book'] : null,
    );
  }

  ReviewModel copyWith({
    int? id,
    int? bookId,
    String? reviewerName,
    String? designation,
    int? rating,
    String? comment,
    String? screenshotUrl,
    bool? isActive,
    bool? isFeatured,
    String? source,
    String? sourceLabel,
    bool? hasScreenshot,
    String? createdAt,
    Map<String, dynamic>? book,
  }) {
    return ReviewModel(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      reviewerName: reviewerName ?? this.reviewerName,
      designation: designation ?? this.designation,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      screenshotUrl: screenshotUrl ?? this.screenshotUrl,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      source: source ?? this.source,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      hasScreenshot: hasScreenshot ?? this.hasScreenshot,
      createdAt: createdAt ?? this.createdAt,
      book: book ?? this.book,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'reviewer_name': reviewerName,
      'designation': designation,
      'rating': rating,
      'comment': comment,
      'screenshot_url': screenshotUrl,
      'is_active': isActive,
      'is_featured': isFeatured,
      'source': source,
    };
  }
}
