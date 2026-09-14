import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/models.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_success_screen.dart';
import 'screens/recent_orders_screen.dart';
import 'screens/staff_panel_screen.dart';
import 'screens/tracking_screen.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const HomeScreen()),
    ),
    GoRoute(
      path: '/cart',
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const CartScreen()),
    ),
    GoRoute(
      path: '/order-success',
      // A browser refresh or direct link can lose the in-memory order result.
      redirect: (context, state) =>
          state.extra is OrderCreatedResponse ? null : '/orders',
      pageBuilder: (context, state) {
        final result = state.extra! as OrderCreatedResponse;
        return _buildTransitionPage(
          state: state,
          child: OrderSuccessScreen(result: result),
        );
      },
    ),
    GoRoute(
      path: '/tracking',
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const TrackingScreen()),
    ),
    GoRoute(
      path: '/tracking/:orderId',
      pageBuilder: (context, state) {
        final orderId = state.pathParameters['orderId']!;
        return _buildTransitionPage(
          state: state,
          child: TrackingScreen(initialValue: orderId),
        );
      },
    ),
    GoRoute(
      path: '/orders',
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const RecentOrdersScreen()),
    ),
    GoRoute(
      path: '/staff',
      pageBuilder: (context, state) =>
          _buildTransitionPage(state: state, child: const StaffPanelScreen()),
    ),
  ],
);

CustomTransitionPage<void> _buildTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 360),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(curvedAnimation);
      final scaleAnimation = Tween<double>(
        begin: 0.985,
        end: 1,
      ).animate(curvedAnimation);

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        ),
      );
    },
  );
}
