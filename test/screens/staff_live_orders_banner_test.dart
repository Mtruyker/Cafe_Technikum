import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/staff_orders_live_controller.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';
import 'package:cafe_technikum/widgets/staff_live_orders_banner.dart';

class MockApi extends Mock implements ApiClientBase {}

class MockState extends Mock implements TechCafeState {}

void main() {
  testWidgets('admin sees new order on another tab and can open orders', (
    tester,
  ) async {
    final api = MockApi();
    final state = MockState();
    final signals = StreamController<StaffRealtimeSignal>();
    final live = StaffOrdersLiveController(
      api: api,
      refreshOrders: () async {},
    );
    when(() => state.isAdmin).thenReturn(true);
    when(() => state.createStaffOrdersLiveController()).thenReturn(live);
    when(() => api.watchStaffOrderChanges()).thenAnswer((_) => signals.stream);
    when(() => api.pollStaffOrderEvents(after: null)).thenAnswer(
      (_) async =>
          const StaffOrderEventBatch(cursor: 0, events: [], hasMore: false),
    );
    when(() => api.pollStaffOrderEvents(after: 0)).thenAnswer(
      (_) async => StaffOrderEventBatch(
        cursor: 1,
        events: [
          StaffOrderEvent(
            kind: 'created',
            orderId: 'id',
            order: CafeOrder.fromJson({
              'id': 'id',
              'orderNumber': 'A-999',
              'status': 'created',
            }),
          ),
        ],
        hasMore: false,
      ),
    );
    when(() => api.pollStaffOrderEvents(after: 1)).thenAnswer(
      (_) async =>
          const StaffOrderEventBatch(cursor: 1, events: [], hasMore: false),
    );
    var opened = false;
    await tester.pumpWidget(
      ChangeNotifierProvider<TechCafeState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StaffLiveOrdersBanner(onShowOrders: () => opened = true),
                const Expanded(child: Text('Отчёты')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Новый заказ A-999'), findsNothing);
    signals.add(StaffRealtimeSignal.changed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Отчёты'), findsOneWidget);
    expect(find.text('Новый заказ A-999'), findsOneWidget);
    expect(find.textContaining('Новых заказов: 1'), findsOneWidget);
    await tester.tap(find.text('Показать'));
    await tester.pump();
    expect(opened, isTrue);
    expect(find.textContaining('Новых заказов: 1'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    unawaited(signals.close());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
