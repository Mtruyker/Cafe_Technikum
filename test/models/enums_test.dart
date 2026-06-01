import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/enums.dart';

void main() {
  group('OrderStatus', () {
    test('fromString parses all known values', () {
      expect(OrderStatusX.fromString('created'), OrderStatus.created);
      expect(OrderStatusX.fromString('accepted'), OrderStatus.accepted);
      expect(OrderStatusX.fromString('cooking'), OrderStatus.cooking);
      expect(OrderStatusX.fromString('ready'), OrderStatus.ready);
      expect(OrderStatusX.fromString('issued'), OrderStatus.issued);
      expect(OrderStatusX.fromString('canceled'), OrderStatus.canceled);
    });

    test('fromString returns unknown for unrecognized value', () {
      expect(OrderStatusX.fromString('garbage'), OrderStatus.unknown);
      expect(OrderStatusX.fromString(null), OrderStatus.unknown);
      expect(OrderStatusX.fromString(''), OrderStatus.unknown);
    });

    test('.value returns correct string', () {
      expect(OrderStatus.created.value, 'created');
      expect(OrderStatus.accepted.value, 'accepted');
      expect(OrderStatus.cooking.value, 'cooking');
      expect(OrderStatus.ready.value, 'ready');
      expect(OrderStatus.issued.value, 'issued');
      expect(OrderStatus.canceled.value, 'canceled');
      expect(OrderStatus.unknown.value, 'unknown');
    });

    test('.label returns Russian label', () {
      expect(OrderStatus.created.label, 'Создан');
      expect(OrderStatus.accepted.label, 'Принят');
      expect(OrderStatus.cooking.label, 'Готовится');
      expect(OrderStatus.ready.label, 'Готов');
      expect(OrderStatus.issued.label, 'Выдан');
      expect(OrderStatus.canceled.label, 'Отменен');
      expect(OrderStatus.unknown.label, 'Неизвестно');
    });
  });

  group('PaymentMethod', () {
    test('fromString parses all known values', () {
      expect(
        PaymentMethodX.fromString('pay_on_pickup'),
        PaymentMethod.payOnPickup,
      );
      expect(
        PaymentMethodX.fromString('online_card'),
        PaymentMethod.onlineCard,
      );
    });

    test('fromString returns unknown for unrecognized value', () {
      expect(PaymentMethodX.fromString('cash'), PaymentMethod.unknown);
      expect(PaymentMethodX.fromString(null), PaymentMethod.unknown);
    });

    test('.value returns correct string', () {
      expect(PaymentMethod.payOnPickup.value, 'pay_on_pickup');
      expect(PaymentMethod.onlineCard.value, 'online_card');
      expect(PaymentMethod.unknown.value, 'unknown');
    });

    test('.label returns Russian label', () {
      expect(PaymentMethod.payOnPickup.label, 'При получении');
      expect(PaymentMethod.onlineCard.label, 'Онлайн картой');
      expect(PaymentMethod.unknown.label, 'Неизвестно');
    });
  });

  group('PaymentStatus', () {
    test('fromString parses all known values', () {
      expect(PaymentStatusX.fromString('unpaid'), PaymentStatus.unpaid);
      expect(PaymentStatusX.fromString('pending'), PaymentStatus.pending);
      expect(PaymentStatusX.fromString('paid'), PaymentStatus.paid);
      expect(PaymentStatusX.fromString('failed'), PaymentStatus.failed);
    });

    test('fromString returns unknown for unrecognized value', () {
      expect(PaymentStatusX.fromString('refunded'), PaymentStatus.unknown);
      expect(PaymentStatusX.fromString(null), PaymentStatus.unknown);
    });

    test('.value returns correct string', () {
      expect(PaymentStatus.unpaid.value, 'unpaid');
      expect(PaymentStatus.pending.value, 'pending');
      expect(PaymentStatus.paid.value, 'paid');
      expect(PaymentStatus.failed.value, 'failed');
      expect(PaymentStatus.unknown.value, 'unknown');
    });

    test('.label returns Russian label', () {
      expect(PaymentStatus.unpaid.label, 'Не оплачено');
      expect(PaymentStatus.pending.label, 'Ожидает оплаты');
      expect(PaymentStatus.paid.label, 'Оплачено');
      expect(PaymentStatus.failed.label, 'Ошибка оплаты');
      expect(PaymentStatus.unknown.label, 'Неизвестно');
    });
  });

  group('PaymentSessionStatus', () {
    test('fromString parses all known values', () {
      expect(
        PaymentSessionStatusX.fromString('created'),
        PaymentSessionStatus.created,
      );
      expect(
        PaymentSessionStatusX.fromString('succeeded'),
        PaymentSessionStatus.succeeded,
      );
      expect(
        PaymentSessionStatusX.fromString('failed'),
        PaymentSessionStatus.failed,
      );
    });

    test('fromString returns unknown for unrecognized value', () {
      expect(
        PaymentSessionStatusX.fromString('pending'),
        PaymentSessionStatus.unknown,
      );
      expect(
        PaymentSessionStatusX.fromString(null),
        PaymentSessionStatus.unknown,
      );
    });

    test('.value returns correct string', () {
      expect(PaymentSessionStatus.created.value, 'created');
      expect(PaymentSessionStatus.succeeded.value, 'succeeded');
      expect(PaymentSessionStatus.failed.value, 'failed');
      expect(PaymentSessionStatus.unknown.value, 'unknown');
    });

    test('.label returns Russian label', () {
      expect(PaymentSessionStatus.created.label, 'Создана');
      expect(PaymentSessionStatus.succeeded.label, 'Успешно');
      expect(PaymentSessionStatus.failed.label, 'Ошибка');
      expect(PaymentSessionStatus.unknown.label, 'Неизвестно');
    });
  });
}
