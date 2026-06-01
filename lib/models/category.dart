import '../utils/formatters.dart';

class Category {
  const Category({required this.id, required this.name, required this.sort});

  final String id;
  final String name;
  final int sort;

  factory Category.fromJson(JsonMap json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sort: (json['sort'] as num?)?.toInt() ?? 0,
    );
  }
}
