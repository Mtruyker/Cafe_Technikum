import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/local_order_record.dart';
import 'package:cafe_technikum/models/enums.dart';

void main() {
  final sampleRecord = LocalOrderRecord(
    orderId: 'ord1',
    orderNumber: 'A-001',
    createdAt: DateTime.utc(2025, 1, 15, 10, 30),
    total: 500.0,
    status: OrderStatus.created,
  );

  group('LocalOrderRecord.fromJson / toJson', () {
    test('roundtrip preserves all fields', () {
      final json = sampleRecord.toJson();
      final restored = LocalOrderRecord.fromJson(json);

      expect(restored.orderId, sampleRecord.orderId);
      expect(restored.orderNumber, sampleRecord.orderNumber);
      expect(restored.createdAt, sampleRecord.createdAt);
      expect(restored.total, sampleRecord.total);
      expect(restored.status, sampleRecord.status);
    });

    test('toJson produces correct keys', () {
      final json = sampleRecord.toJson();

      expect(json['orderId'], 'ord1');
      expect(json['orderNumber'], 'A-001');
      expect(json['total'], 500.0);
      expect(json['status'], 'created');
      expect(json['createdAt'], contains('2025-01-15'));
    });

    test('fromJson handles missing fields', () {
      final record = LocalOrderRecord.fromJson({});

      expect(record.orderId, '');
      expect(record.orderNumber, '');
      expect(record.total, 0);
      expect(record.status, OrderStatus.unknown);
    });
  });

  group('decodeList / encodeList', () {
    test('roundtrip with multiple records', () {
      final records = [
        sampleRecord,
        LocalOrderRecord(
          orderId: 'ord2',
          orderNumber: 'B-002',
          createdAt: DateTime.utc(2025, 2, 1),
          total: 100.0,
          status: OrderStatus.issued,
        ),
      ];

      final encoded = LocalOrderRecord.encodeList(records);
      final decoded = LocalOrderRecord.decodeList(encoded);

      expect(decoded, hasLength(2));
      expect(decoded[0].orderId, 'ord1');
      expect(decoded[1].orderId, 'ord2');
      expect(decoded[1].status, OrderStatus.issued);
    });

    test('decodeList returns empty for non-list JSON', () {
      final result = LocalOrderRecord.decodeList('"not a list"');
      expect(result, isEmpty);
    });

    test('encodeList with empty list', () {
      final encoded = LocalOrderRecord.encodeList([]);
      final decoded = LocalOrderRecord.decodeList(encoded);
      expect(decoded, isEmpty);
    });
  });

  group('copyWith', () {
    test('changes status', () {
      final updated = sampleRecord.copyWith(status: OrderStatus.ready);

      expect(updated.status, OrderStatus.ready);
      expect(updated.orderId, sampleRecord.orderId);
      expect(updated.total, sampleRecord.total);
    });

    test('keeps status when not provided', () {
      final copy = sampleRecord.copyWith();
      expect(copy.status, sampleRecord.status);
    });
  });
}
