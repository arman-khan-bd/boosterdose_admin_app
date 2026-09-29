import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

class OrderProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  Map<String, dynamic> _stats = {};
  int _currentPage = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _isLoading = false;
  String? _errorMessage;

  String _search = '';
  String _selectedStatus = 'all';
  String _selectedPaymentStatus = 'all';

  List<OrderModel> get orders => _orders;
  Map<String, dynamic> get stats => _stats;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get total => _total;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get search => _search;
  String get selectedStatus => _selectedStatus;
  String get selectedPaymentStatus => _selectedPaymentStatus;

  Future<void> fetchOrders({int page = 1, bool refresh = false}) async {
    if (refresh) {
      page = 1;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await ApiService.getOrders(
        search: _search,
        status: _selectedStatus == 'all' ? null : _selectedStatus,
        paymentStatus: _selectedPaymentStatus == 'all' ? null : _selectedPaymentStatus,
        page: page,
      );

      _orders = result['orders'];
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
    fetchOrders(refresh: true);
  }

  void setStatus(String status) {
    _selectedStatus = status;
    fetchOrders(refresh: true);
  }

  void setPaymentStatus(String paymentStatus) {
    _selectedPaymentStatus = paymentStatus;
    fetchOrders(refresh: true);
  }

  Future<bool> updateStatus(int id, String newStatus) async {
    try {
      final updated = await ApiService.updateOrderStatus(id, newStatus);
      final index = _orders.indexWhere((o) => o.id == id);
      if (index != -1) {
        _orders[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePayment(int id, String newPaymentStatus) async {
    try {
      final updated = await ApiService.updatePaymentStatus(id, newPaymentStatus);
      final index = _orders.indexWhere((o) => o.id == id);
      if (index != -1) {
        _orders[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignCourier(int id, String courierName, String trackingCode) async {
    try {
      final updated = await ApiService.updateOrderCourier(id, courierName: courierName, trackingCode: trackingCode);
      final index = _orders.indexWhere((o) => o.id == id);
      if (index != -1) {
        _orders[index] = updated;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> dispatchCourier(
    int id, {
    String courier = 'steadfast',
    String dispatchType = 'api',
    String? consignmentId,
  }) async {
    try {
      final res = await ApiService.sendOrderToCourier(
        id,
        courier: courier,
        dispatchType: dispatchType,
        consignmentId: consignmentId,
      );
      fetchOrders(page: _currentPage);
      return res;
    } catch (e) {
      rethrow;
    }
  }
}
