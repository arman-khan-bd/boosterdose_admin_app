import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/abandoned_order_model.dart';
import '../models/book_model.dart';
import '../models/courier_model.dart';
import '../models/notification_feed_model.dart';
import '../models/order_model.dart';
import '../models/overview_model.dart';
import '../models/review_model.dart';
import '../models/section_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  static Future<Map<String, String>> _getHeaders({bool requiresAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // --- Authentication ---

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: await _getHeaders(requiresAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
          'device_name': 'Android Admin Device',
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'];
        final user = UserModel.fromJson(data['user']);
        await AuthService.saveToken(token);
        await AuthService.saveUser(user);
        return {'success': true, 'user': user, 'message': data['message']};
      } else {
        throw ApiException(data['message'] ?? 'Login failed. Please check credentials.', response.statusCode);
      }
    } on SocketException {
      throw ApiException('সার্ভারে সংযোগ করা যাচ্ছে না। ইন্টারনেট কানেকশন বা ডোমেইন চেক করুন।');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('লগইন করতে সমস্যা হয়েছে: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await http.post(
        Uri.parse(ApiConfig.logout),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
    await AuthService.logout();
  }

  static Future<UserModel> getProfile() async {
    final response = await http.get(
      Uri.parse(ApiConfig.profile),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final user = UserModel.fromJson(data['user']);
      await AuthService.saveUser(user);
      return user;
    }
    throw ApiException(data['message'] ?? 'Failed to load profile');
  }

  static Future<UserModel> updateProfile({
    required String name,
    required String email,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
    };
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
      body['new_password'] = newPassword;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.profile),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final user = UserModel.fromJson(data['user']);
      await AuthService.saveUser(user);
      return user;
    }
    throw ApiException(data['message'] ?? 'Failed to update profile');
  }

  // --- Dashboard Overview ---

  static Future<OverviewData> getOverview() async {
    final response = await http.get(
      Uri.parse(ApiConfig.overview),
      headers: await _getHeaders(),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return OverviewData.fromJson(data);
    }
    throw ApiException(data['message'] ?? 'ড্যাশবোর্ড ডেটা লোড করতে ব্যর্থ হয়েছে।');
  }

  // --- Orders Manager ---

  static Future<Map<String, dynamic>> getOrders({
    String? search,
    String? status,
    String? paymentStatus,
    String? courier,
    int page = 1,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
    };
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (paymentStatus != null && paymentStatus.isNotEmpty) queryParams['payment_status'] = paymentStatus;
    if (courier != null && courier.isNotEmpty) queryParams['courier'] = courier;

    final uri = Uri.parse(ApiConfig.orders).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final orders = (data['orders'] as List? ?? [])
          .map((e) => OrderModel.fromJson(e))
          .toList();
      return {
        'orders': orders,
        'current_page': data['current_page'] ?? 1,
        'last_page': data['last_page'] ?? 1,
        'total': data['total'] ?? 0,
        'stats': data['stats'] ?? {},
      };
    }
    throw ApiException(data['message'] ?? 'Failed to load orders');
  }

  static Future<Map<String, dynamic>> getOrderDetail(int id) async {
    final response = await http.get(
      Uri.parse(ApiConfig.orderDetail(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'order': OrderModel.fromJson(data['order']),
        'customer_history': (data['customer_history'] as List? ?? [])
            .map((e) => OrderModel.fromJson(e))
            .toList(),
        'security': data['security'] ?? {},
      };
    }
    throw ApiException(data['message'] ?? 'Failed to load order detail');
  }

  static Future<OrderModel> updateOrderStatus(int id, String status) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.orderStatus(id)),
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return OrderModel.fromJson(data['order']);
    }
    throw ApiException(data['message'] ?? 'Failed to update order status');
  }

  static Future<OrderModel> updatePaymentStatus(int id, String paymentStatus) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.orderPaymentStatus(id)),
      headers: await _getHeaders(),
      body: jsonEncode({'payment_status': paymentStatus}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return OrderModel.fromJson(data['order']);
    }
    throw ApiException(data['message'] ?? 'Failed to update payment status');
  }

  static Future<OrderModel> updateOrderCourier(int id, {String? courierName, String? trackingCode}) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.orderCourier(id)),
      headers: await _getHeaders(),
      body: jsonEncode({
        'courier_name': courierName,
        'tracking_code': trackingCode,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return OrderModel.fromJson(data['order']);
    }
    throw ApiException(data['message'] ?? 'Failed to update courier');
  }

  static Future<Map<String, dynamic>> sendOrderToCourier(
    int id, {
    String courier = 'steadfast',
    String dispatchType = 'api',
    String? consignmentId,
  }) async {
    final body = <String, dynamic>{
      'courier': courier,
      'dispatch_type': dispatchType,
    };
    if (consignmentId != null && consignmentId.trim().isNotEmpty) {
      body['consignment_id'] = consignmentId.trim();
    }

    final response = await http.post(
      Uri.parse(ApiConfig.orderSendCourier(id)),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw ApiException(data['message'] ?? 'কুরিয়ারে পাঠাতে সমস্যা হয়েছে।');
  }

  static Future<bool> toggleBlockEntity(String type, String value) async {
    final response = await http.post(
      Uri.parse(ApiConfig.toggleBlock),
      headers: await _getHeaders(),
      body: jsonEncode({
        'type': type,
        'value': value,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['is_blocked'] ?? true;
    }
    throw ApiException(data['message'] ?? 'Failed to toggle block status');
  }

  // --- Abandoned Orders ---

  static Future<Map<String, dynamic>> getAbandonedOrders({
    String? search,
    String? recoveryStatus,
    int page = 1,
  }) async {
    final queryParams = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (recoveryStatus != null && recoveryStatus.isNotEmpty) queryParams['recovery_status'] = recoveryStatus;

    final uri = Uri.parse(ApiConfig.abandonedOrders).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final items = (data['abandoned_orders'] as List? ?? [])
          .map((e) => AbandonedOrderModel.fromJson(e))
          .toList();
      return {
        'abandoned_orders': items,
        'current_page': data['current_page'] ?? 1,
        'last_page': data['last_page'] ?? 1,
        'total': data['total'] ?? 0,
        'stats': data['stats'] ?? {},
      };
    }
    throw ApiException(data['message'] ?? 'Failed to load abandoned orders');
  }

  static Future<AbandonedOrderModel> updateAbandonedStatus(int id, String recoveryStatus, {String? notes}) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.abandonedOrderStatus(id)),
      headers: await _getHeaders(),
      body: jsonEncode({
        'recovery_status': recoveryStatus,
        if (notes != null) 'admin_notes': notes,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return AbandonedOrderModel.fromJson(data['abandoned_order']);
    }
    throw ApiException(data['message'] ?? 'Failed to update abandoned lead');
  }

  static Future<Map<String, dynamic>> convertAbandonedOrder(int id, [Map<String, dynamic>? orderData]) async {
    final response = await http.post(
      Uri.parse(ApiConfig.abandonedOrderConvert(id)),
      headers: await _getHeaders(),
      body: orderData != null ? jsonEncode(orderData) : null,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw ApiException(data['message'] ?? 'Failed to convert abandoned cart');
  }

  static Future<void> deleteAbandonedOrder(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.abandonedOrderDelete(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw ApiException(data['message'] ?? 'Failed to delete record');
    }
  }

  // --- Books Manager ---

  static Future<Map<String, dynamic>> uploadBookImage({
    required Uint8List bytes,
    required String filename,
    String type = 'cover',
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse(ApiConfig.bookUploadImage);

    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.fields['type'] = type;

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw ApiException(data['message'] ?? 'ছবি আপলোড করতে ব্যর্থ হয়েছে।');
  }

  static Future<List<BookModel>> getBooks() async {
    final response = await http.get(
      Uri.parse(ApiConfig.books),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return (data['books'] as List? ?? [])
          .map((e) => BookModel.fromJson(e))
          .toList();
    }
    throw ApiException(data['message'] ?? 'Failed to load books');
  }

  static Future<BookModel> createBook(Map<String, dynamic> bookData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.books),
      headers: await _getHeaders(),
      body: jsonEncode(bookData),
    );

    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return BookModel.fromJson(data['book']);
    }
    throw ApiException(data['message'] ?? 'Failed to create book');
  }

  static Future<BookModel> updateBook(int id, Map<String, dynamic> bookData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.bookDetail(id)),
      headers: await _getHeaders(),
      body: jsonEncode(bookData),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return BookModel.fromJson(data['book']);
    }
    throw ApiException(data['message'] ?? 'Failed to update book');
  }

  static Future<void> deleteBook(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.bookDetail(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw ApiException(data['message'] ?? 'Failed to delete book');
    }
  }

  // --- Customer Reviews ---

  static Future<Map<String, dynamic>> getReviews({String? status, int page = 1}) async {
    final queryParams = <String, String>{'page': page.toString()};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse(ApiConfig.reviews).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final reviews = (data['reviews'] as List? ?? [])
          .map((e) => ReviewModel.fromJson(e))
          .toList();
      return {
        'reviews': reviews,
        'current_page': data['current_page'] ?? 1,
        'last_page': data['last_page'] ?? 1,
        'total': data['total'] ?? 0,
        'stats': data['stats'] ?? {},
      };
    }
    throw ApiException(data['message'] ?? 'Failed to load reviews');
  }

  static Future<Map<String, dynamic>> publishReview(int id, {bool? isFeatured}) async {
    final body = <String, dynamic>{};
    if (isFeatured != null) body['is_featured'] = isFeatured;

    final response = await http.post(
      Uri.parse(ApiConfig.reviewPublish(id)),
      headers: await _getHeaders(),
      body: body.isNotEmpty ? jsonEncode(body) : null,
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'is_active': data['is_active'] ?? true,
        'review': data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
        'stats': data['stats'],
        'message': data['message'],
      };
    }
    throw ApiException(data['message'] ?? 'রিভিউ পাবলিশ করতে ব্যর্থ হয়েছে।');
  }

  static Future<Map<String, dynamic>> approveReview(int id) async {
    final response = await http.post(
      Uri.parse(ApiConfig.reviewApprove(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'is_active': data['is_active'] ?? true,
        'review': data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
        'stats': data['stats'],
        'message': data['message'],
      };
    }
    throw ApiException(data['message'] ?? 'রিভিউ অনুমোদন করতে ব্যর্থ হয়েছে।');
  }

  static Future<Map<String, dynamic>> toggleReviewActive(int id) async {
    final response = await http.post(
      Uri.parse(ApiConfig.reviewToggleActive(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'is_active': data['is_active'] ?? false,
        'review': data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
        'stats': data['stats'],
      };
    }
    throw ApiException(data['message'] ?? 'Failed to toggle review status');
  }

  static Future<Map<String, dynamic>> toggleReviewFeatured(int id) async {
    final response = await http.post(
      Uri.parse(ApiConfig.reviewToggleFeatured(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'is_featured': data['is_featured'] ?? false,
        'review': data['review'] != null ? ReviewModel.fromJson(data['review']) : null,
        'stats': data['stats'],
      };
    }
    throw ApiException(data['message'] ?? 'Failed to toggle featured status');
  }

  static Future<Map<String, dynamic>> deleteReview(int id) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.reviewDelete(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw ApiException(data['message'] ?? 'Failed to delete review');
    }
    return {
      'stats': data['stats'],
    };
  }

  static Future<Map<String, dynamic>> updateReview(
    int id,
    Map<String, dynamic> reviewData, {
    Uint8List? screenshotBytes,
    String? screenshotFilename,
  }) async {
    if (screenshotBytes != null) {
      final screenshotUrl = await uploadReviewScreenshot(
        screenshotBytes,
        screenshotFilename ?? 'review.jpg',
      );
      reviewData['screenshot_url'] = screenshotUrl;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.reviewDetail(id)),
      headers: await _getHeaders(),
      body: jsonEncode(reviewData),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return {
        'review': ReviewModel.fromJson(data['review']),
        'stats': data['stats'],
      };
    }
    throw ApiException(data['message'] ?? 'রিভিউ আপডেট করতে ব্যর্থ হয়েছে।');
  }

  static Future<String> uploadReviewScreenshot(Uint8List bytes, String filename) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse(ApiConfig.reviewUploadScreenshot);

    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['url'] ?? '';
    }
    throw ApiException(data['message'] ?? 'স্ক্রিনশট আপলোড করতে ব্যর্থ হয়েছে।');
  }

  static Future<Map<String, dynamic>> createReview(
    Map<String, dynamic> reviewData, {
    Uint8List? screenshotBytes,
    String? screenshotFilename,
  }) async {
    if (screenshotBytes != null) {
      final screenshotUrl = await uploadReviewScreenshot(
        screenshotBytes,
        screenshotFilename ?? 'review.jpg',
      );
      reviewData['screenshot_url'] = screenshotUrl;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.reviews),
      headers: await _getHeaders(),
      body: jsonEncode(reviewData),
    );

    final data = jsonDecode(response.body);
    if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
      return {
        'review': ReviewModel.fromJson(data['review']),
        'stats': data['stats'],
      };
    }
    throw ApiException(data['message'] ?? 'রিভিউ যুক্ত করতে ব্যর্থ হয়েছে।');
  }

  // --- Courier Manager ---

  static Future<CourierSettingsModel> getCouriers() async {
    final response = await http.get(
      Uri.parse(ApiConfig.couriers),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return CourierSettingsModel.fromJson(data);
    }
    throw ApiException(data['message'] ?? 'Failed to load courier settings');
  }

  static Future<void> updateCouriers(Map<String, dynamic> courierData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.couriers),
      headers: await _getHeaders(),
      body: jsonEncode(courierData),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw ApiException(data['message'] ?? 'Failed to save courier settings');
    }
  }

  static Future<Map<String, dynamic>> testCourierConnection({
    String courierProvider = 'steadfast',
    String? apiKey,
    String? secretKey,
    String? baseUrl,
  }) async {
    final body = <String, dynamic>{
      'courier_provider': courierProvider,
    };
    if (apiKey != null && apiKey.trim().isNotEmpty) body['steadfast_api_key'] = apiKey.trim();
    if (secretKey != null && secretKey.trim().isNotEmpty) body['steadfast_secret_key'] = secretKey.trim();
    if (baseUrl != null && baseUrl.trim().isNotEmpty) body['steadfast_base_url'] = baseUrl.trim();

    final response = await http.post(
      Uri.parse(ApiConfig.courierTest),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw ApiException(data['message'] ?? 'কুরিয়ার কানেকশন ভেরিফিকেশন ব্যর্থ হয়েছে।');
  }

  // --- Sections Data Manager ---

  static Future<Map<String, dynamic>> getSectionsData() async {
    final response = await http.get(
      Uri.parse(ApiConfig.sections),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final sections = (data['sections'] as List? ?? [])
          .map((e) => SectionModel.fromJson(e))
          .toList();
      final presetImages = (data['presetImages'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final books = data['books'] as List? ?? [];

      return {
        'sections': sections,
        'presetImages': presetImages,
        'books': books,
      };
    }
    throw ApiException(data['message'] ?? 'Failed to load sections');
  }

  static Future<List<SectionModel>> getSections() async {
    final res = await getSectionsData();
    return res['sections'] as List<SectionModel>;
  }

  static Future<bool> toggleSection(int id) async {
    final response = await http.patch(
      Uri.parse(ApiConfig.sectionToggle(id)),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return data['is_active'] ?? false;
    }
    throw ApiException(data['message'] ?? 'Failed to toggle section');
  }

  static Future<void> reorderSections(List<Map<String, dynamic>> orderList) async {
    final response = await http.post(
      Uri.parse(ApiConfig.sectionsReorder),
      headers: await _getHeaders(),
      body: jsonEncode({'orders': orderList}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw ApiException(data['message'] ?? 'Failed to reorder sections');
    }
  }

  static Future<SectionModel> updateSection(int id, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse(ApiConfig.sectionDetail(id)),
      headers: await _getHeaders(),
      body: jsonEncode(data),
    );

    final resData = jsonDecode(response.body);
    if (response.statusCode == 200 && resData['success'] == true) {
      return SectionModel.fromJson(resData['section']);
    }
    throw ApiException(resData['message'] ?? 'Failed to update section');
  }

  static Future<Map<String, dynamic>> uploadSectionImage(
    int id, {
    required Uint8List bytes,
    required String filename,
    String targetField = 'image_url',
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse(ApiConfig.sectionImage(id));

    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.fields['target_field'] = targetField;

    request.files.add(
      http.MultipartFile.fromBytes(
        'image_file',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data;
    }
    throw ApiException(data['message'] ?? 'ছবি আপলোড করতে ব্যর্থ হয়েছে।');
  }

  static Future<String> uploadSectionMedia({
    required Uint8List bytes,
    required String filename,
  }) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse(ApiConfig.sectionUploadMedia);

    final request = http.MultipartRequest('POST', uri);
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';

    request.files.add(
      http.MultipartFile.fromBytes(
        'image_file',
        bytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return data['url'] ?? data['image_url'] ?? '';
    }
    throw ApiException(data['message'] ?? 'ছবি আপলোড করতে সমস্যা হয়েছে।');
  }

  static Future<SectionModel> resetSectionImage(int id, {String targetField = 'image_url'}) async {
    final response = await http.post(
      Uri.parse(ApiConfig.sectionResetImage(id)),
      headers: await _getHeaders(),
      body: jsonEncode({'target_field': targetField}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return SectionModel.fromJson(data['section']);
    }
    throw ApiException(data['message'] ?? 'ডিফল্ট ছবি রিসেট করতে ব্যর্থ হয়েছে।');
  }

  static Future<SectionModel> saveHeroSection(Map<String, dynamic> heroData) async {
    final response = await http.post(
      Uri.parse(ApiConfig.heroSection),
      headers: await _getHeaders(),
      body: jsonEncode(heroData),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      return SectionModel.fromJson(data['hero']);
    }
    throw ApiException(data['message'] ?? 'হিরো সেকশন সংরক্ষণ ব্যর্থ হয়েছে।');
  }

  // --- Notification Manager ---

  static Future<Map<String, dynamic>> getNotificationFeed() async {
    final response = await http.get(
      Uri.parse(ApiConfig.notificationsFeed),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      final counts = NotificationCounts.fromJson(data['counts'] ?? {});
      final items = (data['items'] as List? ?? [])
          .map((e) => NotificationItem.fromJson(e))
          .toList();
      return {
        'counts': counts,
        'items': items,
      };
    }
    throw ApiException(data['message'] ?? 'Failed to load notification feed');
  }

  static Future<void> testNotification() async {
    final response = await http.post(
      Uri.parse(ApiConfig.notificationTest),
      headers: await _getHeaders(),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200 || data['success'] != true) {
      throw ApiException(data['message'] ?? 'Failed to send test notification');
    }
  }
}
