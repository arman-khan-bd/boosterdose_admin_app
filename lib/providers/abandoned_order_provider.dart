import 'package:flutter/material.dart';
import '../models/abandoned_order_model.dart';
import '../services/api_service.dart';

class AbandonedOrderProvider extends ChangeNotifier {
  List<AbandonedOrderModel> _abandonedOrders = [];
  Map<String, dynamic> _stats = {};
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _isLoading = false;
  String? _errorMessage;

  String _search = '';
  String _selectedRecoveryStatus = 'all';

  List<AbandonedOrderModel> get abandonedOrders => _abandonedOrders;
  Map<String, dynamic> get stats => _stats;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get search => _search;
  String get selectedRecoveryStatus => _selectedRecoveryStatus;

  Future<void> fetchAbandonedOrders({int page = 1, bool refresh = false}) async {
    if (refresh) page = 1;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.getAbandonedOrders(
        search: _search,
        recoveryStatus: _selectedRecoveryStatus == 'all' ? null : _selectedRecoveryStatus,
        page: page,
      );

      _abandonedOrders = result['abandoned_orders'];
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

  void setSearch(String query) {
    _search = query;
    fetchAbandonedOrders(refresh: true);
  }

  void setRecoveryStatus(String status) {
    _selectedRecoveryStatus = status;
    fetchAbandonedOrders(refresh: true);
  }

  Future<bool> updateStatus(int id, String recoveryStatus, {String? notes}) async {
    try {
      final updated = await ApiService.updateAbandonedStatus(id, recoveryStatus, notes: notes);
      final index = _abandonedOrders.indexWhere((o) => o.id == id);
      if (index != -1) {
        _abandonedOrders[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String> convertOrder(int id, [Map<String, dynamic>? orderData]) async {
    try {
      final result = await ApiService.convertAbandonedOrder(id, orderData);
      fetchAbandonedOrders(page: _currentPage);
      return result['message'] ?? 'Converted successfully';
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> deleteAbandoned(int id) async {
    try {
      await ApiService.deleteAbandonedOrder(id);
      _abandonedOrders.removeWhere((o) => o.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
