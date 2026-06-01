import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/product.dart';

void main() {
  group('ModifierItem.fromJson', () {
    test('parses correct JSON', () {
      final item = ModifierItem.fromJson({
        'id': 'm1',
        'name': 'Сахар',
        'priceDelta': 10.0,
      });

      expect(item.id, 'm1');
      expect(item.name, 'Сахар');
      expect(item.priceDelta, 10.0);
    });

    test('handles missing fields with defaults', () {
      final item = ModifierItem.fromJson({});

      expect(item.id, '');
      expect(item.name, '');
      expect(item.priceDelta, 0);
    });
  });

  group('ModifierGroup.fromJson', () {
    test('parses correct JSON with items', () {
      final group = ModifierGroup.fromJson({
        'id': 'g1',
        'name': 'Добавки',
        'min': 0,
        'max': 3,
        'items': [
          {'id': 'm1', 'name': 'Сахар', 'priceDelta': 10},
          {'id': 'm2', 'name': 'Молоко', 'priceDelta': 20},
        ],
      });

      expect(group.id, 'g1');
      expect(group.name, 'Добавки');
      expect(group.min, 0);
      expect(group.max, 3);
      expect(group.items, hasLength(2));
      expect(group.items[0].name, 'Сахар');
      expect(group.items[1].name, 'Молоко');
    });

    test('handles null items list', () {
      final group = ModifierGroup.fromJson({
        'id': 'g1',
        'name': 'Добавки',
      });

      expect(group.items, isEmpty);
      expect(group.max, 1);
    });

    test('handles empty map', () {
      final group = ModifierGroup.fromJson({});

      expect(group.id, '');
      expect(group.name, '');
      expect(group.min, 0);
      expect(group.max, 1);
      expect(group.items, isEmpty);
    });
  });

  group('Product.fromJson', () {
    test('parses full JSON with modifierGroups', () {
      final product = Product.fromJson({
        'id': 'p1',
        'categoryId': 'c1',
        'name': 'Латте',
        'description': 'Кофе с молоком',
        'price': 250.0,
        'imageUrl': 'https://example.com/latte.png',
        'isAvailable': true,
        'modifierGroups': [
          {
            'id': 'g1',
            'name': 'Добавки',
            'min': 0,
            'max': 2,
            'items': [
              {'id': 'm1', 'name': 'Сахар', 'priceDelta': 0},
            ],
          },
        ],
      });

      expect(product.id, 'p1');
      expect(product.categoryId, 'c1');
      expect(product.name, 'Латте');
      expect(product.description, 'Кофе с молоком');
      expect(product.price, 250.0);
      expect(product.imageUrl, 'https://example.com/latte.png');
      expect(product.isAvailable, true);
      expect(product.modifierGroups, hasLength(1));
      expect(product.modifierGroups[0].items, hasLength(1));
    });

    test('handles missing/null fields with defaults', () {
      final product = Product.fromJson({});

      expect(product.id, '');
      expect(product.categoryId, '');
      expect(product.name, '');
      expect(product.description, '');
      expect(product.price, 0);
      expect(product.imageUrl, '');
      expect(product.isAvailable, false);
      expect(product.modifierGroups, isEmpty);
    });

    test('handles null isAvailable as false', () {
      final product = Product.fromJson({'isAvailable': null});
      expect(product.isAvailable, false);
    });
  });
}
