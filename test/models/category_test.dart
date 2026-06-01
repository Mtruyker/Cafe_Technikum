import 'package:flutter_test/flutter_test.dart';
import 'package:cafe_technikum/models/category.dart';

void main() {
  group('Category.fromJson', () {
    test('parses correct JSON', () {
      final category = Category.fromJson({
        'id': '1',
        'name': 'Напитки',
        'sort': 10,
      });

      expect(category.id, '1');
      expect(category.name, 'Напитки');
      expect(category.sort, 10);
    });

    test('converts numeric id to string', () {
      final category = Category.fromJson({
        'id': 42,
        'name': 'Еда',
        'sort': 5,
      });

      expect(category.id, '42');
    });

    test('handles null and missing fields with defaults', () {
      final category = Category.fromJson({});

      expect(category.id, '');
      expect(category.name, '');
      expect(category.sort, 0);
    });

    test('handles null values', () {
      final category = Category.fromJson({
        'id': null,
        'name': null,
        'sort': null,
      });

      expect(category.id, '');
      expect(category.name, '');
      expect(category.sort, 0);
    });
  });
}
