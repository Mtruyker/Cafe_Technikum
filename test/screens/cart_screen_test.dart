import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/screens/cart_screen.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/local_orders_store_base.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';
import 'package:cafe_technikum/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockApiClient extends Mock implements ApiClientBase {}

class MockLocalOrdersStore extends Mock implements LocalOrdersStoreBase {}

class TestTechCafeState extends TechCafeState {
  TestTechCafeState({
    required super.apiClient,
    required super.localOrdersStore,
  });

  @override
  Future<void> initialize() async {
    isInitializing = false;
  }
}

void main() {
  late MockApiClient mockApi;
  late MockLocalOrdersStore mockStore;

  const category = Category(id: 'c1', name: 'Напитки', sort: 1);

  final product = Product.fromJson({
    'id': 'p1',
    'categoryId': 'c1',
    'name': 'Латте',
    'description': 'Кофе с молоком',
    'price': 200,
    'imageUrl': '',
    'isAvailable': true,
  });

  TechCafeState buildState() {
    final state = TestTechCafeState(
      apiClient: mockApi,
      localOrdersStore: mockStore,
    );
    state.categories = [category];
    state.products = [product];
    state.selectedCategoryId = category.id;
    state.addToCart(product, const []);
    return state;
  }

  Widget buildScreen(
    TechCafeState state, {
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: const Size(320, 560), viewInsets: viewInsets),
      child: ChangeNotifierProvider<TechCafeState>.value(
        value: state,
        child: MaterialApp(theme: AppTheme.student(), home: const CartScreen()),
      ),
    );
  }

  setUp(() {
    mockApi = MockApiClient();
    mockStore = MockLocalOrdersStore();
  });

  testWidgets('stays scrollable when keyboard is open on compact height', (
    tester,
  ) async {
    final state = buildState();

    await tester.binding.setSurfaceSize(const Size(320, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen(state));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(
      buildScreen(state, viewInsets: const EdgeInsets.only(bottom: 280)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.drag(
      find.byKey(const ValueKey('filled-cart')),
      const Offset(0, -220),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
