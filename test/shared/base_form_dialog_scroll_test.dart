import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/shared/widgets/base_form_dialog_widget.dart';
import 'package:mountain_fairytale/shared/widgets/text_button_widget.dart';

void main() {
  testWidgets(
    'text action remains usable and wraps on narrow screens',
    (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var deactivated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: BaseFormDialog(
            title: 'Редактирование',
            submitButtonText: 'Сохранить',
            submitButtonWidth: 160,
            onSubmit: () {},
            formKey: GlobalKey<FormState>(),
            leadingAction: AppSecondaryButton(
              text: 'Деактивировать',
              destructive: true,
              onPressed: () => deactivated = true,
            ),
            children: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.text('Деактивировать');
      final cancel = find.text('Отмена');
      final save = find.text('Сохранить');
      expect(
        tester.getCenter(action).dy,
        lessThanOrEqualTo(tester.getCenter(save).dy),
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(400, 600);
      await tester.pumpAndSettle();
      expect(tester.getCenter(action).dy, lessThan(tester.getCenter(save).dy));
      expect(
        tester.getCenter(cancel).dy,
        lessThanOrEqualTo(tester.getCenter(save).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      expect(deactivated, isTrue);
    },
  );

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets(
      'form reserves scrollbar space without resizing fields on $platform',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final formKey = GlobalKey<FormState>();
        var saved = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: platform),
            home: Scaffold(
              body: BaseFormDialog(
                title: 'Проверка формы',
                submitButtonText: 'Сохранить',
                onSubmit: () => saved = true,
                formKey: formKey,
                children: [
                  for (var index = 0; index < 5; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        key: ValueKey('field-$index'),
                        decoration: InputDecoration(
                          labelText: 'Поле $index',
                          border: const OutlineInputBorder(),
                        ),
                        validator: (_) =>
                            index == 0 ? 'Введите значение' : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('field-0'));
        final scrollView = find.byType(SingleChildScrollView);
        final original = tester.getRect(first);
        expect(original.width, 452);
        expect(tester.getRect(scrollView).right - original.right, 16);
        expect(
          find.byType(Scrollbar),
          platform == TargetPlatform.windows ? findsOneWidget : findsNothing,
        );

        // A shorter window and validation errors must not move the field edges.
        tester.view.physicalSize = const Size(800, 380);
        formKey.currentState!.validate();
        await tester.pumpAndSettle();
        final resized = tester.getRect(first);
        expect(resized.left, original.left);
        expect(resized.right, original.right);
        final scrollable = tester.state<ScrollableState>(
          find.byType(Scrollable).first,
        );
        expect(scrollable.position.maxScrollExtent, greaterThan(0));
        await tester.ensureVisible(find.text('Сохранить'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Сохранить'));
        expect(saved, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
