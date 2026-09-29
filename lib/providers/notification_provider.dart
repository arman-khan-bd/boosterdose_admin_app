import 'package:flutter/material.dart';
import '../models/notification_feed_model.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationCounts? _counts;
  List<NotificationItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  NotificationCounts? get counts => _counts;
  List<NotificationItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchFeed({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await ApiService.getNotificationFeed();
      _counts = res['counts'];
      _items = res['items'];
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendTestNotification() async {
    try {
      await ApiService.testNotification();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
