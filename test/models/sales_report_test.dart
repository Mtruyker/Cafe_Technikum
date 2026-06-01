import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/sales_report.dart';

void main() {
  group('SalesReport.fromJson', () {
    test('parses full JSON with byStatus map', () {
      final report = SalesReport.fromJson({
        'from': '2025-01-01T00:00:00Z',
        'to': '2025-01-31T23:59:59Z',
        'ordersCount': 50,
        'nonCanceledOrdersCount': 45,
        'itemsSold': 120,
        'totalRevenue': 25000.0,
        'byStatus': {
          'created': 5,
          'cooking': 3,
          'ready': 2,
          'issued': 35,
          'canceled': 5,
        },
        'ordersByDay': {'2025-01-01': 4, '2025-01-02': 6},
        'revenueByDay': {'2025-01-01': 1800.0, '2025-01-02': 2400.0},
      });

      expect(report.from, isNotNull);
      expect(report.from!.year, 2025);
      expect(report.to, isNotNull);
      expect(report.ordersCount, 50);
      expect(report.nonCanceledOrdersCount, 45);
      expect(report.itemsSold, 120);
      expect(report.totalRevenue, 25000.0);
      expect(report.byStatus, hasLength(5));
      expect(report.byStatus['issued'], 35);
      expect(report.byStatus['canceled'], 5);
      expect(report.ordersByDay, hasLength(2));
      expect(report.revenueByDay, hasLength(2));
      expect(report.ordersByDay[DateTime(2025, 1, 1)], 4);
      expect(report.revenueByDay[DateTime(2025, 1, 2)], 2400.0);
    });

    test('handles missing fields with defaults', () {
      final report = SalesReport.fromJson({});

      expect(report.from, isNull);
      expect(report.to, isNull);
      expect(report.ordersCount, 0);
      expect(report.nonCanceledOrdersCount, 0);
      expect(report.itemsSold, 0);
      expect(report.totalRevenue, 0);
      expect(report.byStatus, isEmpty);
      expect(report.ordersByDay, isEmpty);
      expect(report.revenueByDay, isEmpty);
    });

    test('handles byStatus as non-map gracefully', () {
      final report = SalesReport.fromJson({'byStatus': 'not a map'});

      expect(report.byStatus, isEmpty);
    });

    test('handles null byStatus', () {
      final report = SalesReport.fromJson({'byStatus': null});

      expect(report.byStatus, isEmpty);
    });

    test('handles malformed daily series gracefully', () {
      final report = SalesReport.fromJson({
        'ordersByDay': {'bad-date': 2, '2025-02-01': 7},
        'revenueByDay': 'not a map',
      });

      expect(report.ordersByDay, hasLength(1));
      expect(report.ordersByDay[DateTime(2025, 2, 1)], 7);
      expect(report.revenueByDay, isEmpty);
    });
  });
}
