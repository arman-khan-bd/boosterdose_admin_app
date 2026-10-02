import 'package:flutter_test/flutter_test.dart';
import 'package:boosterdose_admin_app/models/order_model.dart';
import 'package:boosterdose_admin_app/models/abandoned_order_model.dart';

void main() {
  group('OrderModel Copy Text Tests', () {
    test('copyableOrderData formats full order details with name, phone, address', () {
      final order = OrderModel(
        id: 1,
        orderNumber: 'ORD-1234',
        customerName: 'তানজিম হাসান',
        customerPhone: '01711223344',
        deliveryAddress: 'বাসা ১২, রোড ৪, ধানমন্ডি, ঢাকা',
        deliveryCharge: 60,
        quantity: 2,
        unitPrice: 350,
        totalAmount: 760,
        paymentMethod: 'cod',
        paymentStatus: 'pending',
        status: 'pending',
        book: {'title': 'এইচএসসি বুস্টার ডেক্স'},
      );

      final text = order.copyableOrderData;
      expect(text, contains('নাম: তানজিম হাসান'));
      expect(text, contains('ফোন: 01711223344'));
      expect(text, contains('ঠিকানা: বাসা ১২, রোড ৪, ধানমন্ডি, ঢাকা'));
      expect(text, contains('পণ্য: এইচএসসি বুস্টার ডেক্স (x2)'));
      expect(text, contains('মূল্য: ৳760'));
      expect(text, contains('অর্ডার নম্বর: #ORD-1234'));
    });

    test('copyableCustomerInfo formats name, phone, address only', () {
      final order = OrderModel(
        id: 2,
        orderNumber: 'ORD-5678',
        customerName: 'রাকিবুল ইসলাম',
        customerPhone: '01899887766',
        deliveryAddress: 'মিরপুর ১০, ঢাকা',
        deliveryCharge: 60,
        quantity: 1,
        unitPrice: 400,
        totalAmount: 460,
        paymentMethod: 'cod',
        paymentStatus: 'pending',
        status: 'processing',
      );

      final text = order.copyableCustomerInfo;
      expect(text, contains('নাম: রাকিবুল ইসলাম'));
      expect(text, contains('ফোন: 01899887766'));
      expect(text, contains('ঠিকানা: মিরপুর ১০, ঢাকা'));
    });
  });

  group('AbandonedOrderModel Copy Text Tests', () {
    test('copyableLeadData formats name, phone, address, book and amount', () {
      final lead = AbandonedOrderModel(
        id: 10,
        customerName: 'সাকিব আল হাসান',
        customerPhone: '01911223344',
        deliveryAddress: 'উত্তরা সেক্টর ৭, ঢাকা',
        deliveryCharge: 60,
        quantity: 1,
        unitPrice: 390,
        totalAmount: 450,
        recoveryStatus: 'pending',
        book: {'title': 'পদার্থবিজ্ঞান বুস্টার'},
      );

      final text = lead.copyableLeadData;
      expect(text, contains('নাম: সাকিব আল হাসান'));
      expect(text, contains('ফোন: 01911223344'));
      expect(text, contains('ঠিকানা: উত্তরা সেক্টর ৭, ঢাকা'));
      expect(text, contains('পণ্য: পদার্থবিজ্ঞান বুস্টার (x1)'));
      expect(text, contains('মূল্য: ৳450'));
    });
  });
}
