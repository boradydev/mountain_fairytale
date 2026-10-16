import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/shared/widgets/dropdown_widget.dart';

void main() {
  testWidgets(
    'external selection updates preserve field and validation state',
    (tester) async {
      final formKey = GlobalKey<FormState>();
      String? value;
      var changes = 0;
      var isLoading = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return AppDropdown<String>(
                    label: 'Запись',
                    isLoading: isLoading,
                    items: const ['Первая', 'Вторая'],
                    value: value,
                    onChanged: (_) => changes++,
                    validator: (v) => v == null ? 'Выберите запись' : null,
                  );
                },
              ),
            ),
          ),
        ),
      );
      final field = find.byType(DropdownButtonFormField<String>);
      final originalState = tester.state<FormFieldState<String>>(field);
      final dropdown = find.byType(AppDropdown<String>);
      final initialRect = tester.getRect(dropdown);
      final initialFieldRect = tester.getRect(field);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      update(() => isLoading = true);
      await tester.pump();
      final progressRect = tester.getRect(find.byType(LinearProgressIndicator));
      expect(progressRect.top - tester.getRect(field).bottom, 4);
      expect(progressRect.height, 4);
      expect(tester.getRect(dropdown), initialRect);
      expect(tester.getRect(field), initialFieldRect);
      expect(tester.state(field), same(originalState));
      update(() => isLoading = false);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getRect(dropdown), initialRect);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      update(() => value = 'Первая');
      await tester.pumpAndSettle();
      expect(tester.state(field), same(originalState));
      expect(originalState.value, 'Первая');
      expect(originalState.hasError, isTrue);
      expect(changes, 0);
      expect(formKey.currentState!.validate(), isTrue);
      update(() => value = 'Вторая');
      await tester.pumpAndSettle();
      expect(tester.state(field), same(originalState));
      expect(originalState.value, 'Вторая');
      update(() => value = null);
      await tester.pumpAndSettle();
      expect(tester.state(field), same(originalState));
      expect(originalState.value, isNull);
      expect(changes, 0);
    },
  );
}
