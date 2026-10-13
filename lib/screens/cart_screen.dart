import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/feedback_states.dart';
import '../widgets/pickup_slot_picker.dart';
import '../widgets/guest_navigation_bar.dart';
import '../widgets/validated_form_fields.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;
  String? _pickupSlotId;
  int _slotRevision = 0;
  PaymentMethod _paymentMethod = PaymentMethod.payOnPickup;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TechCafeState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Корзина')),
          bottomNavigationBar: useGuestBottomNavigation(context)
              ? GuestNavigationBar(
                  currentItem: GuestNavigationItem.cart,
                  cartItemsCount: state.cartItemsCount,
                )
              : null,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: state.cartItems.isEmpty
                ? const _EmptyCartView(key: ValueKey('empty-cart'))
                : ListView(
                    key: const ValueKey('filled-cart'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm,
                      AppSpacing.sm + MediaQuery.of(context).padding.bottom,
                    ),
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: state.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = state.cartItems[index];
                          return _AnimatedCartItemTile(
                            key: ValueKey(item.signature),
                            item: item,
                            onDecrement: () =>
                                state.setCartItemQty(item, item.qty - 1),
                            onIncrement: () =>
                                state.setCartItemQty(item, item.qty + 1),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const RequiredFieldsHint(),
                              const SizedBox(height: AppSpacing.sm),
                              BlurValidatedTextFormField(
                                controller: _firstNameController,
                                maxLength: 60,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Имя *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Укажите имя';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              BlurValidatedTextFormField(
                                controller: _lastNameController,
                                maxLength: 60,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Фамилия *',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Укажите фамилию';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextFormField(
                                controller: _commentController,
                                minLines: 2,
                                maxLines: 3,
                                maxLength: 500,
                                decoration: const InputDecoration(
                                  labelText: 'Комментарий к заказу',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              PickupSlotPicker(
                                key: ValueKey(_slotRevision),
                                portions: state.cartItemsCount,
                                onChanged: (id) => _pickupSlotId = id,
                              ),
                              const Text('Получение: самовывоз'),
                              const Text(
                                'Оплата: наличные/перевод/карта у кассы',
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              DropdownButtonFormField<PaymentMethod>(
                                initialValue: _paymentMethod,
                                decoration: const InputDecoration(
                                  labelText: 'Способ оплаты',
                                  border: OutlineInputBorder(),
                                ),
                                items: PaymentMethod.values
                                    .where(
                                      (method) =>
                                          method != PaymentMethod.unknown,
                                    )
                                    .map(
                                      (method) =>
                                          DropdownMenuItem<PaymentMethod>(
                                            value: method,
                                            child: Text(method.label),
                                          ),
                                    )
                                    .toList(growable: false),
                                onChanged: (next) {
                                  if (next == null) {
                                    return;
                                  }
                                  setState(() {
                                    _paymentMethod = next;
                                  });
                                },
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                _paymentMethod == PaymentMethod.onlineCard
                                    ? 'После оформления откроется тестовая онлайн-оплата.'
                                    : 'Оплата при получении: наличные/перевод/карта у кассы.',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Итого'),
                                        _AnimatedValueText(
                                          value: formatRub(state.cartTotal),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: _isSubmitting
                                        ? null
                                        : () => _submitOrder(context, state),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox.square(
                                              key: ValueKey('submitting'),
                                              dimension: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Оформить',
                                              key: ValueKey('submit-label'),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Future<void> _submitOrder(BuildContext context, TechCafeState state) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await state.placeOrder(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        comment: _commentController.text,
        paymentMethod: _paymentMethod,
        pickupSlotId: _pickupSlotId,
      );
      if (!context.mounted) {
        return;
      }

      context.pushReplacement('/order-success', extra: result);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _slotRevision++;
          _pickupSlotId = null;
        });
      }
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

class _EmptyCartView extends StatelessWidget {
  const _EmptyCartView({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStatePanel(
      icon: Icons.shopping_cart_checkout_outlined,
      title: 'Корзина пуста',
      description: 'Добавьте несколько позиций из меню, и они появятся здесь.',
      actionLabel: 'Перейти в меню',
      onAction: () => context.go('/'),
    );
  }
}

class _AnimatedCartItemTile extends StatefulWidget {
  const _AnimatedCartItemTile({
    super.key,
    required this.item,
    required this.onDecrement,
    required this.onIncrement,
  });

  final CartItem item;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  State<_AnimatedCartItemTile> createState() => _AnimatedCartItemTileState();
}

class _AnimatedCartItemTileState extends State<_AnimatedCartItemTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _highlightAnimation = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInCubic)),
      weight: 55,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _AnimatedCartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.qty != oldWidget.item.qty) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final useVerticalControls = textScale > 1.2;

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        final backgroundColor = Color.alphaBlend(
          theme.colorScheme.primary.withValues(
            alpha: 0.08 * _highlightAnimation.value,
          ),
          theme.colorScheme.surface,
        );

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: child,
        );
      },
      child: MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: useVerticalControls
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CartItemDetails(item: widget.item),
                    const SizedBox(height: AppSpacing.sm),
                    _CartQtyControls(
                      itemName: widget.item.product.name,
                      qty: widget.item.qty,
                      onDecrement: widget.onDecrement,
                      onIncrement: widget.onIncrement,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _CartItemDetails(item: widget.item)),
                    const SizedBox(width: AppSpacing.md),
                    _CartQtyControls(
                      itemName: widget.item.product.name,
                      qty: widget.item.qty,
                      onDecrement: widget.onDecrement,
                      onIncrement: widget.onIncrement,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CartItemDetails extends StatelessWidget {
  const _CartItemDetails({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.product.name, style: theme.textTheme.titleMedium),
        if (item.modifiers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.modifiers.map((entry) => entry.name).join(', '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Цена за единицу: ${formatRub(item.unitPrice)}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        _AnimatedValueText(
          value: 'Итого: ${formatRub(item.lineTotal)}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _CartQtyControls extends StatelessWidget {
  const _CartQtyControls({
    required this.itemName,
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String itemName;
  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Уменьшить количество: $itemName',
            visualDensity: VisualDensity.compact,
          ),
          Semantics(
            label: 'Количество товара $itemName',
            value: '$qty',
            child: _AnimatedValueText(
              value: '$qty',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Увеличить количество: $itemName',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _AnimatedValueText extends StatelessWidget {
  const _AnimatedValueText({required this.value, this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnimation = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offsetAnimation, child: child),
        );
      },
      child: Text(value, key: ValueKey(value), style: style),
    );
  }
}
