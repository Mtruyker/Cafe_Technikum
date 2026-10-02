import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:cafe_technikum/models/models.dart';
import 'package:cafe_technikum/state/techcafe_state.dart';
import 'package:cafe_technikum/widgets/pickup_slot_picker.dart';

class MockState extends Mock implements TechCafeState {}

void main() {
  testWidgets(
    'excludes full, closed and disabled slots; quantity change clears selection',
    (tester) async {
      final state = MockState();
      final now = DateTime.now();
      PickupSlot slot(
        String id,
        int remaining, {
        bool enabled = true,
        bool closed = false,
      }) => PickupSlot(
        id: id,
        startsAt: now.add(const Duration(hours: 2)),
        cutoffAt: now.add(Duration(hours: closed ? -1 : 1)),
        capacity: 10,
        remaining: remaining,
        enabled: enabled,
      );
      when(() => state.fetchPickupSlots()).thenAnswer(
        (_) async => [
          slot('full', 1),
          slot('open', 5),
          slot('closed', 10, closed: true),
          slot('disabled', 10, enabled: false),
        ],
      );
      String? selected;
      final form = GlobalKey<FormState>();
      Widget app(int qty) => ChangeNotifierProvider<TechCafeState>.value(
        value: state,
        child: MaterialApp(
          home: Scaffold(
            body: Form(
              key: form,
              child: PickupSlotPicker(
                portions: qty,
                onChanged: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(2));
      await tester.pumpAndSettle();
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.initialValue, isNull);
      expect(form.currentState!.validate(), isFalse);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 порц.'), findsWidgets);
      expect(find.textContaining('1 порц.'), findsNothing);
      expect(find.textContaining('10 порц.'), findsNothing);
      await tester.tap(find.textContaining('5 порц.').last);
      await tester.pumpAndSettle();
      expect(selected, 'open');
      expect(form.currentState!.validate(), isTrue);
      await tester.pumpWidget(app(6));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(form.currentState!.validate(), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
