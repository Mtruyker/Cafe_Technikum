import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/techcafe_state.dart';
import '../theme.dart';
import '../widgets/feedback_states.dart';
import '../widgets/guest_navigation_bar.dart';
import '../widgets/loading_placeholders.dart';
import '../widgets/product_card.dart';
import '../widgets/product_options_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TechCafeState>(
      builder: (context, state, _) {
        final showGuestBottomNavigation = useGuestBottomNavigation;

        return Scaffold(
          appBar: AppBar(
            title: const Text('КафеТехникум'),
            actions: [
              if (!showGuestBottomNavigation)
                IconButton(
                  tooltip: 'Панель персонала',
                  onPressed: () => context.push('/staff'),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                ),
              IconButton(
                tooltip: 'Отслеживание заказа',
                onPressed: () => context.push('/tracking'),
                icon: const Icon(Icons.qr_code_scanner_outlined),
              ),
              if (!showGuestBottomNavigation)
                IconButton(
                  tooltip: 'Мои заказы',
                  onPressed: () => context.push('/orders'),
                  icon: const Icon(Icons.history),
                ),
              if (!showGuestBottomNavigation)
                _AnimatedCartActionButton(
                  count: state.cartItemsCount,
                  onPressed: () => context.push('/cart'),
                ),
            ],
          ),
          bottomNavigationBar: showGuestBottomNavigation
              ? GuestNavigationBar(
                  currentItem: GuestNavigationItem.menu,
                  cartItemsCount: state.cartItemsCount,
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_bodyKey(state)),
              child: _buildBody(context, state),
            ),
          ),
        );
      },
    );
  }

  String _bodyKey(TechCafeState state) {
    if (state.isInitializing ||
        (state.isMenuLoading && state.products.isEmpty)) {
      return 'loading';
    }
    if (state.initializationError != null && state.categories.isEmpty) {
      return 'error';
    }
    return 'content';
  }

  Widget _buildBody(BuildContext context, TechCafeState state) {
    if (state.isInitializing ||
        (state.isMenuLoading && state.products.isEmpty)) {
      return const HomeScreenSkeleton();
    }

    if (state.initializationError != null && state.categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ErrorStateCard(
              title: 'Не удалось загрузить меню',
              message: state.initializationError!,
              onRetry: () => state.initialize(),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Поиск по названию',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setSearchQuery,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: state.categories
                            .map((category) {
                              final isSelected =
                                  state.selectedCategoryId == category.id;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.xs,
                                ),
                                child: ChoiceChip(
                                  label: Text(category.name),
                                  selected: isSelected,
                                  onSelected: (_) =>
                                      state.selectCategory(category.id),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('В наличии'),
                      Switch(
                        value: state.inStockOnly,
                        onChanged: state.setInStockOnly,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.isMenuLoading && state.products.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),
        if (state.initializationError != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ErrorStateCard(
              title: 'Не удалось обновить меню',
              message: state.initializationError!,
              onRetry: () => state.refreshMenu(),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: state.refreshMenu,
            child: state.visibleProducts.isEmpty
                ? _buildEmptyCatalogState(state)
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification &&
                          notification.metrics.extentAfter < 200 &&
                          !state.isLoadingMoreProducts &&
                          state.hasMoreProducts) {
                        state.loadMoreProducts();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      itemCount:
                          state.visibleProducts.length +
                          (state.isLoadingMoreProducts ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.visibleProducts.length) {
                          return const LoadingListTail();
                        }
                        final product = state.visibleProducts[index];
                        return ProductCard(
                          product: product,
                          onAdd: product.isAvailable
                              ? () => _onAddPressed(context, state, product)
                              : null,
                        );
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCatalogState(TechCafeState state) {
    final hasFilters = state.hasActiveCatalogFilters;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        EmptyStatePanel(
          icon: hasFilters
              ? Icons.search_off_rounded
              : Icons.local_cafe_outlined,
          title: hasFilters ? 'Ничего не найдено' : 'Меню пока пусто',
          description: hasFilters
              ? 'Попробуйте изменить запрос, выбрать другую категорию или сбросить фильтры.'
              : 'Когда блюда появятся на сервере, они отобразятся здесь. Пока можно повторить загрузку меню.',
          actionLabel: hasFilters ? 'Сбросить фильтры' : 'Обновить меню',
          onAction: hasFilters
              ? () => _resetCatalogFilters(state)
              : () => state.refreshMenu(),
        ),
      ],
    );
  }

  Future<void> _resetCatalogFilters(TechCafeState state) async {
    _searchController.clear();
    await state.resetCatalogFilters();
  }

  Future<void> _onAddPressed(
    BuildContext context,
    TechCafeState state,
    Product product,
  ) async {
    final modifiers = await showModalBottomSheet<List<SelectedModifier>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProductOptionsSheet(product: product),
    );

    if (modifiers == null) {
      return;
    }

    state.addToCart(product, modifiers);

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${product.name} добавлен в корзину'),
      ),
    );
  }
}

class _AnimatedCartActionButton extends StatefulWidget {
  const _AnimatedCartActionButton({
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  State<_AnimatedCartActionButton> createState() =>
      _AnimatedCartActionButtonState();
}

class _AnimatedCartActionButtonState extends State<_AnimatedCartActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final Animation<double> _scaleAnimation = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.16,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.16,
        end: 1,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 60,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedCartActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count > oldWidget.count) {
      _controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartLabel = widget.count == 0
        ? 'Корзина пуста'
        : 'Корзина, ${widget.count} товаров';

    return IconButton(
      tooltip: cartLabel,
      onPressed: widget.onPressed,
      icon: ScaleTransition(
        scale: _scaleAnimation,
        child: Semantics(
          button: true,
          label: cartLabel,
          child: Badge(
            isLabelVisible: widget.count > 0,
            label: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text('${widget.count}', key: ValueKey(widget.count)),
            ),
            child: const Icon(Icons.shopping_cart_outlined),
          ),
        ),
      ),
    );
  }
}
