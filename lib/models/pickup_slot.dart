class PickupSlot {
  const PickupSlot({
    required this.id,
    required this.startsAt,
    required this.cutoffAt,
    required this.capacity,
    required this.remaining,
    required this.enabled,
  });
  final String id;
  final DateTime startsAt;
  final DateTime cutoffAt;
  final int capacity;
  final int remaining;
  final bool enabled;
  bool fits(int portions, DateTime now) =>
      enabled && cutoffAt.isAfter(now) && remaining >= portions;
  factory PickupSlot.fromJson(Map<String, dynamic> json) => PickupSlot(
    id: json['id'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    cutoffAt: DateTime.parse(json['cutoffAt'] as String),
    capacity: (json['capacity'] as num).toInt(),
    remaining: (json['remaining'] as num).toInt(),
    enabled: json['enabled'] == true,
  );
}
