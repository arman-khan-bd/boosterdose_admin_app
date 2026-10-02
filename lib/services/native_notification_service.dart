import 'package:flutter/services.dart';

class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel('com.boosterdose.admin/notifications');

  static Function(String type, String payload)? _onNotificationTapped;

  /// Initialize channel and listen for notification tap callbacks from native Android
  static void init({Function(String type, String payload)? onNotificationTapped}) {
    _onNotificationTapped = onNotificationTapped;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationTapped') {
        final args = call.arguments;
        if (args is Map) {
          final type = args['type']?.toString() ?? 'order';
          final payload = args['payload']?.toString() ?? '';
          _onNotificationTapped?.call(type, payload);
        }
      }
    });

    // Schedule background polling alarm so notifications run if app is closed
    scheduleBackgroundSync();
  }

  /// Display a high-priority Android heads-up dropdown notification with vibration & sound
  static Future<bool> showNotification({
    required int id,
    required String title,
    required String body,
    String type = 'order',
    String? payload,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'payload': payload,
      });
      return res ?? true;
    } catch (e) {
      return false;
    }
  }

  /// Schedule background sync alarm to poll server even when the app is completely closed
  static Future<bool> scheduleBackgroundSync({int intervalSeconds = 45}) async {
    try {
      final res = await _channel.invokeMethod<bool>('scheduleBackgroundSync', {
        'intervalSeconds': intervalSeconds,
      });
      return res ?? true;
    } catch (e) {
      return false;
    }
  }

  /// Fire an instant test dropdown heads-up notification
  static Future<bool> testDropdownNotification() async {
    try {
      final res = await _channel.invokeMethod<bool>('testDropdownNotification');
      return res ?? true;
    } catch (e) {
      return false;
    }
  }

  /// Clear all posted notifications
  static Future<bool> cancelAll() async {
    try {
      final res = await _channel.invokeMethod<bool>('cancelAll');
      return res ?? true;
    } catch (e) {
      return false;
    }
  }

  /// Check if the app was launched by tapping an Android notification
  static Future<Map<String, dynamic>?> getInitialNotification() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('getInitialNotification');
      return res;
    } catch (e) {
      return null;
    }
  }
}
