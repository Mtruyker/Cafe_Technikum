import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';
import 'package:cafe_technikum/widgets/pickup_slot_picker.dart';

class MockState extends Mock implements TechCafeState {}

void main() {
  for (final hasSlots in [false, true]) {
    testWidgets('pickup selection with available slots: $hasSlots', (
      tester,
    ) async {
      final state = MockState();
      final form = GlobalKey<FormState>();
      String? selected;
      when(() => state.fetchPickupSlots()).thenAnswer(
        (_) async => hasSlots
            ? [
                PickupSlot(
                  id: 'slot',
                  startsAt: DateTime.now().add(const Duration(days: 1)),
                  cutoffAt: DateTime.now().add(const Duration(hours: 23)),
                  capacity: 30,
                  remaining: 30,
                  enabled: true,
                ),
              ]
            : [],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<TechCafeState>.value(
          value: state,
          child: MaterialApp(
            home: Scaffold(
              body: Form(
                key: form,
                child: PickupSlotPicker(
                  portions: 1,
                  onChanged: (value) => selected = value,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (hasSlots) {
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('30 порц.').last);
        await tester.pumpAndSettle();
        expect(selected, 'slot');
        expect(form.currentState!.validate(), isTrue);
      } else {
        expect(form.currentState!.validate(), isFalse);
        await tester.pump();
        expect(
          find.textContaining('Расписание получения пока не опубликовано'),
          findsWidgets,
        );
        expect(find.text('Выберите доступное время получения'), findsNothing);
      }
    });
  }
}
