import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/techcafe_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/feedback_states.dart';
import '../widgets/guest_navigation_bar.dart';

class RecentOrdersScreen extends StatefulWidget {
  const RecentOrdersScreen({super.key});

  @override
  State<RecentOrdersScreen> createState() => _RecentOrdersScreenState();
}

class _RecentOrdersScreenState extends State<RecentOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechCafeState>().reloadRecentOrders();
    });
  }

  Future<void> _removeOrder(TechCafeState state, LocalOrderRecord order) async {
    try {
      await state.removeRecentOrder(order.orderId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заказ ${order.orderNumber} удален из истории')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить заказ из истории')),
      );
    }
  }

  Future<bool> _confirmRemoveOrder(LocalOrderRecord order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заказ?'),
        content: Text('Заказ ${order.orderNumber} будет удален из истории.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _confirmClearOrders(TechCafeState state) async {
    if (state.recentOrders.isEmpty) {
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все заказы будут удалены из локальной истории.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Очистить'),
          ),
        ],
      ),
    );

    if (result != true) {
      return;
    }

    try {
      await state.clearRecentOrders();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('История очищена')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось очистить историю')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TechCafeState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Мои заказы'),
            actions: [
              IconButton(
                onPressed: state.reloadRecentOrders,
                icon: const Icon(Icons.refresh),
              ),
              if (state.recentOrders.isNotEmpty)
                IconButton(
                  onPressed: () => _confirmClearOrders(state),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          bottomNavigationBar: useGuestBottomNavigation(context)
              ? GuestNavigationBar(
                  currentItem: GuestNavigationItem.orders,
                  cartItemsCount: state.cartItemsCount,
                )
              : null,
          body: state.recentOrders.isEmpty
              ? EmptyStatePanel(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'История заказов пуста',
                  description:
                      'Здесь появятся ваши последние заказы, чтобы их можно было быстро открыть снова.',
                  actionLabel: 'Перейти в меню',
                  onAction: () => context.go('/'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: state.recentOrders.length,
                  itemBuilder: (context, index) {
                    final order = state.recentOrders[index];
                    return Dismissible(
                      key: ValueKey(order.orderId),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmRemoveOrder(order),
                      onDismissed: (_) {
                        unawaited(_removeOrder(state, order));
                      },
                      background: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'Удалить',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: Card(
                        child: ListTile(
                          title: Text('Заказ ${order.orderNumber}'),
                          subtitle: Text(
                            '${order.status.label} • ${formatRub(order.total)}\n${order.createdAt.toLocal()}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            context.push('/tracking/${order.orderId}');
                          },
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
