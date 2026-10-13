import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/local_orders_store_base.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';

class MockApi extends Mock implements ApiClientBase {}

class MockStore extends Mock implements LocalOrdersStoreBase {}

class TestState extends TechCafeState {
  TestState(ApiClientBase api)
    : super(apiClient: api, localOrdersStore: MockStore());
  @override
  Future<void> initialize() async {}
}

PaginatedResponse<CafeOrder> page(String id, {bool more = false}) =>
    PaginatedResponse(
      items: [
        CafeOrder.fromJson({'id': id, 'status': 'created'}),
      ],
      total: more ? 100 : 1,
      page: 1,
      limit: 20,
      hasMore: more,
    );

void main() {
  late MockApi api;
  late TestState state;
  setUp(() {
    api = MockApi();
    state = TestState(api)
      ..staffSession = const StaffSession(
        token: 'token',
        role: 'admin',
        name: 'Admin',
      );
  });
  tearDown(() => state.dispose());

  test(
    'silent refresh keeps filter and loaded page window without loading spinner',
    () async {
      when(
        () => api.fetchStaffOrders(
          token: 'token',
          status: 'ready',
          page: 1,
          limit: 20,
        ),
      ).thenAnswer((_) async => page('first', more: true));
      when(
        () => api.fetchStaffOrders(
          token: 'token',
          status: 'ready',
          page: 2,
          limit: 20,
        ),
      ).thenAnswer((_) async => page('second', more: true));
      when(
        () => api.fetchStaffOrders(
          token: 'token',
          status: 'ready',
          page: 1,
          limit: 40,
        ),
      ).thenAnswer((_) async => page('refreshed', more: true));
      await state.loadStaffOrders(status: 'ready');
      await state.loadMoreStaffOrders();
      var spinnerSeen = false;
      state.addListener(() {
        spinnerSeen |= state.isStaffOrdersLoading;
      });
      await state.refreshStaffOrdersSilently();
      verify(
        () => api.fetchStaffOrders(
          token: 'token',
          status: 'ready',
          page: 1,
          limit: 40,
        ),
      ).called(1);
      expect(state.staffStatusFilter, 'ready');
      expect(state.staffOrders.single.id, 'refreshed');
      expect(spinnerSeen, isFalse);
    },
  );

  test('late refresh cannot restore orders after logout', () async {
    final pending = Completer<PaginatedResponse<CafeOrder>>();
    when(
      () => api.fetchStaffOrders(
        token: 'token',
        status: null,
        page: 1,
        limit: 20,
      ),
    ).thenAnswer((_) => pending.future);
    when(() => api.logoutStaff()).thenAnswer((_) async {});
    final loading = state.refreshStaffOrdersSilently();
    state.logoutStaff();
    pending.complete(page('private'));
    await loading;
    expect(state.staffOrders, isEmpty);
    expect(state.staffSession, isNull);
  });

  test('manual filter change wins over an older realtime response', () async {
    final pending = Completer<PaginatedResponse<CafeOrder>>();
    when(
      () => api.fetchStaffOrders(
        token: 'token',
        status: null,
        page: 1,
        limit: 20,
      ),
    ).thenAnswer((_) => pending.future);
    when(
      () => api.fetchStaffOrders(
        token: 'token',
        status: 'ready',
        page: 1,
        limit: 20,
      ),
    ).thenAnswer((_) async => page('ready'));
    final loading = state.refreshStaffOrdersSilently();
    await state.loadStaffOrders(status: 'ready');
    pending.complete(page('old'));
    await loading;
    expect(state.staffOrders.single.id, 'ready');
    expect(state.staffStatusFilter, 'ready');
    expect(state.isStaffOrdersLoading, isFalse);
  });
}
