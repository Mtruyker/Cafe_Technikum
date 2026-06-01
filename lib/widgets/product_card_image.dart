import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

@immutable
class ProductCardStyle {
  const ProductCardStyle({
    required this.primary,
    required this.secondary,
    required this.highlight,
    required this.icon,
    required this.label,
  });

  final Color primary;
  final Color secondary;
  final Color highlight;
  final IconData icon;
  final String label;

  static ProductCardStyle fromCategoryId(String categoryId) {
    final normalized = categoryId.toLowerCase();

    if (normalized.contains('coffee')) {
      return const ProductCardStyle(
        primary: Color(0xFF8C4B2F),
        secondary: Color(0xFFD8894C),
        highlight: Color(0xFFFFE1A8),
        icon: Icons.local_cafe_outlined,
        label: 'Кофе',
      );
    }

    if (normalized.contains('donut')) {
      return const ProductCardStyle(
        primary: Color(0xFFCF4A72),
        secondary: Color(0xFFFFA36C),
        highlight: Color(0xFFFFE4B5),
        icon: Icons.donut_large_outlined,
        label: 'Пончики',
      );
    }

    if (normalized.contains('pancake')) {
      return const ProductCardStyle(
        primary: Color(0xFFE49A2F),
        secondary: Color(0xFFF7C768),
        highlight: Color(0xFFFFF2C8),
        icon: Icons.breakfast_dining_outlined,
        label: 'Завтраки',
      );
    }

    return const ProductCardStyle(
      primary: Color(0xFF3F7C85),
      secondary: Color(0xFF8FD3C1),
      highlight: Color(0xFFE5FFF8),
      icon: Icons.fastfood_outlined,
      label: 'Меню',
    );
  }
}

class ProductCardImage extends StatelessWidget {
  const ProductCardImage({
    super.key,
    required this.imageUrl,
    required this.style,
    required this.productName,
  });

  final String imageUrl;
  final ProductCardStyle style;
  final String productName;

  @override
  Widget build(BuildContext context) {
    final content = imageUrl.isEmpty
        ? _ProductImageFallback(
            style: style,
            message: 'Фото блюда скоро появится',
          )
        : CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (context, url) =>
                _ProductImagePlaceholder(style: style),
            imageBuilder: (context, imageProvider) =>
                _BlurRevealImage(imageProvider: imageProvider, style: style),
            errorWidget: (context, url, error) => _ProductImageFallback(
              style: style,
              message: 'Не удалось загрузить фото',
            ),
          );

    final semanticLabel = imageUrl.isEmpty
        ? 'Изображение товара $productName отсутствует. Фото скоро появится.'
        : 'Изображение товара $productName. Категория ${style.label}.';

    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.sm,
              top: AppSpacing.sm,
              child: _CategoryBadge(style: style),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.style});

  final ProductCardStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.26)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 14, color: Colors.white),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              style.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatefulWidget {
  const _ProductImagePlaceholder({required this.style});

  final ProductCardStyle style;

  @override
  State<_ProductImagePlaceholder> createState() =>
      _ProductImagePlaceholderState();
}

class _ProductImagePlaceholderState extends State<_ProductImagePlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [widget.style.primary, widget.style.secondary],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment(-1.4 + (_controller.value * 2.8), -0.3),
                      end: Alignment(-0.2 + (_controller.value * 2.8), 0.3),
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.34),
                        Colors.white.withValues(alpha: 0.10),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.35, 0.5, 0.65, 1],
                    ).createShader(bounds);
                  },
                  child: Container(color: Colors.white.withValues(alpha: 0.16)),
                ),
              ),
              _FallbackContent(style: widget.style, message: 'Загружаем фото'),
            ],
          ),
        );
      },
    );
  }
}

class _BlurRevealImage extends StatefulWidget {
  const _BlurRevealImage({required this.imageProvider, required this.style});

  final ImageProvider imageProvider;
  final ProductCardStyle style;

  @override
  State<_BlurRevealImage> createState() => _BlurRevealImageState();
}

class _BlurRevealImageState extends State<_BlurRevealImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..forward();
  late final Animation<double> _blurAnimation = Tween<double>(
    begin: 12,
    end: 0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  late final Animation<double> _opacityAnimation = Tween<double>(
    begin: 0.78,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Image(image: widget.imageProvider, fit: BoxFit.cover),
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.style.primary.withValues(alpha: 0.18),
                widget.style.secondary.withValues(alpha: 0.06),
              ],
            ),
          ),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: _blurAnimation.value,
              sigmaY: _blurAnimation.value,
            ),
            child: Opacity(opacity: _opacityAnimation.value, child: child),
          ),
        );
      },
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({required this.style, required this.message});

  final ProductCardStyle style;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [style.primary, style.secondary],
        ),
      ),
      child: _FallbackContent(style: style, message: message),
    );
  }
}

class _FallbackContent extends StatelessWidget {
  const _FallbackContent({required this.style, required this.message});

  final ProductCardStyle style;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Icon(style.icon, size: 28, color: style.highlight),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
