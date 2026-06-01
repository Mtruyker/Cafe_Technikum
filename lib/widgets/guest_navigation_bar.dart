import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

bool get useGuestBottomNavigation =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

enum GuestNavigationItem {
  menu('/'),
  cart('/cart'),
  orders('/orders');

  const GuestNavigationItem(this.path);

  final String path;
}

class GuestNavigationBar extends StatelessWidget {
  const GuestNavigationBar({
    super.key,
    required this.currentItem,
    required this.cartItemsCount,
  });

  final GuestNavigationItem currentItem;
  final int cartItemsCount;

  @override
  Widget build(BuildContext context) {
    final cartLabel = cartItemsCount == 0
        ? 'Корзина пуста'
        : 'В корзине $cartItemsCount ${_cartItemsWord(cartItemsCount)}';

    return NavigationBar(
      selectedIndex: currentItem.index,
      onDestinationSelected: (index) {
        final nextItem = GuestNavigationItem.values[index];
        if (nextItem == currentItem) {
          return;
        }
        context.go(nextItem.path);
      },
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu),
          label: 'Меню',
        ),
        NavigationDestination(
          icon: Semantics(
            label: cartLabel,
            child: Badge(
              isLabelVisible: cartItemsCount > 0,
              label: Text('$cartItemsCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          selectedIcon: Semantics(
            label: cartLabel,
            child: Badge(
              isLabelVisible: cartItemsCount > 0,
              label: Text('$cartItemsCount'),
              child: const Icon(Icons.shopping_cart),
            ),
          ),
          label: 'Корзина',
        ),
        const NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Заказы',
        ),
      ],
    );
  }

  String _cartItemsWord(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) {
      return 'товаров';
    }
    if (mod10 == 1) {
      return 'товар';
    }
    if (mod10 >= 2 && mod10 <= 4) {
      return 'товара';
    }
    return 'товаров';
  }
}
