import '../utils/formatters.dart';

class SalesReport {
  const SalesReport({
    required this.from,
    required this.to,
    required this.ordersCount,
    required this.nonCanceledOrdersCount,
    required this.itemsSold,
    required this.totalRevenue,
    required this.byStatus,
    required this.ordersByDay,
    required this.revenueByDay,
  });

  final DateTime? from;
  final DateTime? to;
  final int ordersCount;
  final int nonCanceledOrdersCount;
  final int itemsSold;
  final double totalRevenue;
  final Map<String, int> byStatus;
  final Map<DateTime, int> ordersByDay;
  final Map<DateTime, double> revenueByDay;

  factory SalesReport.fromJson(JsonMap json) {
    return SalesReport(
      from: DateTime.tryParse(json['from']?.toString() ?? ''),
      to: DateTime.tryParse(json['to']?.toString() ?? ''),
      ordersCount: (json['ordersCount'] as num?)?.toInt() ?? 0,
      nonCanceledOrdersCount:
          (json['nonCanceledOrdersCount'] as num?)?.toInt() ?? 0,
      itemsSold: (json['itemsSold'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0,
      byStatus: _parseIntMap(json['byStatus']),
      ordersByDay: _parseDailyIntMap(json['ordersByDay']),
      revenueByDay: _parseDailyDoubleMap(json['revenueByDay']),
    );
  }

  static Map<String, int> _parseIntMap(Object? raw) {
    final result = <String, int>{};
    if (raw is! Map<String, dynamic>) {
      return result;
    }

    for (final entry in raw.entries) {
      result[entry.key] = (entry.value as num?)?.toInt() ?? 0;
    }
    return result;
  }

  static Map<DateTime, int> _parseDailyIntMap(Object? raw) {
    final result = <DateTime, int>{};
    if (raw is! Map<String, dynamic>) {
      return result;
    }

    for (final entry in raw.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null) {
        continue;
      }
      result[DateTime(day.year, day.month, day.day)] =
          (entry.value as num?)?.toInt() ?? 0;
    }
    return result;
  }

  static Map<DateTime, double> _parseDailyDoubleMap(Object? raw) {
    final result = <DateTime, double>{};
    if (raw is! Map<String, dynamic>) {
      return result;
    }

    for (final entry in raw.entries) {
      final day = DateTime.tryParse(entry.key);
      if (day == null) {
        continue;
      }
      result[DateTime(day.year, day.month, day.day)] =
          (entry.value as num?)?.toDouble() ?? 0;
    }
    return result;
  }
}
