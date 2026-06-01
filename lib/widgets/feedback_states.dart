import 'package:flutter/material.dart';

import '../theme.dart';

class EmptyStatePanel extends StatelessWidget {
  const EmptyStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: '$title. $description',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.45,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.14),
                              theme.colorScheme.secondary.withValues(
                                alpha: 0.2,
                              ),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 38,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        button: true,
                        label: actionLabel!,
                        child: FilledButton.icon(
                          onPressed: onAction,
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(actionLabel!),
                        ),
                      ),
                    ],
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

class ErrorStateCard extends StatelessWidget {
  const ErrorStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Повторить',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Ошибка. $title. $message',
      child: Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.38),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Semantics(
                      button: true,
                      label: retryLabel,
                      child: FilledButton.tonalIcon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(retryLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
