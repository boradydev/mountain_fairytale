import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mountain_fairytale/features/delivery_route/ui/document_connection_dialog.dart';

import 'document_provider_test.dart' show Orders, Catalog, Locks;

void main() {
  for (final width in [800.0, 420.0]) {
    testWidgets(
      'reconnect spinner preserves dialog and button geometry at $width px',
      (tester) async {
        tester.view.physicalSize = Size(width, 650);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = Orders(Catalog(), Locks());
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DocumentConnectionDialog(provider: provider)),
          ),
        );
        await tester.pumpAndSettle();
        final dialog = find.byType(AlertDialog);
        final button = find.byType(FilledButton);
        final dialogRect = tester.getRect(dialog);
        final buttonRect = tester.getRect(button);
        provider.reconnecting = true;
        provider.notifyListeners();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(tester.getRect(dialog), dialogRect);
        expect(tester.getRect(button), buttonRect);
        provider.reconnecting = false;
        provider.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.getRect(dialog), dialogRect);
        expect(tester.getRect(button), buttonRect);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
