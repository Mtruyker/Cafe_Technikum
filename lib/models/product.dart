import '../utils/formatters.dart';

class ModifierItem {
  const ModifierItem({
    required this.id,
    required this.name,
    required this.priceDelta,
  });

  final String id;
  final String name;
  final double priceDelta;

  factory ModifierItem.fromJson(JsonMap json) {
    return ModifierItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      priceDelta: (json['priceDelta'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ModifierGroup {
  const ModifierGroup({
    required this.id,
    required this.name,
    required this.min,
    required this.max,
    required this.items,
  });

  final String id;
  final String name;
  final int min;
  final int max;
  final List<ModifierItem> items;

  factory ModifierGroup.fromJson(JsonMap json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];

    return ModifierGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      min: (json['min'] as num?)?.toInt() ?? 0,
      max: (json['max'] as num?)?.toInt() ?? 1,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(ModifierItem.fromJson)
          .toList(growable: false),
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.isAvailable,
    required this.modifierGroups,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool isAvailable;
  final List<ModifierGroup> modifierGroups;

  factory Product.fromJson(JsonMap json) {
    final rawGroups = json['modifierGroups'] as List<dynamic>? ?? const [];

    return Product(
      id: json['id']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['imageUrl']?.toString() ?? '',
      isAvailable: json['isAvailable'] as bool? ?? false,
      modifierGroups: rawGroups
          .whereType<Map<String, dynamic>>()
          .map(ModifierGroup.fromJson)
          .toList(growable: false),
    );
  }
}
