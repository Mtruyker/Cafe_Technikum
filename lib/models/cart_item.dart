import '../utils/formatters.dart';
import 'product.dart';

class SelectedModifier {
  const SelectedModifier({required this.name, required this.priceDelta});

  final String name;
  final double priceDelta;

  JsonMap toOrderJson() {
    return {'name': name, 'priceDelta': priceDelta};
  }

  factory SelectedModifier.fromJson(JsonMap json) {
    return SelectedModifier(
      name: json['name']?.toString() ?? '',
      priceDelta: (json['priceDelta'] as num?)?.toDouble() ?? 0,
    );
  }

  JsonMap toJson() {
    return {'name': name, 'priceDelta': priceDelta};
  }
}

class CartItem {
  const CartItem({
    required this.product,
    required this.modifiers,
    required this.qty,
  });

  final Product product;
  final List<SelectedModifier> modifiers;
  final int qty;

  double get unitPrice {
    final delta = modifiers.fold<double>(
      0,
      (sum, modifier) => sum + modifier.priceDelta,
    );
    return product.price + delta;
  }

  double get lineTotal => unitPrice * qty;

  String get signature {
    final sorted = [...modifiers]..sort((a, b) => a.name.compareTo(b.name));
    final modifierKey = sorted
        .map((item) => '${item.name}:${item.priceDelta}')
        .join('|');
    return '${product.id}::$modifierKey';
  }

  CartItem copyWith({int? qty}) {
    return CartItem(
      product: product,
      modifiers: modifiers,
      qty: qty ?? this.qty,
    );
  }

  JsonMap toOrderJson() {
    return {
      'productId': product.id,
      'qty': qty,
      'modifiers': modifiers.map((item) => item.toOrderJson()).toList(),
    };
  }
}
