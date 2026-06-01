enum OrderStatus {
  created,
  accepted,
  cooking,
  ready,
  issued,
  canceled,
  unknown,
}

extension OrderStatusX on OrderStatus {
  String get value {
    switch (this) {
      case OrderStatus.created:
        return 'created';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.cooking:
        return 'cooking';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.issued:
        return 'issued';
      case OrderStatus.canceled:
        return 'canceled';
      case OrderStatus.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.created:
        return 'Создан';
      case OrderStatus.accepted:
        return 'Принят';
      case OrderStatus.cooking:
        return 'Готовится';
      case OrderStatus.ready:
        return 'Готов';
      case OrderStatus.issued:
        return 'Выдан';
      case OrderStatus.canceled:
        return 'Отменен';
      case OrderStatus.unknown:
        return 'Неизвестно';
    }
  }

  static OrderStatus fromString(String? value) {
    return switch (value) {
      'created' => OrderStatus.created,
      'accepted' => OrderStatus.accepted,
      'cooking' => OrderStatus.cooking,
      'ready' => OrderStatus.ready,
      'issued' => OrderStatus.issued,
      'canceled' => OrderStatus.canceled,
      _ => OrderStatus.unknown,
    };
  }
}

enum PaymentMethod { payOnPickup, onlineCard, unknown }

extension PaymentMethodX on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.payOnPickup:
        return 'pay_on_pickup';
      case PaymentMethod.onlineCard:
        return 'online_card';
      case PaymentMethod.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.payOnPickup:
        return 'При получении';
      case PaymentMethod.onlineCard:
        return 'Онлайн картой';
      case PaymentMethod.unknown:
        return 'Неизвестно';
    }
  }

  static PaymentMethod fromString(String? value) {
    return switch (value) {
      'pay_on_pickup' => PaymentMethod.payOnPickup,
      'online_card' => PaymentMethod.onlineCard,
      _ => PaymentMethod.unknown,
    };
  }
}

enum PaymentStatus { unpaid, pending, paid, failed, unknown }

extension PaymentStatusX on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Не оплачено';
      case PaymentStatus.pending:
        return 'Ожидает оплаты';
      case PaymentStatus.paid:
        return 'Оплачено';
      case PaymentStatus.failed:
        return 'Ошибка оплаты';
      case PaymentStatus.unknown:
        return 'Неизвестно';
    }
  }

  static PaymentStatus fromString(String? value) {
    return switch (value) {
      'unpaid' => PaymentStatus.unpaid,
      'pending' => PaymentStatus.pending,
      'paid' => PaymentStatus.paid,
      'failed' => PaymentStatus.failed,
      _ => PaymentStatus.unknown,
    };
  }
}

enum PaymentSessionStatus { created, succeeded, failed, unknown }

extension PaymentSessionStatusX on PaymentSessionStatus {
  String get value {
    switch (this) {
      case PaymentSessionStatus.created:
        return 'created';
      case PaymentSessionStatus.succeeded:
        return 'succeeded';
      case PaymentSessionStatus.failed:
        return 'failed';
      case PaymentSessionStatus.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case PaymentSessionStatus.created:
        return 'Создана';
      case PaymentSessionStatus.succeeded:
        return 'Успешно';
      case PaymentSessionStatus.failed:
        return 'Ошибка';
      case PaymentSessionStatus.unknown:
        return 'Неизвестно';
    }
  }

  static PaymentSessionStatus fromString(String? value) {
    return switch (value) {
      'created' => PaymentSessionStatus.created,
      'succeeded' => PaymentSessionStatus.succeeded,
      'failed' => PaymentSessionStatus.failed,
      _ => PaymentSessionStatus.unknown,
    };
  }
}
