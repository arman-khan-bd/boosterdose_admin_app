import 'package:flutter/material.dart';
import '../models/courier_model.dart';
import '../services/api_service.dart';

class CourierProvider extends ChangeNotifier {
  CourierSettingsModel? _settings;
  bool _isLoading = false;
  bool _isTesting = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastTestResult;

  CourierSettingsModel? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isTesting => _isTesting;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get lastTestResult => _lastTestResult;

  void clearTestResult() {
    _lastTestResult = null;
    notifyListeners();
  }

  Future<void> fetchCourierSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _settings = await ApiService.getCouriers();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSettings(Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await ApiService.updateCouriers(data);
      await fetchCourierSettings();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> testConnection({
    String courierProvider = 'steadfast',
    String? apiKey,
    String? secretKey,
    String? baseUrl,
  }) async {
    _isTesting = true;
    notifyListeners();

    try {
      final res = await ApiService.testCourierConnection(
        courierProvider: courierProvider,
        apiKey: apiKey,
        secretKey: secretKey,
        baseUrl: baseUrl,
      );
      _lastTestResult = res;
      return res;
    } catch (e) {
      _lastTestResult = {
        'success': false,
        'message': e.toString().replaceAll('Exception:', '').trim(),
      };
      rethrow;
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }
}
