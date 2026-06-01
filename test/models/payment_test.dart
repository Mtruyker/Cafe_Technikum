import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/payment.dart';
import 'package:cafe_technikum/models/enums.dart';
import 'package:cafe_technikum/services/api_exception.dart';

void main() {
  group('PaymentSession.fromJson', () {
    test('parses correct JSON', () {
      final session = PaymentSession.fromJson({
        'id': 'ps1',
        'orderId': 'ord1',
        'amount': 500.0,
        'status': 'created',
        'checkoutUrl': 'https://pay.example.com/checkout/ps1',
        'createdAt': '2025-01-15T10:30:00Z',
        'updatedAt': '2025-01-15T10:30:00Z',
      });

      expect(session.id, 'ps1');
      expect(session.orderId, 'ord1');
      expect(session.amount, 500.0);
      expect(session.status, PaymentSessionStatus.created);
      expect(session.checkoutUrl, 'https://pay.example.com/checkout/ps1');
      expect(session.createdAt.year, 2025);
      expect(session.updatedAt.year, 2025);
    });

    test('handles missing fields with defaults', () {
      final session = PaymentSession.fromJson({});

      expect(session.id, '');
      expect(session.orderId, '');
      expect(session.amount, 0);
      expect(session.status, PaymentSessionStatus.unknown);
      expect(session.checkoutUrl, '');
    });
  });

  group('PaymentConfirmationResult.fromJson', () {
    test('parses correct JSON with payment and order', () {
      final result = PaymentConfirmationResult.fromJson({
        'payment': {
          'id': 'ps1',
          'orderId': 'ord1',
          'amount': 500.0,
          'status': 'succeeded',
          'checkoutUrl': '',
          'createdAt': '2025-01-15T10:30:00Z',
          'updatedAt': '2025-01-15T10:31:00Z',
        },
        'order': {
          'id': 'ord1',
          'orderNumber': 'A-001',
          'createdAt': '2025-01-15T10:30:00Z',
          'status': 'cooking',
          'total': 500.0,
          'paymentMethod': 'online_card',
          'paymentStatus': 'paid',
          'items': [],
        },
      });

      expect(result.payment.id, 'ps1');
      expect(result.payment.status, PaymentSessionStatus.succeeded);
      expect(result.order.id, 'ord1');
      expect(result.order.status, OrderStatus.cooking);
    });

    test('throws ApiException when payment is not a map', () {
      expect(
        () => PaymentConfirmationResult.fromJson({
          'payment': 'invalid',
          'order': {'id': 'ord1'},
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException when order is not a map', () {
      expect(
        () => PaymentConfirmationResult.fromJson({
          'payment': {'id': 'ps1'},
          'order': 'invalid',
        }),
        throwsA(isA<ApiException>()),
      );
    });

    test('throws ApiException when both are missing', () {
      expect(
        () => PaymentConfirmationResult.fromJson({}),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
