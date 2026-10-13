import 'order.dart';

enum StaffRealtimeSignal { changed, connected, disconnected }

class StaffOrderEvent {
  const StaffOrderEvent({
    required this.kind,
    required this.orderId,
    this.order,
  });
  final String kind;
  final String orderId;
  final CafeOrder? order;

  factory StaffOrderEvent.fromJson(Map<String, dynamic> json) =>
      StaffOrderEvent(
        kind: json['kind'] as String,
        orderId: json['orderId'] as String,
        order: json['order'] == null
            ? null
            : CafeOrder.fromJson(
                Map<String, dynamic>.from(json['order'] as Map),
              ),
      );
}

class StaffOrderEventBatch {
  const StaffOrderEventBatch({
    required this.cursor,
    required this.events,
    required this.hasMore,
  });
  final int cursor;
  final List<StaffOrderEvent> events;
  final bool hasMore;

  factory StaffOrderEventBatch.fromJson(Map<String, dynamic> json) =>
      StaffOrderEventBatch(
        cursor: (json['cursor'] as num).toInt(),
        events: (json['events'] as List)
            .map(
              (e) =>
                  StaffOrderEvent.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        hasMore: json['hasMore'] == true,
      );
}
