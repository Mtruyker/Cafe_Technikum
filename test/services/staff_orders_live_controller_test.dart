import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/staff_orders_live_controller.dart';

class MockApi extends Mock implements ApiClientBase {}

StaffOrderEventBatch batch(
  int cursor, {
  List<StaffOrderEvent> events = const [],
  bool more = false,
}) => StaffOrderEventBatch(cursor: cursor, events: events, hasMore: more);
StaffOrderEvent event(String kind, String id) => StaffOrderEvent(
  kind: kind,
  orderId: id,
  order: CafeOrder.fromJson({
    'id': id,
    'orderNumber': 'A-$id',
    'status': 'created',
  }),
);

void main() {
  test(
    'baseline is silent, new orders deduplicated, updates do not alert',
    () async {
      final api = MockApi();
      var refreshes = 0;
      final live = StaffOrdersLiveController(
        api: api,
        refreshOrders: () async {
          refreshes++;
        },
      );
      addTearDown(live.dispose);
      final alerts = <List<CafeOrder>>[];
      live.notifications.listen(alerts.add);
      when(
        () => api.pollStaffOrderEvents(after: null),
      ).thenAnswer((_) async => batch(10));
      await live.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(alerts, isEmpty);
      when(() => api.pollStaffOrderEvents(after: 10)).thenAnswer(
        (_) async => batch(
          13,
          events: [
            event('created', '1'),
            event('updated', '1'),
            event('created', '1'),
          ],
        ),
      );
      await live.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(alerts.single.map((o) => o.id), ['1']);
      when(
        () => api.pollStaffOrderEvents(after: 13),
      ).thenAnswer((_) async => batch(14, events: [event('updated', '1')]));
      await live.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(alerts.length, 1);
      expect(refreshes, 3);
    },
  );

  test(
    'drains journal pages and preserves cursor until visible refresh succeeds',
    () async {
      final api = MockApi();
      var fail = false;
      final live = StaffOrdersLiveController(
        api: api,
        refreshOrders: () async {
          if (fail) throw StateError('offline');
        },
      );
      addTearDown(live.dispose);
      final alerts = <List<CafeOrder>>[];
      live.notifications.listen(alerts.add);
      when(
        () => api.pollStaffOrderEvents(after: null),
      ).thenAnswer((_) async => batch(0));
      await live.refresh();
      when(() => api.pollStaffOrderEvents(after: 0)).thenAnswer(
        (_) async => batch(1, events: [event('created', '1')], more: true),
      );
      when(
        () => api.pollStaffOrderEvents(after: 1),
      ).thenAnswer((_) async => batch(2, events: [event('created', '2')]));
      fail = true;
      await live.refresh();
      expect(live.hasError, isTrue);
      expect(alerts, isEmpty);
      fail = false;
      await live.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(alerts.single.map((o) => o.id), ['1', '2']);
      expect(live.hasError, isFalse);
      verify(() => api.pollStaffOrderEvents(after: 0)).called(2);
    },
  );

  test('late response after disposal neither refreshes nor alerts', () async {
    final api = MockApi();
    final pending = Completer<StaffOrderEventBatch>();
    var refreshes = 0;
    when(
      () => api.pollStaffOrderEvents(after: null),
    ).thenAnswer((_) => pending.future);
    final live = StaffOrdersLiveController(
      api: api,
      refreshOrders: () async {
        refreshes++;
      },
    );
    final running = live.refresh();
    live.dispose();
    pending.complete(batch(1));
    await running;
    expect(refreshes, 0);
  });

  testWidgets(
    'realtime wakes refresh and timer recovers missed changes without parallel requests',
    (tester) async {
      final api = MockApi();
      final signals = StreamController<StaffRealtimeSignal>();
      when(
        () => api.watchStaffOrderChanges(),
      ).thenAnswer((_) => signals.stream);
      when(
        () => api.pollStaffOrderEvents(after: any(named: 'after')),
      ).thenAnswer((_) async => batch(1));
      var refreshes = 0;
      final live = StaffOrdersLiveController(
        api: api,
        refreshOrders: () async {
          refreshes++;
        },
      );
      live.start();
      await tester.pump();
      expect(refreshes, 1);
      signals.add(StaffRealtimeSignal.connected);
      signals.add(StaffRealtimeSignal.changed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(live.connected, isTrue);
      expect(refreshes, 2);
      await tester.pump(const Duration(seconds: 10));
      expect(refreshes, 3);
      live.dispose();
      unawaited(signals.close());
      await tester.pump();
    },
  );
}
