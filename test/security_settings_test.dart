import 'package:flutter_test/flutter_test.dart';
import 'package:boosterdose_admin_app/models/security_settings_model.dart';

void main() {
  group('SecurityConfigModel Tests', () {
    test('Parses from json correctly', () {
      final json = {
        'api_blocking_enabled': true,
        'api_blocking_count': 5,
        'api_blocking_time_window_hours': 24,
        'api_blocking_duration_hours': 48,
        'api_blocking_cooldown_seconds': 30,
      };

      final config = SecurityConfigModel.fromJson(json);

      expect(config.apiBlockingEnabled, isTrue);
      expect(config.apiBlockingCount, 5);
      expect(config.apiBlockingTimeWindowHours, 24);
      expect(config.apiBlockingDurationHours, 48);
      expect(config.apiBlockingCooldownSeconds, 30);
    });

    test('Serializes to json correctly', () {
      final config = SecurityConfigModel(
        apiBlockingEnabled: false,
        apiBlockingCount: 3,
        apiBlockingTimeWindowHours: 48,
        apiBlockingDurationHours: 24,
        apiBlockingCooldownSeconds: 20,
      );

      final json = config.toJson();

      expect(json['api_blocking_enabled'], isFalse);
      expect(json['api_blocking_count'], 3);
      expect(json['api_blocking_time_window_hours'], 48);
      expect(json['api_blocking_duration_hours'], 24);
      expect(json['api_blocking_cooldown_seconds'], 20);
    });

    test('copyWith works as expected', () {
      final config = SecurityConfigModel(
        apiBlockingEnabled: true,
        apiBlockingCount: 3,
        apiBlockingTimeWindowHours: 48,
        apiBlockingDurationHours: 24,
        apiBlockingCooldownSeconds: 20,
      );

      final updated = config.copyWith(apiBlockingCount: 10, apiBlockingDurationHours: 72);

      expect(updated.apiBlockingCount, 10);
      expect(updated.apiBlockingDurationHours, 72);
      expect(updated.apiBlockingTimeWindowHours, 48);
      expect(updated.apiBlockingEnabled, isTrue);
    });
  });

  group('BlockedEntityModel Tests', () {
    test('Parses IP blocked entity with formatted time and active status', () {
      final json = {
        'id': 2,
        'type': 'ip',
        'value': '103.138.125.47',
        'reason': 'Too many orders placed',
        'order_count': 4,
        'status': 'blocked',
        'is_expired': false,
        'is_active': true,
        'blocked_at': '2026-10-02T14:17:55.000000Z',
        'blocked_at_formatted': '02 Oct, 2026 08:17 PM',
        'blocked_until': '2026-10-03T14:17:55.000000Z',
        'blocked_until_formatted': '03 Oct, 2026 08:17 PM',
      };

      final entity = BlockedEntityModel.fromJson(json);

      expect(entity.id, 2);
      expect(entity.type, 'ip');
      expect(entity.value, '103.138.125.47');
      expect(entity.orderCount, 4);
      expect(entity.isActive, isTrue);
      expect(entity.isExpired, isFalse);
      expect(entity.blockedAtFormatted, '02 Oct, 2026 08:17 PM');
      expect(entity.blockedUntilFormatted, '03 Oct, 2026 08:17 PM');
    });

    test('Parses Phone blocked entity with permanent duration', () {
      final json = {
        'id': 3,
        'type': 'phone',
        'value': '01891903444',
        'reason': 'Manual block',
        'order_count': 0,
        'status': 'blocked',
        'is_expired': false,
        'is_active': true,
        'blocked_at_formatted': '02 Oct, 2026 08:16 PM',
        'blocked_until': null,
        'blocked_until_formatted': 'স্থায়ী (Permanent)',
      };

      final entity = BlockedEntityModel.fromJson(json);

      expect(entity.type, 'phone');
      expect(entity.value, '01891903444');
      expect(entity.blockedUntil, isNull);
      expect(entity.blockedUntilFormatted, 'স্থায়ী (Permanent)');
    });
  });
}
