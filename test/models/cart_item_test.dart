import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/cart_item.dart';
import 'package:cafe_technikum/models/product.dart';

void main() {
  group('SelectedModifier', () {
    test('fromJson parses correctly', () {
      final mod = SelectedModifier.fromJson({
        'name': 'Сахар',
        'priceDelta': 15.0,
      });

      expect(mod.name, 'Сахар');
      expect(mod.priceDelta, 15.0);
    });

    test('fromJson handles missing fields', () {
      final mod = SelectedModifier.fromJson({});

      expect(mod.name, '');
      expect(mod.priceDelta, 0);
    });

    test('toJson returns correct map', () {
      const mod = SelectedModifier(name: 'Молоко', priceDelta: 20);
      final json = mod.toJson();

      expect(json, {'name': 'Молоко', 'priceDelta': 20});
    });

    test('toOrderJson returns correct map', () {
      const mod = SelectedModifier(name: 'Молоко', priceDelta: 20);
      final json = mod.toOrderJson();

      expect(json, {'name': 'Молоко', 'priceDelta': 20});
    });

    test('fromJson/toJson roundtrip', () {
      const original = SelectedModifier(name: 'Сироп', priceDelta: 30);
      final restored = SelectedModifier.fromJson(original.toJson());

      expect(restored.name, original.name);
      expect(restored.priceDelta, original.priceDelta);
    });
  });

  group('CartItem', () {
    final product = Product.fromJson({
      'id': 'p1',
      'categoryId': 'c1',
      'name': 'Латте',
      'price': 200.0,
      'isAvailable': true,
    });

    const modifiers = [
      SelectedModifier(name: 'Сахар', priceDelta: 10),
      SelectedModifier(name: 'Молоко', priceDelta: 20),
    ];

    test('unitPrice = product.price + sum of modifier deltas', () {
      final item = CartItem(product: product, modifiers: modifiers, qty: 1);
      expect(item.unitPrice, 230.0);
    });

    test('unitPrice without modifiers = product.price', () {
      final item = CartItem(product: product, modifiers: const [], qty: 1);
      expect(item.unitPrice, 200.0);
    });

    test('lineTotal = unitPrice * qty', () {
      final item = CartItem(product: product, modifiers: modifiers, qty: 3);
      expect(item.lineTotal, 690.0);
    });

    test('signature is deterministic regardless of modifier order', () {
      const modsA = [
        SelectedModifier(name: 'Молоко', priceDelta: 20),
        SelectedModifier(name: 'Сахар', priceDelta: 10),
      ];
      const modsB = [
        SelectedModifier(name: 'Сахар', priceDelta: 10),
        SelectedModifier(name: 'Молоко', priceDelta: 20),
      ];

      final itemA = CartItem(product: product, modifiers: modsA, qty: 1);
      final itemB = CartItem(product: product, modifiers: modsB, qty: 1);

      expect(itemA.signature, itemB.signature);
    });

    test('signature differs for different products', () {
      final product2 = Product.fromJson({
        'id': 'p2',
        'categoryId': 'c1',
        'name': 'Капучино',
        'price': 200.0,
        'isAvailable': true,
      });

      final item1 = CartItem(product: product, modifiers: const [], qty: 1);
      final item2 = CartItem(product: product2, modifiers: const [], qty: 1);

      expect(item1.signature, isNot(item2.signature));
    });

    test('copyWith changes qty', () {
      final item = CartItem(product: product, modifiers: modifiers, qty: 1);
      final updated = item.copyWith(qty: 5);

      expect(updated.qty, 5);
      expect(updated.product, same(product));
      expect(updated.modifiers, same(modifiers));
    });

    test('copyWith without args keeps same qty', () {
      final item = CartItem(product: product, modifiers: modifiers, qty: 3);
      final copy = item.copyWith();

      expect(copy.qty, 3);
    });

    test('toOrderJson returns correct structure', () {
      final item = CartItem(product: product, modifiers: modifiers, qty: 2);
      final json = item.toOrderJson();

      expect(json['productId'], 'p1');
      expect(json['qty'], 2);
      expect(json['modifiers'], hasLength(2));
      expect(
        json['modifiers'][0],
        {'name': 'Сахар', 'priceDelta': 10},
      );
    });
  });
}
