typedef JsonMap = Map<String, dynamic>;

enum OrderStatus { created, accepted, cooking, ready, issued, canceled }

extension OrderStatusX on OrderStatus {
  String get value => switch (this) {
    OrderStatus.created => 'created',
    OrderStatus.accepted => 'accepted',
    OrderStatus.cooking => 'cooking',
    OrderStatus.ready => 'ready',
    OrderStatus.issued => 'issued',
    OrderStatus.canceled => 'canceled',
  };

  static OrderStatus? fromValue(String? value) {
    for (final status in OrderStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}

enum PaymentMethod { payOnPickup, onlineCard }

extension PaymentMethodX on PaymentMethod {
  String get value => switch (this) {
    PaymentMethod.payOnPickup => 'pay_on_pickup',
    PaymentMethod.onlineCard => 'online_card',
  };

  static PaymentMethod? fromValue(String? value) {
    for (final method in PaymentMethod.values) {
      if (method.value == value) {
        return method;
      }
    }
    return null;
  }
}

enum PaymentStatus { unpaid, pending, paid, failed }

extension PaymentStatusX on PaymentStatus {
  String get value => switch (this) {
    PaymentStatus.unpaid => 'unpaid',
    PaymentStatus.pending => 'pending',
    PaymentStatus.paid => 'paid',
    PaymentStatus.failed => 'failed',
  };
}

enum PaymentSessionStatus { created, succeeded, failed }

extension PaymentSessionStatusX on PaymentSessionStatus {
  String get value => switch (this) {
    PaymentSessionStatus.created => 'created',
    PaymentSessionStatus.succeeded => 'succeeded',
    PaymentSessionStatus.failed => 'failed',
  };
}
