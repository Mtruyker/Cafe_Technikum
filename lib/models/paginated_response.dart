class PaginatedResponse<T> {
  const PaginatedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawItems = json['items'] as List;
    return PaginatedResponse<T>(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(fromJsonT)
          .toList(growable: false),
      total: (json['total'] as num).toInt(),
      page: (json['page'] as num).toInt(),
      limit: (json['limit'] as num).toInt(),
      hasMore: json['hasMore'] as bool,
    );
  }
}
