import 'package:cafe_technikum/models/enums.dart';
import 'package:cafe_technikum/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderItemModifierSnapshot.fromJson', () {
    test('parses correct JSON', () {
      final mod = OrderItemModifierSnapshot.fromJson({
        'nameSnapshot': 'Сахар',
        'priceDeltaSnapshot': 10.0,
      });

      expect(mod.nameSnapshot, 'Сахар');
      expect(mod.priceDeltaSnapshot, 10.0);
    });

    test('handles missing fields', () {
      final mod = OrderItemModifierSnapshot.fromJson({});

      expect(mod.nameSnapshot, '');
      expect(mod.priceDeltaSnapshot, 0);
    });
  });

  group('OrderItemSnapshot.fromJson', () {
    test('parses correct JSON with modifiers', () {
      final item = OrderItemSnapshot.fromJson({
        'id': 'oi1',
        'productId': 'p1',
        'nameSnapshot': 'Латте',
        'priceSnapshot': 200.0,
        'qty': 2,
        'lineTotal': 400.0,
        'modifiers': [
          {'nameSnapshot': 'Сахар', 'priceDeltaSnapshot': 10},
        ],
      });

      expect(item.id, 'oi1');
      expect(item.productId, 'p1');
      expect(item.nameSnapshot, 'Латте');
      expect(item.priceSnapshot, 200.0);
      expect(item.qty, 2);
      expect(item.lineTotal, 400.0);
      expect(item.modifiers, hasLength(1));
      expect(item.modifiers[0].nameSnapshot, 'Сахар');
    });

    test('handles empty modifiers', () {
      final item = OrderItemSnapshot.fromJson({
        'id': 'oi1',
        'productId': 'p1',
        'nameSnapshot': 'Латте',
        'priceSnapshot': 200.0,
        'qty': 1,
        'lineTotal': 200.0,
      });

      expect(item.modifiers, isEmpty);
    });
  });

  group('CafeOrder.fromJson', () {
    test('parses full JSON', () {
      final order = CafeOrder.fromJson({
        'id': 'ord1',
        'orderNumber': 'A-001',
        'createdAt': '2025-01-15T10:30:00Z',
        'customerFirstName': 'Иван',
        'customerLastName': 'Петров',
        'status': 'cooking',
        'total': 500.0,
        'comment': 'Без сахара',
        'paymentMethod': 'online_card',
        'paymentStatus': 'paid',
        'providerPaymentId': 'pay_123',
        'paidAt': '2025-01-15T10:31:00Z',
        'items': [
          {
            'id': 'oi1',
            'productId': 'p1',
            'nameSnapshot': 'Латте',
            'priceSnapshot': 250.0,
            'qty': 2,
            'lineTotal': 500.0,
            'modifiers': [],
          },
        ],
      });

      expect(order.id, 'ord1');
      expect(order.orderNumber, 'A-001');
      expect(order.createdAt.year, 2025);
      expect(order.customerFirstName, 'Иван');
      expect(order.customerLastName, 'Петров');
      expect(order.customerFullName, 'Иван Петров');
      expect(order.status, OrderStatus.cooking);
      expect(order.total, 500.0);
      expect(order.comment, 'Без сахара');
      expect(order.paymentMethod, PaymentMethod.onlineCard);
      expect(order.paymentStatus, PaymentStatus.paid);
      expect(order.providerPaymentId, 'pay_123');
      expect(order.paidAt, isNotNull);
      expect(order.items, hasLength(1));
    });

    test('handles missing optional fields', () {
      final order = CafeOrder.fromJson({
        'id': 'ord2',
        'orderNumber': 'B-002',
        'createdAt': '2025-01-15T10:30:00Z',
        'status': 'created',
        'total': 100.0,
      });

      expect(order.customerFirstName, '');
      expect(order.customerLastName, '');
      expect(order.customerFullName, '');
      expect(order.paymentMethod, PaymentMethod.unknown);
      expect(order.paymentStatus, PaymentStatus.unknown);
      expect(order.items, isEmpty);
    });
  });

  group('OrderCreatedResponse.fromJson', () {
    test('parses correct JSON', () {
      final resp = OrderCreatedResponse.fromJson({
        'orderId': 'ord1',
        'orderNumber': 'A-001',
        'qrCodeData': 'qr_data_here',
        'status': 'created',
        'total': 350.0,
        'createdAt': '2025-01-15T12:00:00Z',
        'paymentMethod': 'pay_on_pickup',
        'paymentStatus': 'unpaid',
        'providerPaymentId': null,
        'paidAt': null,
      });

      expect(resp.orderId, 'ord1');
      expect(resp.orderNumber, 'A-001');
      expect(resp.qrCodeData, 'qr_data_here');
      expect(resp.status, OrderStatus.created);
      expect(resp.total, 350.0);
      expect(resp.paymentMethod, PaymentMethod.payOnPickup);
      expect(resp.paymentStatus, PaymentStatus.unpaid);
      expect(resp.providerPaymentId, isNull);
      expect(resp.paidAt, isNull);
    });

    test('resolvedQrCodeData uses qrCodeData when it exists', () {
      final resp = OrderCreatedResponse.fromJson({
        'orderId': 'ord1',
        'orderNumber': 'A-001',
        'qrCodeData': 'qr_data_here',
        'status': 'created',
        'total': 350.0,
        'createdAt': '2025-01-15T12:00:00Z',
        'paymentMethod': 'pay_on_pickup',
        'paymentStatus': 'unpaid',
      });

      expect(resp.resolvedQrCodeData, 'qr_data_here');
    });

    test('resolvedQrCodeData falls back to orderNumber', () {
      final resp = OrderCreatedResponse.fromJson({
        'orderId': 'ord1',
        'orderNumber': 'A-001',
        'qrCodeData': '   ',
        'status': 'created',
        'total': 350.0,
        'createdAt': '2025-01-15T12:00:00Z',
        'paymentMethod': 'pay_on_pickup',
        'paymentStatus': 'unpaid',
      });

      expect(resp.resolvedQrCodeData, 'A-001');
    });
  });
}
