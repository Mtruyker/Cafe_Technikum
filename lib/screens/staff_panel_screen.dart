import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/feedback_states.dart';
import '../widgets/loading_placeholders.dart';
import '../widgets/order_status_badge.dart';
import '../widgets/staff_report_charts.dart';
import '../widgets/validated_form_fields.dart';

class StaffPanelScreen extends StatefulWidget {
  const StaffPanelScreen({super.key});

  @override
  State<StaffPanelScreen> createState() => _StaffPanelScreenState();
}

class _StaffPanelScreenState extends State<StaffPanelScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int _tabIndex = 0;

  static const List<String> _statusFilters = [
    '',
    'created',
    'accepted',
    'cooking',
    'ready',
    'issued',
    'canceled',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TechCafeState>(
      builder: (context, state, _) {
        final session = state.staffSession;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              session == null
                  ? 'Вход персонала'
                  : 'Панель персонала (${_roleLabel(session.role)})',
            ),
            actions: [
              if (session != null)
                IconButton(
                  onPressed: () => _refreshCurrentTab(state),
                  icon: const Icon(Icons.refresh),
                ),
              if (session != null)
                IconButton(
                  onPressed: () {
                    state.logoutStaff();
                    setState(() {
                      _tabIndex = 0;
                    });
                  },
                  icon: const Icon(Icons.logout),
                ),
            ],
          ),
          body: session == null ? _buildLogin(state) : _buildPanel(state),
          bottomNavigationBar: session != null && state.isAdmin
              ? NavigationBar(
                  selectedIndex: _tabIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _tabIndex = index;
                    });
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long),
                      label: 'Заказы',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2),
                      label: 'Товары',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights),
                      label: 'Отчеты',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _buildLogin(TechCafeState state) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          margin: const EdgeInsets.all(AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Form(
              key: _loginFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Вход персонала',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const Text('Введите логин и пароль сотрудника'),
                  const SizedBox(height: AppSpacing.xxs),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: RequiredFieldsHint(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BlurValidatedTextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final normalized = value?.trim() ?? '';
                      if (normalized.isEmpty) {
                        return 'Введите email';
                      }
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(normalized)) {
                        return 'Введите корректный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BlurValidatedTextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(state),
                    decoration: const InputDecoration(
                      labelText: 'Пароль *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      return null;
                    },
                  ),
                  if (state.staffError != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    ErrorStateCard(
                      title: 'Не удалось войти',
                      message: state.staffError!,
                      onRetry: () => _login(state),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: state.isStaffAuthLoading
                        ? null
                        : () => _login(state),
                    child: state.isStaffAuthLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Войти'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(TechCafeState state) {
    if (!state.isAdmin) {
      return _buildOrdersTab(state);
    }

    return switch (_tabIndex) {
      0 => _buildOrdersTab(state),
      1 => _buildProductsTab(state),
      _ => _buildReportsTab(state),
    };
  }

  Widget _buildOrdersTab(TechCafeState state) {
    final currentFilter = state.staffStatusFilter;
    final showErrorBanner =
        state.staffError != null && state.staffOrders.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilters.contains(currentFilter)
                      ? currentFilter
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Фильтр статуса',
                    border: OutlineInputBorder(),
                  ),
                  items: _statusFilters
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(_statusFilterLabel(value)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    unawaited(state.loadStaffOrders(status: value));
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: state.isStaffOrdersLoading
                    ? null
                    : () => _refreshOrders(state),
                icon: const Icon(Icons.refresh),
              ),
              if (state.isAdmin)
                IconButton(
                  onPressed:
                      state.isStaffOrdersLoading ||
                          state.isClearingCompletedStaffOrders
                      ? null
                      : () => _confirmClearCompletedOrders(state),
                  tooltip: 'Сбросить завершенные',
                  icon: state.isClearingCompletedStaffOrders
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
        ),
        if (state.isStaffOrdersLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (showErrorBanner)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ErrorStateCard(
              title: 'Не удалось загрузить заказы',
              message: state.staffError!,
              onRetry: () => _refreshOrders(state),
            ),
          ),
        Expanded(
          child: state.isStaffOrdersLoading && state.staffOrders.isEmpty
              ? const StaffOrdersSkeleton()
              : state.staffOrders.isEmpty
              ? state.staffError != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: ErrorStateCard(
                          title: 'Не удалось загрузить заказы',
                          message: state.staffError!,
                          onRetry: () => _refreshOrders(state),
                        ),
                      )
                    : EmptyStatePanel(
                        icon: Icons.receipt_long_outlined,
                        title: 'Заказов пока нет',
                        description:
                            'Новые заказы появятся здесь сразу после оформления клиентами.',
                        actionLabel: 'Обновить',
                        onAction: () => _refreshOrders(state),
                      )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollUpdateNotification &&
                        notification.metrics.extentAfter < 200 &&
                        !state.isLoadingMoreStaffOrders &&
                        state.hasMoreStaffOrders) {
                      state.loadMoreStaffOrders();
                    }
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount:
                        state.staffOrders.length +
                        (state.isLoadingMoreStaffOrders ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.staffOrders.length) {
                        return const LoadingListTail();
                      }
                      final order = state.staffOrders[index];
                      return _StaffOrderCard(
                        order: order,
                        onStatusChanged: (next) {
                          unawaited(_changeOrderStatus(state, order, next));
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildProductsTab(TechCafeState state) {
    final showErrorBanner =
        state.staffError != null && state.adminProducts.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => _openProductEditor(state),
                icon: const Icon(Icons.add),
                label: const Text('Добавить товар'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.isAdminProductsLoading
                    ? null
                    : () => _refreshProducts(state),
                icon: const Icon(Icons.refresh),
                label: const Text('Обновить'),
              ),
            ],
          ),
        ),
        if (state.isAdminProductsLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (showErrorBanner)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ErrorStateCard(
              title: 'Не удалось загрузить товары',
              message: state.staffError!,
              onRetry: () => _refreshProducts(state),
            ),
          ),
        Expanded(
          child: state.isAdminProductsLoading && state.adminProducts.isEmpty
              ? const AdminProductsSkeleton()
              : state.adminProducts.isEmpty
              ? state.staffError != null
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: ErrorStateCard(
                          title: 'Не удалось загрузить товары',
                          message: state.staffError!,
                          onRetry: () => _refreshProducts(state),
                        ),
                      )
                    : EmptyStatePanel(
                        icon: Icons.inventory_2_outlined,
                        title: 'Список товаров пуст',
                        description:
                            'Добавьте первую позицию или обновите данные, если товары уже есть на сервере.',
                        actionLabel: 'Добавить товар',
                        onAction: () => _openProductEditor(state),
                      )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: state.adminProducts.length,
                  itemBuilder: (context, index) {
                    final product = state.adminProducts[index];
                    return _AdminProductCard(
                      product: product,
                      onAvailabilityChanged: (value) {
                        unawaited(_setAvailability(state, product, value));
                      },
                      onEdit: () => _openProductEditor(state, product: product),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReportsTab(TechCafeState state) {
    final report = state.salesReport;
    final showErrorBanner = state.staffError != null && report != null;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            FilledButton(
              onPressed: () => _loadTodayReport(state),
              child: const Text('Сегодня'),
            ),
            OutlinedButton(
              onPressed: () => _loadLast7DaysReport(state),
              child: const Text('Последние 7 дней'),
            ),
            OutlinedButton(
              onPressed: () => _loadAllTimeReport(state),
              child: const Text('Все'),
            ),
            OutlinedButton(
              onPressed: () => _pickCustomRange(state),
              child: const Text('Период'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.isSalesReportLoading)
          const LinearProgressIndicator(minHeight: 2),
        if (showErrorBanner) ...[
          const SizedBox(height: AppSpacing.sm),
          ErrorStateCard(
            title: 'Не удалось загрузить отчет',
            message: state.staffError!,
            onRetry: () => _loadTodayReport(state),
          ),
        ],
        if (state.isSalesReportLoading && report == null) ...[
          const SizedBox(height: AppSpacing.md),
          const SizedBox(height: 420, child: ReportsSkeleton()),
        ] else if (report == null) ...[
          const SizedBox(height: AppSpacing.md),
          if (state.staffError != null)
            ErrorStateCard(
              title: 'Не удалось загрузить отчет',
              message: state.staffError!,
              onRetry: () => _loadTodayReport(state),
            )
          else
            EmptyStatePanel(
              icon: Icons.insights_outlined,
              title: 'Отчет еще не загружен',
              description:
                  'Выберите период, чтобы посмотреть выручку, статусы и количество заказов.',
              actionLabel: 'Загрузить за сегодня',
              onAction: () => _loadTodayReport(state),
            ),
        ] else ...[
          _MetricCard(
            title: 'Количество заказов',
            value: '${report.ordersCount}',
          ),
          _MetricCard(
            title: 'Не отменено',
            value: '${report.nonCanceledOrdersCount}',
          ),
          _MetricCard(title: 'Продано позиций', value: '${report.itemsSold}'),
          _MetricCard(title: 'Выручка', value: formatRub(report.totalRevenue)),
          _MetricCard(
            title: 'Период',
            value:
                '${report.from?.toLocal().toString() ?? 'весь период'} -> ${report.to?.toLocal().toString() ?? 'весь период'}',
          ),
          StaffReportCharts(report: report),
        ],
      ],
    );
  }

  Future<void> _login(TechCafeState state) async {
    if (!_loginFormKey.currentState!.validate()) return;

    try {
      await state.loginStaff(
        email: _emailController.text,
        password: _passwordController.text,
      );
      _passwordController.clear();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Вход выполнен: ${_roleLabel(state.staffSession?.role ?? '')}',
          ),
        ),
      );
    } on ApiException {
      return;
    }
  }

  void _refreshCurrentTab(TechCafeState state) {
    if (!state.isStaffLoggedIn) {
      return;
    }

    if (!state.isAdmin) {
      _refreshOrders(state);
      return;
    }

    switch (_tabIndex) {
      case 0:
        _refreshOrders(state);
        break;
      case 1:
        _refreshProducts(state);
        break;
      default:
        _loadAllTimeReport(state);
        break;
    }
  }

  void _refreshOrders(TechCafeState state) {
    unawaited(
      state.loadStaffOrders(
        status: state.staffStatusFilter.isEmpty ? '' : state.staffStatusFilter,
      ),
    );
  }

  void _refreshProducts(TechCafeState state) {
    unawaited(state.loadAdminProducts());
  }

  Future<void> _confirmClearCompletedOrders(TechCafeState state) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить завершенные заказы?'),
        content: const Text(
          'Из панели исчезнут заказы со статусами "Выдан" и "Отменен". '
          'Они останутся в базе для отчетов.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (result != true) {
      return;
    }

    try {
      final clearedCount = await state.clearCompletedStaffOrders();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            clearedCount > 0
                ? 'Завершенные заказы сброшены: $clearedCount'
                : 'Завершенных заказов для сброса нет',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _changeOrderStatus(
    TechCafeState state,
    CafeOrder order,
    OrderStatus nextStatus,
  ) async {
    try {
      await state.changeOrderStatus(order, nextStatus);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Статус заказа ${order.orderNumber} обновлен')),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _setAvailability(
    TechCafeState state,
    Product product,
    bool value,
  ) async {
    try {
      await state.setAdminProductAvailability(
        product: product,
        isAvailable: value,
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openProductEditor(
    TechCafeState state, {
    Product? product,
  }) async {
    if (state.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Категории еще не загружены.')),
      );
      return;
    }

    final result = await showDialog<_ProductEditorResult>(
      context: context,
      builder: (context) =>
          _ProductEditorDialog(categories: state.categories, product: product),
    );

    if (result == null) {
      return;
    }

    try {
      await state.saveAdminProduct(
        productId: product?.id,
        categoryId: result.categoryId,
        name: result.name,
        price: result.price,
        description: result.description,
        imageUrl: result.imageUrl,
        isAvailable: result.isAvailable,
        modifierGroups: result.modifierGroups,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(product == null ? 'Товар создан' : 'Товар обновлен'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _loadTodayReport(TechCafeState state) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 1));

    try {
      await state.loadSalesReport(from: from, to: to);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _loadLast7DaysReport(TechCafeState state) async {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7));

    try {
      await state.loadSalesReport(from: from, to: now);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _loadAllTimeReport(TechCafeState state) async {
    try {
      await state.loadSalesReport();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickCustomRange(TechCafeState state) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
    );

    if (picked == null) {
      return;
    }

    try {
      await state.loadSalesReport(from: picked.start, to: picked.end);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'cashier':
        return 'Кассир';
      case 'barista':
        return 'Бариста';
      case 'admin':
        return 'Админ';
      default:
        return role;
    }
  }

  String _statusFilterLabel(String value) {
    if (value.isEmpty) {
      return 'Все статусы';
    }
    return OrderStatusX.fromString(value).label;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _StaffOrderCard extends StatelessWidget {
  const _StaffOrderCard({required this.order, required this.onStatusChanged});

  final CafeOrder order;
  final ValueChanged<OrderStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableStatuses = OrderStatus.values
        .where((status) => status != OrderStatus.unknown)
        .toList(growable: false);
    final selectedStatus = order.status == OrderStatus.unknown
        ? OrderStatus.created
        : order.status;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Заказ ${order.orderNumber}',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      if (order.customerFullName.isNotEmpty)
                        Text(
                          'Клиент: ${order.customerFullName}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      Text(
                        'Создан: ${order.createdAt.toLocal()}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatRub(order.total),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    OrderStatusBadge(status: order.status),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: order.items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: _OrderItemSummary(item: item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<OrderStatus>(
              key: ValueKey('order-status-${order.id}-${selectedStatus.value}'),
              initialValue: selectedStatus,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Сменить статус',
                border: OutlineInputBorder(),
              ),
              selectedItemBuilder: (context) => availableStatuses
                  .map(
                    (status) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        status.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              items: availableStatuses
                  .map(
                    (status) => DropdownMenuItem<OrderStatus>(
                      value: status,
                      child: Row(
                        children: [
                          OrderStatusBadge(status: status),
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              status.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next == null || next == order.status) {
                  return;
                }
                onStatusChanged(next);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemSummary extends StatelessWidget {
  const _OrderItemSummary({required this.item});

  final OrderItemSnapshot item;

  @override
  Widget build(BuildContext context) {
    final modifierText = item.modifiers
        .map((modifier) => modifier.nameSnapshot)
        .join(', ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6, right: AppSpacing.xs),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.nameSnapshot} x${item.qty}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (modifierText.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  modifierText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(formatRub(item.lineTotal)),
      ],
    );
  }
}

class _AdminProductCard extends StatelessWidget {
  const _AdminProductCard({
    required this.product,
    required this.onAvailabilityChanged,
    required this.onEdit,
  });

  final Product product;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AdminProductThumbnail(
              imageUrl: product.imageUrl,
              productName: product.name,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    formatRub(product.price),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    product.description.isEmpty
                        ? 'Описание не задано'
                        : product.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color:
                          (product.isAvailable
                                  ? AppColors.success
                                  : theme.colorScheme.error)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      child: Text(
                        product.isAvailable ? 'В наличии' : 'Недоступен',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: product.isAvailable
                              ? AppColors.success
                              : theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Column(
              children: [
                Switch(
                  value: product.isAvailable,
                  onChanged: onAvailabilityChanged,
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProductThumbnail extends StatelessWidget {
  const _AdminProductThumbnail({
    required this.imageUrl,
    required this.productName,
  });

  final String imageUrl;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticLabel = imageUrl.trim().isEmpty
        ? 'Изображение товара $productName отсутствует.'
        : 'Изображение товара $productName.';

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 84,
            height: 84,
            child: imageUrl.trim().isEmpty
                ? _ThumbnailFallback(productName: productName)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: const Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, imageUrl, error) =>
                        _ThumbnailFallback(productName: productName),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback({required this.productName});

  final String productName;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.24),
          ],
        ),
      ),
      child: Center(
        child: Text(
          productName.isEmpty
              ? '?'
              : productName.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ProductEditorResult {
  const _ProductEditorResult({
    required this.categoryId,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.isAvailable,
    required this.modifierGroups,
  });

  final String categoryId;
  final String name;
  final double price;
  final String description;
  final String imageUrl;
  final bool isAvailable;
  final List<JsonMap> modifierGroups;
}

class _ProductEditorDialog extends StatefulWidget {
  const _ProductEditorDialog({required this.categories, this.product});

  final List<Category> categories;
  final Product? product;

  @override
  State<_ProductEditorDialog> createState() => _ProductEditorDialogState();
}

class _ProductEditorDialogState extends State<_ProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  final List<_ModifierGroupDraft> _modifierGroups = [];

  late String _categoryId;
  late bool _isAvailable;
  String? _error;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: (widget.product?.price ?? 0).toStringAsFixed(0),
    );
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.product?.imageUrl ?? '',
    );
    _modifierGroups.addAll(
      (widget.product?.modifierGroups ?? const []).map(
        _ModifierGroupDraft.fromModifierGroup,
      ),
    );

    _categoryId = widget.product?.categoryId ?? widget.categories.first.id;
    _isAvailable = widget.product?.isAvailable ?? true;
  }

  @override
  void dispose() {
    for (final group in _modifierGroups) {
      group.dispose();
    }
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.product == null ? 'Создать товар' : 'Редактировать товар',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: RequiredFieldsHint(),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Категория *',
                    border: OutlineInputBorder(),
                  ),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _categoryId = value;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                BlurValidatedTextFormField(
                  controller: _nameController,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Название *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Название обязательно';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                BlurValidatedTextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Цена *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Укажите цену';
                    }
                    final parsed = double.tryParse(value.replaceAll(',', '.'));
                    if (parsed == null || parsed <= 0) {
                      return 'Цена должна быть больше 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Ссылка на изображение',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Опции товара',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (_modifierGroups.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Опции не добавлены'),
                  ),
                ...List.generate(
                  _modifierGroups.length,
                  (index) => _buildModifierGroupEditor(index),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addModifierGroup,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить группу опций'),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SwitchListTile(
                  value: _isAvailable,
                  onChanged: (value) {
                    setState(() {
                      _isAvailable = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  title: const Text('В наличии'),
                ),
                if (_error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }

  Widget _buildModifierGroupEditor(int groupIndex) {
    final group = _modifierGroups[groupIndex];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Группа ${groupIndex + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Удалить группу',
                  onPressed: () => _removeModifierGroup(groupIndex),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            BlurValidatedTextFormField(
              key: ValueKey('group-$groupIndex-name'),
              controller: group.nameController,
              decoration: const InputDecoration(
                labelText: 'Название группы *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Укажите название группы';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: BlurValidatedTextFormField(
                    key: ValueKey('group-$groupIndex-min'),
                    controller: group.minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Мин *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Обязательно';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed < 0) {
                        return '>= 0';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: BlurValidatedTextFormField(
                    key: ValueKey('group-$groupIndex-max'),
                    controller: group.maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Макс *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Обязательно';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return '> 0';
                      }
                      final min =
                          int.tryParse(group.minController.text.trim()) ?? 0;
                      if (parsed < min) {
                        return '>= мин';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ...List.generate(
              group.items.length,
              (itemIndex) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: _buildModifierItemEditor(groupIndex, itemIndex),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addModifierItem(groupIndex),
                icon: const Icon(Icons.add),
                label: const Text('Добавить опцию'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierItemEditor(int groupIndex, int itemIndex) {
    final item = _modifierGroups[groupIndex].items[itemIndex];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: BlurValidatedTextFormField(
            key: ValueKey('group-$groupIndex-item-$itemIndex-name'),
            controller: item.nameController,
            decoration: const InputDecoration(
              labelText: 'Опция *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Название обязательно';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: BlurValidatedTextFormField(
            key: ValueKey('group-$groupIndex-item-$itemIndex-price'),
            controller: item.priceDeltaController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Цена +/- *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Обязательно';
              }
              if (double.tryParse(value.replaceAll(',', '.')) == null) {
                return 'Некорректное число';
              }
              return null;
            },
          ),
        ),
        IconButton(
          tooltip: 'Удалить опцию',
          onPressed: () => _removeModifierItem(groupIndex, itemIndex),
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }

  void _addModifierGroup() {
    setState(() {
      _error = null;
      _modifierGroups.add(_ModifierGroupDraft.empty());
    });
  }

  void _removeModifierGroup(int groupIndex) {
    setState(() {
      _error = null;
      final removed = _modifierGroups.removeAt(groupIndex);
      removed.dispose();
    });
  }

  void _addModifierItem(int groupIndex) {
    setState(() {
      _error = null;
      _modifierGroups[groupIndex].items.add(_ModifierItemDraft.empty());
    });
  }

  void _removeModifierItem(int groupIndex, int itemIndex) {
    setState(() {
      _error = null;
      final removed = _modifierGroups[groupIndex].items.removeAt(itemIndex);
      removed.dispose();
    });
  }

  List<JsonMap>? _buildModifierGroupsPayload() {
    final result = <JsonMap>[];

    for (
      var groupIndex = 0;
      groupIndex < _modifierGroups.length;
      groupIndex++
    ) {
      final group = _modifierGroups[groupIndex];
      final groupName = group.nameController.text.trim();
      final min = int.tryParse(group.minController.text.trim()) ?? 0;
      final max = int.tryParse(group.maxController.text.trim()) ?? 1;

      if (group.items.isEmpty) {
        _error = 'Добавьте хотя бы одну опцию в группе #${groupIndex + 1}.';
        return null;
      }

      final items = <JsonMap>[];
      for (var itemIndex = 0; itemIndex < group.items.length; itemIndex++) {
        final item = group.items[itemIndex];
        final itemName = item.nameController.text.trim();
        final priceDelta =
            double.tryParse(
              item.priceDeltaController.text.replaceAll(',', '.'),
            ) ??
            0;

        final itemJson = <String, dynamic>{
          'name': itemName,
          'priceDelta': priceDelta,
        };
        if (item.id != null && item.id!.isNotEmpty) {
          itemJson['id'] = item.id;
        }
        items.add(itemJson);
      }

      final groupJson = <String, dynamic>{
        'name': groupName,
        'min': min,
        'max': max,
        'items': items,
      };
      if (group.id != null && group.id!.isNotEmpty) {
        groupJson['id'] = group.id;
      }
      result.add(groupJson);
    }

    return result;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final modifierGroups = _buildModifierGroupsPayload();
    if (modifierGroups == null) {
      setState(() {});
      return;
    }

    _error = null;

    final parsedPrice = double.tryParse(
      _priceController.text.replaceAll(',', '.'),
    )!;

    Navigator.of(context).pop(
      _ProductEditorResult(
        categoryId: _categoryId,
        name: _nameController.text.trim(),
        price: parsedPrice,
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        isAvailable: _isAvailable,
        modifierGroups: modifierGroups,
      ),
    );
  }
}

class _ModifierGroupDraft {
  _ModifierGroupDraft({
    required this.id,
    required this.nameController,
    required this.minController,
    required this.maxController,
    required this.items,
  });

  factory _ModifierGroupDraft.empty() {
    return _ModifierGroupDraft(
      id: null,
      nameController: TextEditingController(),
      minController: TextEditingController(text: '0'),
      maxController: TextEditingController(text: '1'),
      items: <_ModifierItemDraft>[_ModifierItemDraft.empty()],
    );
  }

  factory _ModifierGroupDraft.fromModifierGroup(ModifierGroup group) {
    return _ModifierGroupDraft(
      id: group.id,
      nameController: TextEditingController(text: group.name),
      minController: TextEditingController(text: '${group.min}'),
      maxController: TextEditingController(text: '${group.max}'),
      items: group.items
          .map(_ModifierItemDraft.fromModifierItem)
          .toList(growable: true),
    );
  }

  final String? id;
  final TextEditingController nameController;
  final TextEditingController minController;
  final TextEditingController maxController;
  final List<_ModifierItemDraft> items;

  void dispose() {
    nameController.dispose();
    minController.dispose();
    maxController.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

class _ModifierItemDraft {
  _ModifierItemDraft({
    required this.id,
    required this.nameController,
    required this.priceDeltaController,
  });

  factory _ModifierItemDraft.empty() {
    return _ModifierItemDraft(
      id: null,
      nameController: TextEditingController(),
      priceDeltaController: TextEditingController(text: '0'),
    );
  }

  factory _ModifierItemDraft.fromModifierItem(ModifierItem item) {
    return _ModifierItemDraft(
      id: item.id,
      nameController: TextEditingController(text: item.name),
      priceDeltaController: TextEditingController(text: '${item.priceDelta}'),
    );
  }

  final String? id;
  final TextEditingController nameController;
  final TextEditingController priceDeltaController;

  void dispose() {
    nameController.dispose();
    priceDeltaController.dispose();
  }
}
