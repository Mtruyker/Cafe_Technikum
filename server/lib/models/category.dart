import 'enums.dart';

class Category {
  const Category({required this.id, required this.name, required this.sort});

  final String id;
  final String name;
  final int sort;

  JsonMap toJson() {
    return {'id': id, 'name': name, 'sort': sort};
  }
}
