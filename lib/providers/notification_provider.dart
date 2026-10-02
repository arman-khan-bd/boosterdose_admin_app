import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/notification_feed_model.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationCounts? _counts;
  List<NotificationItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;

  Timer? _pollTimer;
  final Set<String> _seenItemIds = {};
  bool _isFirstFetch = true;
  NotificationItem? _latestArrival;

  NotificationCounts? get counts => _counts;
  List<NotificationItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NotificationItem? get latestArrival => _latestArrival;
  int get totalUnread {
    if (_items.isEmpty && (_counts?.totalUnread ?? 0) == 0) return 0;
    final eligibleAbandoned = _items.where((i) => i.type == 'abandoned_order').length;
    final orders = _counts?.pendingOrders ?? _items.where((i) => i.type == 'order').length;
    final reviews = _counts?.pendingReviews ?? _items.where((i) => i.type == 'review').length;
    final calculated = orders + eligibleAbandoned + reviews;
    return calculated > 0 ? calculated : (_counts?.totalUnread ?? 0);
  }

  /// Start periodic live polling (default: 25 seconds) to catch new orders and abandoned cart leads in real-time
  void startPolling({Duration interval = const Duration(seconds: 25)}) {
    _pollTimer?.cancel();
    // Immediate background fetch
    fetchFeed(silent: true, isBackgroundPoll: true);
    _pollTimer = Timer.periodic(interval, (_) {
      fetchFeed(silent: true, isBackgroundPoll: true);
    });
  }

  /// Stop polling (e.g., when app is minimized or disposed)
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void clearLatestArrival() {
    _latestArrival = null;
    notifyListeners();
  }

  Future<void> fetchFeed({bool silent = false, bool isBackgroundPoll = false}) async {
    if (!silent) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final res = await ApiService.getNotificationFeed();
      final NotificationCounts? fetchedCounts = res['counts'];
      final List<NotificationItem> rawItems = res['items'] != null
          ? List<NotificationItem>.from(res['items'])
          : [];

      // Filter: Do NOT show abandoned order notifications before 5 minutes have elapsed
      final fetchedItems = rawItems.where((i) => i.isEligibleForDisplay).toList();

      // Detect new incoming orders or abandoned cart leads during background polling
      if (!_isFirstFetch && fetchedItems.isNotEmpty) {
        final newItems = fetchedItems.where((i) => !_seenItemIds.contains(i.id)).toList();
        if (newItems.isNotEmpty) {
          // Play system alert sound and vibration on modern & older Android (Samsung J2 etc.)
          try {
            SystemSound.play(SystemSoundType.alert);
            HapticFeedback.vibrate();
          } catch (_) {}

          _latestArrival = newItems.first;
        }
      }

      // Track all seen item IDs that are eligible
      for (final it in fetchedItems) {
        _seenItemIds.add(it.id);
      }
      _isFirstFetch = false;

      _counts = fetchedCounts;
      _items = fetchedItems;
      _errorMessage = null;
    } catch (e) {
      if (!isBackgroundPoll) {
        _errorMessage = e.toString();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendTestNotification() async {
    try {
      await ApiService.testNotification();
      // Refetch feed immediately after test notification
      await fetchFeed(silent: true);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
