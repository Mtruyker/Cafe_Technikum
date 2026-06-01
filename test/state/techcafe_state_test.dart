import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/api_exception.dart';
import 'package:cafe_technikum/services/local_orders_store_base.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';

class MockApiClient extends Mock implements ApiClientBase {}

class MockLocalOrdersStore extends Mock implements LocalOrdersStoreBase {}

class FakeCartItem extends Fake implements CartItem {}

class FakeLocalOrderRecord extends Fake implements LocalOrderRecord {}

void main() {
  late MockApiClient mockApi;
  late MockLocalOrdersStore mockStore;

  final testCategories = [
    const Category(id: 'c1', name: 'Напитки', sort: 1),
    const Category(id: 'c2', name: 'Еда', sort: 2),
  ];

  final testProducts = [
    Product.fromJson({
      'id': 'p1',
      'categoryId': 'c1',
      'name': 'Латте',
      'price': 200,
      'isAvailable': true,
    }),
    Product.fromJson({
      'id': 'p2',
      'categoryId': 'c1',
      'name': 'Капучино',
      'price': 250,
      'isAvailable': true,
    }),
  ];

  PaginatedResponse<Product> paginatedProducts(List<Product> items) {
    return PaginatedResponse<Product>(
      items: items,
      total: items.length,
      page: 1,
      limit: 20,
      hasMore: false,
    );
  }

  PaginatedResponse<CafeOrder> paginatedOrders(List<CafeOrder> items) {
    return PaginatedResponse<CafeOrder>(
      items: items,
      total: items.length,
      page: 1,
      limit: 20,
      hasMore: false,
    );
  }

  CafeOrder buildOrder({
    required String id,
    required String orderNumber,
    required OrderStatus status,
  }) {
    return CafeOrder.fromJson({
      'id': id,
      'orderNumber': orderNumber,
      'createdAt': '2026-04-16T10:00:00.000Z',
      'status': status.value,
      'total': 250,
      'comment': '',
      'paymentMethod': 'pay_on_pickup',
      'paymentStatus': 'unpaid',
      'items': const [],
    });
  }

  OrderCreatedResponse buildCreatedResponse() {
    return OrderCreatedResponse.fromJson({
      'orderId': 'ord-created',
      'orderNumber': 'A-150',
      'qrCodeData': 'qr-created',
      'status': 'created',
      'total': 450.0,
      'createdAt': '2026-04-16T11:00:00.000Z',
      'paymentMethod': 'pay_on_pickup',
      'paymentStatus': 'unpaid',
    });
  }

  setUpAll(() {
    registerFallbackValue(FakeCartItem());
    registerFallbackValue(FakeLocalOrderRecord());
    registerFallbackValue(PaymentMethod.payOnPickup);
    registerFallbackValue(OrderStatus.created);
  });

  setUp(() {
    mockApi = MockApiClient();
    mockStore = MockLocalOrdersStore();

    when(() => mockStore.load()).thenAnswer((_) async => const []);
    when(() => mockApi.restoreStaffSession()).thenAnswer((_) async => null);
  });

  /// Creates a TechCafeState and waits for initialize() to complete.
  Future<TechCafeState> createState() async {
    when(
      () => mockApi.fetchCategories(),
    ).thenAnswer((_) async => testCategories);
    when(() => mockApi.restoreStaffSession()).thenAnswer((_) async => null);
    when(
      () => mockApi.fetchProducts(
        categoryId: any(named: 'categoryId'),
        inStockOnly: any(named: 'inStockOnly'),
        page: any(named: 'page'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => paginatedProducts(testProducts));

    final state = TechCafeState(
      apiClient: mockApi,
      localOrdersStore: mockStore,
    );

    // Wait for initialize() to complete
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    return state;
  }

  group('initialize', () {
    test('loads categories and products, sets selectedCategoryId', () async {
      final state = await createState();

      expect(state.isInitializing, false);
      expect(state.initializationError, isNull);
      expect(state.categories, hasLength(2));
      expect(state.products, hasLength(2));
      expect(state.selectedCategoryId, 'c1');
    });

    test('on ApiException sets initializationError to message', () async {
      when(() => mockApi.fetchCategories()).thenThrow(
        const ApiException('Сервер недоступен', kind: ApiErrorKind.network),
      );
      when(() => mockApi.restoreStaffSession()).thenAnswer((_) async => null);
      when(() => mockStore.load()).thenAnswer((_) async => const []);

      final state = TechCafeState(
        apiClient: mockApi,
        localOrdersStore: mockStore,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.isInitializing, false);
      expect(state.initializationError, 'Сервер недоступен');
    });

    test('on generic error sets fallback initializationError', () async {
      when(() => mockApi.fetchCategories()).thenThrow(Exception('oops'));
      when(() => mockApi.restoreStaffSession()).thenAnswer((_) async => null);
      when(() => mockStore.load()).thenAnswer((_) async => const []);

      final state = TechCafeState(
        apiClient: mockApi,
        localOrdersStore: mockStore,
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(state.isInitializing, false);
      expect(
        state.initializationError,
        'Нет соединения с сервером. Проверьте интернет.',
      );
    });
  });

  group('cart operations', () {
    test('addToCart adds new item', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);

      expect(state.cartItems, hasLength(1));
      expect(state.cartItems[0].product.id, 'p1');
      expect(state.cartItems[0].qty, 1);
    });

    test('addToCart increments qty for same signature', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);
      state.addToCart(testProducts[0], const []);

      expect(state.cartItems, hasLength(1));
      expect(state.cartItems[0].qty, 2);
    });

    test('addToCart creates separate items for different modifiers', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);
      state.addToCart(testProducts[0], const [
        SelectedModifier(name: 'Сахар', priceDelta: 10),
      ]);

      expect(state.cartItems, hasLength(2));
    });

    test('setCartItemQty updates quantity', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);
      state.setCartItemQty(state.cartItems[0], 5);

      expect(state.cartItems[0].qty, 5);
    });

    test('setCartItemQty with 0 removes item', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);
      state.setCartItemQty(state.cartItems[0], 0);

      expect(state.cartItems, isEmpty);
    });

    test('clearCart empties the cart', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);
      state.addToCart(testProducts[1], const []);
      state.clearCart();

      expect(state.cartItems, isEmpty);
    });

    test('placeOrder validates missing first name before transport', () async {
      final state = await createState();
      state.addToCart(testProducts[0], const []);

      expect(
        () => state.placeOrder(
          firstName: ' ',
          lastName: 'Петров',
          comment: '',
          paymentMethod: PaymentMethod.payOnPickup,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Укажите имя.',
          ),
        ),
      );

      verifyNever(
        () => mockApi.createOrder(
          items: any(named: 'items'),
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          comment: any(named: 'comment'),
          paymentMethod: any(named: 'paymentMethod'),
        ),
      );
    });

    test('placeOrder validates missing last name before transport', () async {
      final state = await createState();
      state.addToCart(testProducts[0], const []);

      expect(
        () => state.placeOrder(
          firstName: 'Иван',
          lastName: ' ',
          comment: '',
          paymentMethod: PaymentMethod.payOnPickup,
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Укажите фамилию.',
          ),
        ),
      );
    });

    test('placeOrder sends first and last name to api', () async {
      final state = await createState();
      state.addToCart(testProducts[0], const []);

      when(
        () => mockApi.createOrder(
          items: any(named: 'items'),
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
          comment: any(named: 'comment'),
          paymentMethod: any(named: 'paymentMethod'),
        ),
      ).thenAnswer((_) async => buildCreatedResponse());
      when(() => mockStore.save(any())).thenAnswer((_) async {});

      final response = await state.placeOrder(
        firstName: ' Иван ',
        lastName: ' Петров ',
        comment: 'Без сахара',
        paymentMethod: PaymentMethod.payOnPickup,
      );

      expect(response.orderId, 'ord-created');
      verify(
        () => mockApi.createOrder(
          items: any(named: 'items'),
          firstName: 'Иван',
          lastName: 'Петров',
          comment: 'Без сахара',
          paymentMethod: PaymentMethod.payOnPickup,
        ),
      ).called(1);
      verify(() => mockStore.save(any())).called(1);
      expect(state.cartItems, isEmpty);
    });
  });

  group('computed properties', () {
    test('cartItemsCount sums all quantities', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []);
      state.addToCart(testProducts[0], const []);
      state.addToCart(testProducts[1], const []);

      // p1 qty=2, p2 qty=1
      expect(state.cartItemsCount, 3);
    });

    test('cartTotal sums all lineTotals', () async {
      final state = await createState();

      state.addToCart(testProducts[0], const []); // 200
      state.addToCart(testProducts[0], const []); // 200 * 2 = 400
      state.addToCart(testProducts[1], const []); // 250

      expect(state.cartTotal, 650.0);
    });
  });

  group('selectCategory', () {
    test('changes selectedCategoryId and reloads products', () async {
      final state = await createState();

      await state.selectCategory('c2');

      expect(state.selectedCategoryId, 'c2');
      // fetchProducts called: once during init, once during selectCategory
      verify(
        () => mockApi.fetchProducts(
          categoryId: any(named: 'categoryId'),
          inStockOnly: any(named: 'inStockOnly'),
          page: any(named: 'page'),
          limit: any(named: 'limit'),
        ),
      ).called(2);
    });
  });

  group('visibleProducts', () {
    test('returns all products when searchQuery is empty', () async {
      final state = await createState();

      expect(state.visibleProducts, hasLength(2));
    });

    test('filters products by searchQuery', () async {
      final state = await createState();

      state.setSearchQuery('латте');

      expect(state.visibleProducts, hasLength(1));
      expect(state.visibleProducts[0].name, 'Латте');
    });

    test('case-insensitive search', () async {
      final state = await createState();

      state.setSearchQuery('КАПУЧИНО');

      expect(state.visibleProducts, hasLength(1));
      expect(state.visibleProducts[0].name, 'Капучино');
    });

    test('empty result for non-matching query', () async {
      final state = await createState();

      state.setSearchQuery('Чай');

      expect(state.visibleProducts, isEmpty);
    });
  });

  group('clearCompletedStaffOrders', () {
    test(
      'clears completed staff orders and reloads the list for admin',
      () async {
        final state = await createState();
        state.staffSession = const StaffSession(
          token: 'admin-token',
          role: 'admin',
          name: 'Admin',
        );
        state.staffOrders = [
          buildOrder(
            id: 'o1',
            orderNumber: 'A-101',
            status: OrderStatus.issued,
          ),
          buildOrder(
            id: 'o2',
            orderNumber: 'A-102',
            status: OrderStatus.accepted,
          ),
        ];

        when(
          () => mockApi.clearCompletedStaffOrders(token: 'admin-token'),
        ).thenAnswer((_) async => 1);
        when(
          () => mockApi.fetchStaffOrders(
            token: 'admin-token',
            status: any(named: 'status'),
            page: 1,
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => paginatedOrders([
            buildOrder(
              id: 'o2',
              orderNumber: 'A-102',
              status: OrderStatus.accepted,
            ),
          ]),
        );

        final clearedCount = await state.clearCompletedStaffOrders();

        expect(clearedCount, 1);
        expect(state.isClearingCompletedStaffOrders, false);
        expect(state.staffOrders, hasLength(1));
        expect(state.staffOrders.single.id, 'o2');
        verify(
          () => mockApi.clearCompletedStaffOrders(token: 'admin-token'),
        ).called(1);
        verify(
          () => mockApi.fetchStaffOrders(
            token: 'admin-token',
            status: null,
            page: 1,
            limit: any(named: 'limit'),
          ),
        ).called(1);
      },
    );
  });
}
