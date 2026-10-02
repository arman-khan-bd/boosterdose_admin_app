import 'package:flutter_test/flutter_test.dart';
import 'package:boosterdose_admin_app/models/courier_model.dart';

void main() {
  group('CourierSettingsModel Configuration Tests', () {
    test('Correctly identifies configured Steadfast credentials', () {
      final model = CourierSettingsModel.fromJson({
        'settings': {
          'courier_provider': 'steadfast',
          'steadfast_api_key': 'stf_test_key_123',
          'steadfast_secret_key': 'stf_secret_456',
        },
        'stats': {},
      });

      expect(model.isSteadfastConfigured, isTrue);
      expect(model.isPathaoConfigured, isFalse);
      expect(model.isRedxConfigured, isFalse);
      expect(model.hasAnyConfigured, isTrue);
    });

    test('Correctly identifies empty/null credentials as not configured', () {
      final model = CourierSettingsModel.fromJson({
        'settings': {
          'courier_provider': 'steadfast',
          'steadfast_api_key': '   ',
          'steadfast_secret_key': '',
          'pathao_client_id': null,
          'redx_api_token': '',
        },
        'stats': {},
      });

      expect(model.isSteadfastConfigured, isFalse);
      expect(model.isPathaoConfigured, isFalse);
      expect(model.isRedxConfigured, isFalse);
      expect(model.hasAnyConfigured, isFalse);
    });

    test('Loads configured_couriers list when supplied by API', () {
      final model = CourierSettingsModel.fromJson({
        'settings': {'courier_provider': 'pathao'},
        'configured_couriers': [
          {'id': 'pathao', 'name': 'Pathao Courier'},
        ],
        'stats': {},
      });

      expect(model.configuredCouriers.length, equals(1));
      expect(model.configuredCouriers.first['id'], equals('pathao'));
    });
  });
}
