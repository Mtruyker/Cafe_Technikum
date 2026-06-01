import '../utils/formatters.dart';
import '../services/api_exception.dart';
import 'enums.dart';
import 'order.dart';

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

  factory PaymentSession.fromJson(JsonMap json) {
    return PaymentSession(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: PaymentSessionStatusX.fromString(json['status']?.toString()),
      checkoutUrl: json['checkoutUrl']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class PaymentConfirmationResult {
  const PaymentConfirmationResult({required this.payment, required this.order});

  final PaymentSession payment;
  final CafeOrder order;

  factory PaymentConfirmationResult.fromJson(JsonMap json) {
    final paymentJson = json['payment'];
    final orderJson = json['order'];

    if (paymentJson is! Map<String, dynamic> || orderJson is! Map<String, dynamic>) {
      throw const ApiException('Некорректный ответ API: подтверждение оплаты.');
    }

    return PaymentConfirmationResult(
      payment: PaymentSession.fromJson(paymentJson),
      order: CafeOrder.fromJson(orderJson),
    );
  }
}
