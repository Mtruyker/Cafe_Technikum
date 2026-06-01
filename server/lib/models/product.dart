import 'enums.dart';

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

  Product copyWith({
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    List<ModifierGroup>? modifierGroups,
  }) {
    return Product(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      modifierGroups: modifierGroups ?? this.modifierGroups,
    );
  }

  JsonMap toJson() {
    return {
      'id': id,
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'modifierGroups': modifierGroups
          .map((group) => group.toJson())
          .toList(growable: false),
    };
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

  JsonMap toJson() {
    return {
      'id': id,
      'name': name,
      'min': min,
      'max': max,
      'items': items.map((item) => item.toJson()).toList(growable: false),
    };
  }
}

class ModifierItem {
  const ModifierItem({
    required this.id,
    required this.name,
    required this.priceDelta,
  });

  final String id;
  final String name;
  final double priceDelta;

  JsonMap toJson() {
    return {'id': id, 'name': name, 'priceDelta': priceDelta};
  }
}
