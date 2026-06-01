import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../theme.dart';
import '../utils/formatters.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.result});

  final OrderCreatedResponse result;

  @override
  Widget build(BuildContext context) {
    final qrData = result.resolvedQrCodeData;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Заказ оформлен'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Номер заказа: ${result.orderNumber}',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Статус: ${result.status.label}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'Сумма: ${formatRub(result.total)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final qrSize = math
                            .max(
                              160.0,
                              math.min(
                                constraints.maxWidth - (AppSpacing.sm * 2),
                                220.0,
                              ),
                            )
                            .toDouble();

                        return Semantics(
                          image: true,
                          label:
                              'QR-код для заказа ${result.orderNumber}. Можно показать его на кассе.',
                          child: ExcludeSemantics(
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.qrBackground,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.black12),
                              ),
                              child: Center(
                                child: QrImageView(
                                  data: qrData,
                                  size: qrSize,
                                  backgroundColor: AppColors.qrBackground,
                                  errorStateBuilder: (context, error) {
                                    return _QrFallback(
                                      orderNumber: result.orderNumber,
                                    );
                                  },
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Покажите номер или QR на кассе',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      button: true,
                      label:
                          'Перейти к отслеживанию заказа ${result.orderNumber}',
                      child: FilledButton(
                        onPressed: () {
                          context.push(
                            '/tracking/${Uri.encodeComponent(result.orderNumber)}',
                          );
                        },
                        child: const Text('Отслеживать'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      button: true,
                      label: 'Вернуться к меню',
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('К меню'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrFallback extends StatelessWidget {
  const _QrFallback({required this.orderNumber});

  final String orderNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.qr_code_2_outlined, size: 40),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'QR временно недоступен',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          orderNumber,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
