import '../utils/formatters.dart';
import 'enums.dart';

class OrderItemModifierSnapshot {
  const OrderItemModifierSnapshot({
    required this.nameSnapshot,
    required this.priceDeltaSnapshot,
  });

  final String nameSnapshot;
  final double priceDeltaSnapshot;

  factory OrderItemModifierSnapshot.fromJson(JsonMap json) {
    return OrderItemModifierSnapshot(
      nameSnapshot: json['nameSnapshot']?.toString() ?? '',
      priceDeltaSnapshot: (json['priceDeltaSnapshot'] as num?)?.toDouble() ?? 0,
    );
  }
}

class OrderItemSnapshot {
  const OrderItemSnapshot({
    required this.id,
    required this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.lineTotal,
    required this.modifiers,
  });

  final String id;
  final String productId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int qty;
  final double lineTotal;
  final List<OrderItemModifierSnapshot> modifiers;

  factory OrderItemSnapshot.fromJson(JsonMap json) {
    final rawModifiers = json['modifiers'] as List<dynamic>? ?? const [];

    return OrderItemSnapshot(
      id: json['id']?.toString() ?? '',
      productId: json['productId']?.toString() ?? '',
      nameSnapshot: json['nameSnapshot']?.toString() ?? '',
      priceSnapshot: (json['priceSnapshot'] as num?)?.toDouble() ?? 0,
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      modifiers: rawModifiers
          .whereType<Map<String, dynamic>>()
          .map(OrderItemModifierSnapshot.fromJson)
          .toList(growable: false),
    );
  }
}

class CafeOrder {
  const CafeOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.customerFirstName,
    required this.customerLastName,
    required this.status,
    required this.total,
    required this.comment,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.providerPaymentId,
    required this.paidAt,
    required this.items,
  });

  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final String customerFirstName;
  final String customerLastName;
  final OrderStatus status;
  final double total;
  final String? comment;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? providerPaymentId;
  final DateTime? paidAt;
  final List<OrderItemSnapshot> items;

  String get customerFullName => [
    customerFirstName.trim(),
    customerLastName.trim(),
  ].where((value) => value.isNotEmpty).join(' ');

  factory CafeOrder.fromJson(JsonMap json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return CafeOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      customerFirstName: json['customerFirstName']?.toString() ?? '',
      customerLastName: json['customerLastName']?.toString() ?? '',
      status: OrderStatusX.fromString(json['status']?.toString()),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      comment: json['comment']?.toString(),
      paymentMethod: PaymentMethodX.fromString(
        json['paymentMethod']?.toString(),
      ),
      paymentStatus: PaymentStatusX.fromString(
        json['paymentStatus']?.toString(),
      ),
      providerPaymentId: json['providerPaymentId']?.toString(),
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(OrderItemSnapshot.fromJson)
          .toList(growable: false),
    );
  }
}

class OrderCreatedResponse {
  const OrderCreatedResponse({
    required this.orderId,
    required this.orderNumber,
    required this.qrCodeData,
    required this.status,
    required this.total,
    required this.createdAt,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.providerPaymentId,
    required this.paidAt,
  });

  final String orderId;
  final String orderNumber;
  final String qrCodeData;
  final OrderStatus status;
  final double total;
  final DateTime createdAt;
  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;
  final String? providerPaymentId;
  final DateTime? paidAt;

  String get resolvedQrCodeData {
    final qrValue = qrCodeData.trim();
    if (qrValue.isNotEmpty) {
      return qrValue;
    }

    final orderNumberValue = orderNumber.trim();
    if (orderNumberValue.isNotEmpty) {
      return orderNumberValue;
    }

    return orderId.trim();
  }

  factory OrderCreatedResponse.fromJson(JsonMap json) {
    return OrderCreatedResponse(
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      qrCodeData: json['qrCodeData']?.toString() ?? '',
      status: OrderStatusX.fromString(json['status']?.toString()),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      paymentMethod: PaymentMethodX.fromString(
        json['paymentMethod']?.toString(),
      ),
      paymentStatus: PaymentStatusX.fromString(
        json['paymentStatus']?.toString(),
      ),
      providerPaymentId: json['providerPaymentId']?.toString(),
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
    );
  }
}
