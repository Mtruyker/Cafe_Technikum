import 'dart:convert';

import '../utils/formatters.dart';
import 'enums.dart';

class LocalOrderRecord {
  const LocalOrderRecord({
    required this.orderId,
    required this.orderNumber,
    required this.createdAt,
    required this.total,
    required this.status,
    this.pickupCode = '',
  });

  final String orderId;
  final String orderNumber;
  final DateTime createdAt;
  final double total;
  final OrderStatus status;
  final String pickupCode;

  LocalOrderRecord copyWith({OrderStatus? status}) {
    return LocalOrderRecord(
      orderId: orderId,
      orderNumber: orderNumber,
      createdAt: createdAt,
      total: total,
      status: status ?? this.status,
      pickupCode: pickupCode,
    );
  }

  JsonMap toJson() {
    return {
      'orderId': orderId,
      'orderNumber': orderNumber,
      'createdAt': createdAt.toIso8601String(),
      'total': total,
      'status': status.value,
      'pickupCode': pickupCode,
    };
  }

  factory LocalOrderRecord.fromJson(JsonMap json) {
    return LocalOrderRecord(
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      status: OrderStatusX.fromString(json['status']?.toString()),
      pickupCode: json['pickupCode']?.toString() ?? '',
    );
  }

  static List<LocalOrderRecord> decodeList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(LocalOrderRecord.fromJson)
        .toList(growable: false);
  }

  static String encodeList(List<LocalOrderRecord> records) {
    return jsonEncode(
      records.map((record) => record.toJson()).toList(growable: false),
    );
  }
}
