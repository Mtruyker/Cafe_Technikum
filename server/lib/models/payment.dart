import 'enums.dart';

class PaymentSession {
  const PaymentSession({
    required this.id,
    required this.orderId,
    required this.amount,
    required this.status,
    required this.checkoutUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String orderId;
  final double amount;
  final PaymentSessionStatus status;
  final String checkoutUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentSession copyWith({PaymentSessionStatus? status, DateTime? updatedAt}) {
    return PaymentSession(
      id: id,
      orderId: orderId,
      amount: amount,
      status: status ?? this.status,
      checkoutUrl: checkoutUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  JsonMap toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'amount': amount,
      'status': status.value,
      'checkoutUrl': checkoutUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
