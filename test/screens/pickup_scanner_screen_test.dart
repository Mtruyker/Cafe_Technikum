import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/screens/pickup_scanner_screen.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';

class MockState extends Mock implements TechCafeState {}

void main() {
  testWidgets(
    'inspection shows order and requires separate issuance confirmation',
    (tester) async {
      final state = MockState();
      final ready = CafeOrder.fromJson({
        'id': 'id',
        'orderNumber': 'A42',
        'status': 'ready',
        'total': 250,
        'paymentStatus': 'unpaid',
      });
      final issued = CafeOrder.fromJson({
        'id': 'id',
        'orderNumber': 'A42',
        'status': 'issued',
        'total': 250,
        'paymentStatus': 'paid',
      });
      when(
        () => state.inspectPickupCode('techcafe:pickup:test'),
      ).thenAnswer((_) async => ready);
      when(
        () => state.redeemPickupCode(
          'techcafe:pickup:test',
          paymentReceived: true,
        ),
      ).thenAnswer((_) async => issued);
      await tester.pumpWidget(
        ChangeNotifierProvider<TechCafeState>.value(
          value: state,
          child: const MaterialApp(home: PickupScannerScreen()),
        ),
      );
      await tester.enterText(find.byType(TextField), 'techcafe:pickup:test');
      await tester.tap(find.text('Проверить заказ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Заказ A42'), findsOneWidget);
      verifyNever(
        () => state.redeemPickupCode(
          any(),
          paymentReceived: any(named: 'paymentReceived'),
        ),
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('Подтвердить выдачу'));
      await tester.tap(find.text('Подтвердить выдачу'));
      await tester.pumpAndSettle();
      expect(find.text('Заказ A42 выдан'), findsOneWidget);
      verify(
        () => state.redeemPickupCode(
          'techcafe:pickup:test',
          paymentReceived: true,
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
    },
  );
}
