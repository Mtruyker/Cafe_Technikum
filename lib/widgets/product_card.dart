import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'product_card_image.dart';

class ProductCard extends StatefulWidget {
  const ProductCard({super.key, required this.product, required this.onAdd});

  final Product product;
  final VoidCallback? onAdd;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final style = ProductCardStyle.fromCategoryId(widget.product.categoryId);
    final surfaceColor = Color.alphaBlend(
      style.primary.withValues(alpha: 0.07),
      theme.colorScheme.surface,
    );
    final borderColor = style.primary.withValues(
      alpha: _isHovered ? 0.24 : 0.12,
    );
    final shadowColor = style.primary.withValues(
      alpha: _isHovered ? 0.18 : 0.08,
    );
    final verticalOffset = _isPressed ? 1.0 : (_isHovered ? -4.0 : 0.0);
    final useStackedActions = textScale > 1.15;

    return MouseRegion(
      cursor: widget.onAdd == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) {
        setState(() {
          _isHovered = false;
          _isPressed = false;
        });
      },
      child: Listener(
        onPointerDown: widget.onAdd == null
            ? null
            : (_) => setState(() => _isPressed = true),
        onPointerUp: widget.onAdd == null
            ? null
            : (_) => setState(() => _isPressed = false),
        onPointerCancel: (_) => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xxs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            transform: Matrix4.translationValues(0, verticalOffset, 0),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: _isHovered ? 28 : 16,
                  offset: Offset(0, _isHovered ? 18 : 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 188,
                      width: double.infinity,
                      child: ProductCardImage(
                        imageUrl: widget.product.imageUrl,
                        style: style,
                        productName: widget.product.name,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              _AvailabilityBadge(
                                isAvailable: widget.product.isAvailable,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.product.description.isEmpty
                                ? 'Описание скоро появится'
                                : widget.product.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (useStackedActions)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatRub(widget.product.price),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: style.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: _AddToCartButton(
                                    product: widget.product,
                                    onPressed: widget.onAdd,
                                    styleColor: style.primary,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Text(
                                  formatRub(widget.product.price),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: style.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                _AddToCartButton(
                                  product: widget.product,
                                  onPressed: widget.onAdd,
                                  styleColor: style.primary,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.isAvailable});

  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final color = isAvailable ? AppColors.success : AppColors.warning;
    final icon = isAvailable
        ? Icons.check_circle_outline
        : Icons.schedule_outlined;
    final label = isAvailable ? 'В наличии' : 'Нет в наличии';

    return Semantics(
      label: 'Статус товара: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({
    required this.product,
    required this.onPressed,
    required this.styleColor,
  });

  final Product product;
  final VoidCallback? onPressed;
  final Color styleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonLabel = product.isAvailable ? 'В корзину' : 'Недоступно';
    final semanticLabel = product.isAvailable
        ? 'Добавить ${product.name} в корзину за ${formatRub(product.price)}'
        : 'Товар ${product.name} недоступен для заказа';

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: styleColor,
            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
            disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: Icon(
            product.isAvailable
                ? Icons.add_shopping_cart_outlined
                : Icons.remove_shopping_cart_outlined,
          ),
          label: Text(buttonLabel),
        ),
      ),
    );
  }
}
