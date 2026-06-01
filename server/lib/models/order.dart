import 'enums.dart';

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
  final List<OrderItem> items;

  CafeOrder copyWith({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    String? providerPaymentId,
    DateTime? paidAt,
  }) {
    return CafeOrder(
      id: id,
      orderNumber: orderNumber,
      createdAt: createdAt,
      customerFirstName: customerFirstName,
      customerLastName: customerLastName,
      status: status ?? this.status,
      total: total,
      comment: comment,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      providerPaymentId: providerPaymentId ?? this.providerPaymentId,
      paidAt: paidAt ?? this.paidAt,
      items: items,
    );
  }

  JsonMap toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'createdAt': createdAt.toIso8601String(),
      'customerFirstName': customerFirstName,
      'customerLastName': customerLastName,
      'status': status.value,
      'total': total,
      'comment': comment,
      'paymentMethod': paymentMethod.value,
      'paymentStatus': paymentStatus.value,
      'providerPaymentId': providerPaymentId,
      'paidAt': paidAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.nameSnapshot,
    required this.priceSnapshot,
    required this.qty,
    required this.modifiers,
  });

  final String id;
  final String productId;
  final String nameSnapshot;
  final double priceSnapshot;
  final int qty;
  final List<OrderItemModifier> modifiers;

  double get unitPrice {
    final modifiersSum = modifiers.fold<double>(
      0,
      (sum, modifier) => sum + modifier.priceDeltaSnapshot,
    );
    return priceSnapshot + modifiersSum;
  }

  double get lineTotal => unitPrice * qty;

  JsonMap toJson() {
    return {
      'id': id,
      'productId': productId,
      'nameSnapshot': nameSnapshot,
      'priceSnapshot': priceSnapshot,
      'qty': qty,
      'lineTotal': lineTotal,
      'modifiers': modifiers
          .map((item) => item.toJson())
          .toList(growable: false),
    };
  }
}

class OrderItemModifier {
  const OrderItemModifier({
    required this.nameSnapshot,
    required this.priceDeltaSnapshot,
  });

  final String nameSnapshot;
  final double priceDeltaSnapshot;

  JsonMap toJson() {
    return {
      'nameSnapshot': nameSnapshot,
      'priceDeltaSnapshot': priceDeltaSnapshot,
    };
  }
}
