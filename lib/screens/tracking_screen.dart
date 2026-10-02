import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../widgets/pickup_slot_picker.dart';
import '../widgets/order_push_button.dart';
import '../services/api_exception.dart';
import '../state/techcafe_state.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/feedback_states.dart';
import '../widgets/loading_placeholders.dart';
import '../widgets/validated_form_fields.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, this.initialValue});

  final String? initialValue;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _controller.addListener(_handleInputChanged);

    if ((widget.initialValue ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _track();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TechCafeState>(
      builder: (context, state, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Отслеживание заказа')),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BlurValidatedTextFormField(
                      controller: _controller,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _track(),
                      decoration: const InputDecoration(
                        labelText: 'Номер заказа или ID из QR *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите номер заказа или ID.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    const RequiredFieldsHint(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                onPressed: state.isTracking ? null : _track,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: state.isTracking
                      ? const SizedBox.square(
                          key: ValueKey('tracking-loading'),
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Проверить статус',
                          key: ValueKey('tracking-label'),
                        ),
                ),
              ),
              if (state.trackingError != null &&
                  _controller.text.trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                ErrorStateCard(
                  title: 'Не удалось получить заказ',
                  message: state.trackingError!,
                  onRetry: _track,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: state.isTracking && state.trackedOrder == null
                    ? const TrackingOrderSkeleton(
                        key: ValueKey('tracking-skeleton'),
                      )
                    : state.trackedOrder != null
                    ? _OrderDetailsCard(
                        key: ValueKey(state.trackedOrder!.id),
                        order: state.trackedOrder!,
                      )
                    : state.trackingError != null
                    ? const SizedBox.shrink(
                        key: ValueKey('tracking-error-space'),
                      )
                    : EmptyStatePanel(
                        key: const ValueKey('tracking-empty'),
                        icon: Icons.local_shipping_outlined,
                        title: 'Введите номер заказа',
                        description:
                            'Укажите номер заказа или ID из QR, чтобы увидеть текущий статус и состав заказа.',
                        actionLabel: 'Открыть мои заказы',
                        onAction: () => context.push('/orders'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _track() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final state = context.read<TechCafeState>();

    try {
      await state.trackOrder(_controller.text);
    } on ApiException {
      return;
    }
  }
}

class _OrderDetailsCard extends StatelessWidget {
  const _OrderDetailsCard({super.key, required this.order});

  final CafeOrder order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Заказ ${order.orderNumber}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xxs),
            if (order.customerFullName.isNotEmpty)
              Text('Клиент: ${order.customerFullName}'),
            Text('Статус: ${order.status.label}'),
            Text('Создан: ${order.createdAt.toLocal()}'),
            if (order.pickupAt != null)
              Text('К получению: ${pickupTimeLabel(order.pickupAt!)} (UTC+4)'),
            _SavedPickupCode(order: order),
            Text('Сумма: ${formatRub(order.total)}'),
            if ((order.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Комментарий: ${order.comment}'),
            ],
            const Divider(height: 20),
            ...order.items.map((item) {
              final modifierText = item.modifiers
                  .map((modifier) => modifier.nameSnapshot)
                  .join(', ');

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.nameSnapshot} x${item.qty}'),
                    if (modifierText.isNotEmpty)
                      Text(
                        modifierText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text('Итого: ${formatRub(item.lineTotal)}'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SavedPickupCode extends StatelessWidget {
  const _SavedPickupCode({required this.order});
  final CafeOrder order;
  @override
  Widget build(BuildContext context) {
    final saved = context
        .watch<TechCafeState>()
        .recentOrders
        .where((r) => r.orderId == order.id)
        .firstOrNull;
    if (saved == null ||
        saved.pickupCode.isEmpty ||
        [OrderStatus.issued, OrderStatus.canceled].contains(order.status)) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        QrImageView(
          data: saved.pickupCode,
          size: 200,
          backgroundColor: Colors.white,
        ),
        const Text('Покажите QR на кассе для получения заказа'),
        OrderPushButton(pickupCode: saved.pickupCode),
      ],
    );
  }
}
