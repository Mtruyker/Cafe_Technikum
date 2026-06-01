import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/screens/order_success_screen.dart';
import 'package:cafe_technikum/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  OrderCreatedResponse buildResult({String qrCodeData = 'A-101'}) {
    return OrderCreatedResponse(
      orderId: 'order-101',
      orderNumber: 'A-101',
      qrCodeData: qrCodeData,
      status: OrderStatus.created,
      total: 480,
      createdAt: DateTime.utc(2026, 4, 16, 16, 13),
      paymentMethod: PaymentMethod.payOnPickup,
      paymentStatus: PaymentStatus.unpaid,
      providerPaymentId: null,
      paidAt: null,
    );
  }

  Widget buildScreen(OrderCreatedResponse result) {
    return MaterialApp(
      theme: AppTheme.student(),
      home: OrderSuccessScreen(result: result),
    );
  }

  testWidgets('stays within a narrow mobile width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildScreen(buildResult()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);

    final screenRect = Offset.zero & const Size(320, 780);
    final filledButtonRect = tester.getRect(find.byType(FilledButton));
    final outlinedButtonRect = tester.getRect(find.byType(OutlinedButton));

    expect(filledButtonRect.left, greaterThanOrEqualTo(screenRect.left));
    expect(filledButtonRect.right, lessThanOrEqualTo(screenRect.right));
    expect(outlinedButtonRect.left, greaterThanOrEqualTo(screenRect.left));
    expect(outlinedButtonRect.right, lessThanOrEqualTo(screenRect.right));
  });

  testWidgets('renders qr widget even when qrCodeData is empty', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen(buildResult(qrCodeData: '   ')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QrImageView), findsOneWidget);
  });
}
