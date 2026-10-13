import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/screens/home_screen.dart';
import 'package:cafe_technikum/services/api_client_base.dart';
import 'package:cafe_technikum/services/local_orders_store_base.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';
import 'package:cafe_technikum/theme.dart';
import 'package:cafe_technikum/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockApi extends Mock implements ApiClientBase {}

class MockStore extends Mock implements LocalOrdersStoreBase {}

class MenuState extends TechCafeState {
  MenuState() : super(apiClient: MockApi(), localOrdersStore: MockStore());
  @override
  Future<void> initialize() async {
    isInitializing = false;
  }
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(1200, 900),
    const Size(700, 500),
    const Size(390, 840),
  ]) {
    testWidgets('menu lays out at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      debugDefaultTargetPlatformOverride = size.width == 1200
          ? TargetPlatform.windows
          : TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final state = MenuState();
      state.isInitializing = false;
      state.categories = [const Category(id: 'coffee', name: 'Кофе', sort: 0)];
      state.selectedCategoryId = 'coffee';
      state.products = List.generate(
        6,
        (i) => Product.fromJson({
          'id': '$i',
          'categoryId': 'coffee',
          'name': 'Капучино с молоком',
          'description': 'Эспрессо и нежная молочная пенка',
          'price': 180,
          'isAvailable': true,
        }),
      );
      state.addToCart(state.products.first, []);
      await tester.pumpWidget(
        ChangeNotifierProvider<TechCafeState>.value(
          value: state,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(size.width == 390 ? 2 : 1),
              ),
              child: child!,
            ),
            theme: AppTheme.student(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Панель персонала'), findsOneWidget);
      expect(find.textContaining('Корзина · 1'), findsOneWidget);
      final cards = find.byType(ProductCard);
      if (size.width >= 700) {
        expect(
          tester.getTopLeft(cards.at(0)).dy,
          tester.getTopLeft(cards.at(1)).dy,
        );
        expect(
          tester.getTopLeft(cards.at(1)).dx,
          greaterThan(tester.getTopLeft(cards.at(0)).dx),
        );
      }
      await tester.pumpWidget(const SizedBox());
      state.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
