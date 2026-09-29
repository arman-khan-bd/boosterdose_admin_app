import 'package:flutter/material.dart';
import '../models/overview_model.dart';
import '../services/api_service.dart';

class DashboardProvider extends ChangeNotifier {
  OverviewData? _data;
  bool _isLoading = false;
  String? _errorMessage;

  OverviewData? get data => _data;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchDashboardData({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _data = await ApiService.getOverview();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
