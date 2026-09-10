import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/widgets/form_fields.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';

void main() {
  testWidgets('OgeraPickerField opens from the chevron side of the field', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: OgeraPickerField(
                label: 'Source',
                value: null,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );

    final field = find.byType(InputDecorator);
    final topRight = tester.getTopRight(field);
    await tester.tapAt(topRight + const Offset(-20, 28));

    expect(taps, 1);
  });

  testWidgets('showOptionPicker filters and returns the selected option', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  selected = await showOptionPicker<String>(
                    context,
                    title: 'District',
                    options: const ['Malappuram', 'Kozhikode'],
                    labelOf: (value) => value,
                  );
                },
                child: const Text('Pick'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pick'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'kozhi');
    await tester.pumpAndSettle();

    expect(find.text('Malappuram'), findsNothing);
    await tester.tap(find.text('Kozhikode'));
    await tester.pumpAndSettle();

    expect(selected, 'Kozhikode');
  });
}
