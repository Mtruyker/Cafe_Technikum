import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/api_exception.dart';
import 'package:cafe_technikum/services/local_orders_store.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';

class MockApi extends Mock implements ApiClientBase {}

class TestState extends TechCafeState {
  TestState({required super.apiClient, required super.localOrdersStore});
  @override
  Future<void> initialize() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'ready notification is emitted once and pickup secret survives tracking save',
    () async {
      final api = MockApi();
      final store = LocalOrdersStore();
      final record = LocalOrderRecord(
        orderId: 'id',
        orderNumber: 'A1',
        createdAt: DateTime.now(),
        total: 100,
        status: OrderStatus.cooking,
        pickupCode: 'techcafe:pickup:secret',
      );
      await store.save(record);
      final state = TestState(apiClient: api, localOrdersStore: store);
      addTearDown(state.dispose);
      await state.reloadRecentOrders();
      when(() => api.getOrder('id')).thenAnswer(
        (_) async => CafeOrder.fromJson({
          'id': 'id',
          'orderNumber': 'A1',
          'status': 'ready',
        }),
      );
      expect(
        (await state.refreshOrderNotifications()).single.status,
        OrderStatus.ready,
      );
      expect(await state.refreshOrderNotifications(), isEmpty);
      await store.save(
        LocalOrderRecord(
          orderId: 'id',
          orderNumber: 'A1',
          createdAt: record.createdAt,
          total: 100,
          status: OrderStatus.ready,
        ),
      );
      expect((await store.load()).single.pickupCode, record.pickupCode);
      expect((await store.load()).single.status, OrderStatus.ready);
    },
  );
  test(
    'network failure preserves status and retries; completed orders are skipped',
    () async {
      final api = MockApi();
      final store = LocalOrdersStore();
      await store.save(
        LocalOrderRecord(
          orderId: 'id',
          orderNumber: 'A1',
          createdAt: DateTime.now(),
          total: 100,
          status: OrderStatus.cooking,
        ),
      );
      final state = TestState(apiClient: api, localOrdersStore: store);
      addTearDown(state.dispose);
      await state.reloadRecentOrders();
      when(() => api.getOrder('id')).thenThrow(const ApiException('network'));
      expect(await state.refreshOrderNotifications(), isEmpty);
      expect(state.recentOrders.single.status, OrderStatus.cooking);
      when(() => api.getOrder('id')).thenAnswer(
        (_) async => CafeOrder.fromJson({'id': 'id', 'status': 'issued'}),
      );
      expect(await state.refreshOrderNotifications(), isEmpty);
      expect(await state.refreshOrderNotifications(), isEmpty);
      verify(() => api.getOrder('id')).called(2);
    },
  );
}
