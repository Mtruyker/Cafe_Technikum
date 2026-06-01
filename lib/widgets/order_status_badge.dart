import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';

Color orderStatusColor(BuildContext context, OrderStatus status) {
  return switch (status) {
    OrderStatus.created => AppColors.info,
    OrderStatus.accepted => const Color(0xFF946200),
    OrderStatus.cooking => const Color(0xFFD97706),
    OrderStatus.ready => AppColors.success,
    OrderStatus.issued => AppColors.adminSeed,
    OrderStatus.canceled => Theme.of(context).colorScheme.error,
    OrderStatus.unknown => AppColors.neutral,
  };
}

OrderStatus orderStatusFromValue(String value) {
  return OrderStatusX.fromString(value);
}

class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final baseColor = orderStatusColor(context, status);

    return Semantics(
      label: 'Статус: ${status.label}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: baseColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: baseColor.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: ExcludeSemantics(
            child: Text(
              status.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: baseColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
