import 'package:flutter/material.dart';

import '../theme.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1.6 + (_controller.value * 2.8), -0.2),
                end: Alignment(-0.4 + (_controller.value * 2.8), 0.2),
                colors: [
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.92,
                  ),
                  theme.colorScheme.surface.withValues(alpha: 0.72),
                  theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.92,
                  ),
                ],
                stops: const [0.1, 0.5, 0.9],
              ).createShader(bounds);
            },
            child: child,
          );
        },
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 16,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(radius)
            : null,
      ),
    );
  }
}

class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Column(
              children: [
                SkeletonBox(height: 56, radius: 18),
                SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          SkeletonBox(width: 90, height: 32, radius: 999),
                          SkeletonBox(width: 76, height: 32, radius: 999),
                          SkeletonBox(width: 104, height: 32, radius: 999),
                        ],
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    SkeletonBox(width: 84, height: 32, radius: 999),
                  ],
                ),
              ],
            ),
          ),
          _ProductCardSkeleton(),
          _ProductCardSkeleton(),
          _ProductCardSkeleton(),
        ],
      ),
    );
  }
}

class StaffOrdersSkeleton extends StatelessWidget {
  const StaffOrdersSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: const [
          _OrderCardSkeleton(),
          _OrderCardSkeleton(),
          _OrderCardSkeleton(),
        ],
      ),
    );
  }
}

class AdminProductsSkeleton extends StatelessWidget {
  const AdminProductsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: const [
          _ProductRowSkeleton(),
          _ProductRowSkeleton(),
          _ProductRowSkeleton(),
          _ProductRowSkeleton(),
        ],
      ),
    );
  }
}

class ReportsSkeleton extends StatelessWidget {
  const ReportsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: const [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              SkeletonBox(width: 92, height: 40, radius: 14),
              SkeletonBox(width: 132, height: 40, radius: 14),
              SkeletonBox(width: 72, height: 40, radius: 14),
              SkeletonBox(width: 88, height: 40, radius: 14),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          _MetricSkeletonCard(),
          _MetricSkeletonCard(),
          _MetricSkeletonCard(),
          _MetricSkeletonCard(),
          _StatusSkeletonCard(),
        ],
      ),
    );
  }
}

class TrackingOrderSkeleton extends StatelessWidget {
  const TrackingOrderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SkeletonBox(width: 180, height: 26, radius: 12),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(width: 120, height: 16, radius: 10),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(width: 160, height: 16, radius: 10),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(width: 108, height: 16, radius: 10),
              SizedBox(height: AppSpacing.sm),
              Divider(),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(height: 16, radius: 10),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(width: 220, height: 14, radius: 10),
              SizedBox(height: AppSpacing.sm),
              SkeletonBox(height: 16, radius: 10),
              SizedBox(height: AppSpacing.xs),
              SkeletonBox(width: 180, height: 14, radius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingListTail extends StatelessWidget {
  const LoadingListTail({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: SkeletonShimmer(child: SkeletonBox(height: 104, radius: 24)),
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xxs,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            child: SkeletonBox(height: 188, radius: 0),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SkeletonBox(height: 22, radius: 10)),
                    SizedBox(width: AppSpacing.xs),
                    SkeletonBox(width: 96, height: 30, radius: 999),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(height: 14, radius: 10),
                SizedBox(height: AppSpacing.xs),
                SkeletonBox(width: 220, height: 14, radius: 10),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    SkeletonBox(width: 92, height: 24, radius: 12),
                    Spacer(),
                    SkeletonBox(width: 128, height: 40, radius: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCardSkeleton extends StatelessWidget {
  const _OrderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 20, radius: 10)),
                SizedBox(width: AppSpacing.sm),
                SkeletonBox(width: 72, height: 20, radius: 10),
              ],
            ),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(width: 180, height: 14, radius: 10),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(height: 14, radius: 10),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 54, radius: 14),
          ],
        ),
      ),
    );
  }
}

class _ProductRowSkeleton extends StatelessWidget {
  const _ProductRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 56, height: 56, radius: 16),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 168, height: 18, radius: 10),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(width: 96, height: 14, radius: 10),
                  SizedBox(height: AppSpacing.xs),
                  SkeletonBox(height: 14, radius: 10),
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            SkeletonBox(width: 72, height: 36, radius: 999),
          ],
        ),
      ),
    );
  }
}

class _MetricSkeletonCard extends StatelessWidget {
  const _MetricSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 144, height: 14, radius: 10),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(width: 84, height: 22, radius: 10),
          ],
        ),
      ),
    );
  }
}

class _StatusSkeletonCard extends StatelessWidget {
  const _StatusSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 120, height: 18, radius: 10),
            SizedBox(height: AppSpacing.sm),
            SkeletonBox(height: 14, radius: 10),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(width: 168, height: 14, radius: 10),
            SizedBox(height: AppSpacing.xs),
            SkeletonBox(width: 132, height: 14, radius: 10),
          ],
        ),
      ),
    );
  }
}
