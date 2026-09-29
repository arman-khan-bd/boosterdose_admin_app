import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/review_model.dart';
import '../services/api_service.dart';

class ReviewProvider extends ChangeNotifier {
  List<ReviewModel> _reviews = [];
  Map<String, dynamic> _stats = {};
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _isLoading = false;
  String? _errorMessage;

  String _filter = 'all';

  List<ReviewModel> get reviews => _reviews;
  Map<String, dynamic> get stats => _stats;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get filter => _filter;

  Future<void> fetchReviews({int page = 1, bool refresh = false}) async {
    if (refresh) page = 1;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.getReviews(
        status: _filter == 'all' ? null : _filter,
        page: page,
      );

      _reviews = result['reviews'];
      _currentPage = result['current_page'];
      _lastPage = result['last_page'];
      _total = result['total'];
      _stats = result['stats'];
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _filter = filter;
    fetchReviews(refresh: true);
  }

  Future<bool> publishReview(int id, {bool? isFeatured}) async {
    try {
      final result = await ApiService.publishReview(id, isFeatured: isFeatured);
      final ReviewModel? updated = result['review'];
      final index = _reviews.indexWhere((r) => r.id == id);
      if (index != -1) {
        if (updated != null) {
          _reviews[index] = updated;
        } else {
          _reviews[index] = _reviews[index].copyWith(isActive: true);
        }
      }
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> approveReview(int id) async {
    try {
      final result = await ApiService.approveReview(id);
      final ReviewModel? updated = result['review'];
      final index = _reviews.indexWhere((r) => r.id == id);
      if (index != -1) {
        if (updated != null) {
          _reviews[index] = updated;
        } else {
          _reviews[index] = _reviews[index].copyWith(isActive: true);
        }
      }
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleActive(int id) async {
    try {
      final result = await ApiService.toggleReviewActive(id);
      final newStatus = result['is_active'] as bool? ?? false;
      final ReviewModel? updated = result['review'];
      final index = _reviews.indexWhere((r) => r.id == id);
      if (index != -1) {
        if (updated != null) {
          _reviews[index] = updated;
        } else {
          _reviews[index] = _reviews[index].copyWith(isActive: newStatus);
        }
      }
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleFeatured(int id) async {
    try {
      final result = await ApiService.toggleReviewFeatured(id);
      final newStatus = result['is_featured'] as bool? ?? false;
      final ReviewModel? updated = result['review'];
      final index = _reviews.indexWhere((r) => r.id == id);
      if (index != -1) {
        if (updated != null) {
          _reviews[index] = updated;
        } else {
          _reviews[index] = _reviews[index].copyWith(isFeatured: newStatus);
        }
      }
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<ReviewModel?> updateReview(
    int id,
    Map<String, dynamic> reviewData, {
    Uint8List? screenshotBytes,
    String? screenshotFilename,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await ApiService.updateReview(
        id,
        reviewData,
        screenshotBytes: screenshotBytes,
        screenshotFilename: screenshotFilename,
      );

      final ReviewModel updated = result['review'];
      final index = _reviews.indexWhere((r) => r.id == id);
      if (index != -1) {
        _reviews[index] = updated;
      }
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      _errorMessage = null;
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ReviewModel?> createReview(
    Map<String, dynamic> reviewData, {
    Uint8List? screenshotBytes,
    String? screenshotFilename,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await ApiService.createReview(
        reviewData,
        screenshotBytes: screenshotBytes,
        screenshotFilename: screenshotFilename,
      );

      final ReviewModel created = result['review'];
      _reviews.insert(0, created);
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      _errorMessage = null;
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteReview(int id) async {
    try {
      final result = await ApiService.deleteReview(id);
      _reviews.removeWhere((r) => r.id == id);
      if (result['stats'] != null && result['stats'] is Map<String, dynamic>) {
        _stats = Map<String, dynamic>.from(result['stats']);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
