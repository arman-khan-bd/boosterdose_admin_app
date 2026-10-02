import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_feed_model.dart';
import '../services/api_service.dart';
import '../services/native_notification_service.dart';

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

  /// Start periodic live polling (default: 25 seconds) and schedule native Android background alarm
  void startPolling({Duration interval = const Duration(seconds: 25)}) {
    _pollTimer?.cancel();
    // Schedule native Android background sync alarm so notifications continue when app is closed
    NativeNotificationService.scheduleBackgroundSync(intervalSeconds: 45);

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
    // Keep native background sync scheduled so notifications still arrive when closed
    NativeNotificationService.scheduleBackgroundSync(intervalSeconds: 45);
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

      // Detect new incoming orders or abandoned cart leads during live polling
      if (!_isFirstFetch && fetchedItems.isNotEmpty) {
        final newItems = fetchedItems.where((i) => !_seenItemIds.contains(i.id)).toList();
        if (newItems.isNotEmpty) {
          // Play system alert sound and vibration
          try {
            SystemSound.play(SystemSoundType.alert);
            HapticFeedback.vibrate();
          } catch (_) {}

          _latestArrival = newItems.first;

          // Trigger real Android high-priority dropdown heads-up notifications
          for (final item in newItems) {
            final isOrder = item.type == 'order';
            final isAbandoned = item.type == 'abandoned_order';
            final title = isOrder
                ? (item.title.isNotEmpty ? item.title : '🔔 নতুন অর্ডার: #${item.orderId ?? ''}')
                : (isAbandoned ? '🛒 নতুন পরিত্যক্ত কার্ট লিড' : '⭐ নতুন শিক্ষার্থী রিভিউ (${item.rating ?? 5}★)');
            final body = isOrder
                ? '${item.customerName} (${item.customerPhone}) • ৳${item.amount.toInt()} - ${item.bookTitle}'
                : (isAbandoned
                    ? '${item.customerName} (${item.customerPhone}) • ৳${item.amount.toInt()}'
                    : '${item.customerName} - "${item.comment ?? item.bookTitle}"');

            final notifId = ((item.orderId ?? item.abandonedOrderId ?? item.reviewId ?? DateTime.now().millisecondsSinceEpoch) % 1000000).toInt();

            NativeNotificationService.showNotification(
              id: notifId,
              title: title,
              body: body,
              type: item.type,
              payload: (item.orderId ?? item.abandonedOrderId ?? item.reviewId)?.toString(),
            );
          }
        }
      }

      // Sync latest seen IDs to SharedPreferences for background receiver compatibility
      if (fetchedItems.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        int maxOrder = prefs.getInt('last_notified_order_id') ?? 0;
        int maxAbandoned = prefs.getInt('last_notified_abandoned_id') ?? 0;
        int maxReview = prefs.getInt('last_notified_review_id') ?? 0;

        for (final it in fetchedItems) {
          _seenItemIds.add(it.id);
          if (it.type == 'order' && (it.orderId ?? 0) > maxOrder) maxOrder = it.orderId!;
          if (it.type == 'abandoned_order' && (it.abandonedOrderId ?? 0) > maxAbandoned) maxAbandoned = it.abandonedOrderId!;
          if (it.type == 'review' && (it.reviewId ?? 0) > maxReview) maxReview = it.reviewId!;
        }

        await prefs.setInt('last_notified_order_id', maxOrder);
        await prefs.setInt('last_notified_abandoned_id', maxAbandoned);
        await prefs.setInt('last_notified_review_id', maxReview);
        await prefs.setBool('bg_notifications_initialized', true);
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
      // Instantly trigger an Android high-priority heads-up dropdown notification
      await NativeNotificationService.showNotification(
        id: 9999,
        title: '🔔 টেস্ট পুশ নোটিফিকেশন',
        body: 'বুস্টার ডোজ অ্যাডমিন পুশ নোটিফিকেশন ড্রপডাউন সফলভাবে কাজ করছে!',
        type: 'test',
        payload: 'test_alert',
      );
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
