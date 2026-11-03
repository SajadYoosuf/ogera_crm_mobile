import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/utils/country_codes.dart';
import 'package:ogera_crm_mobile/core/widgets/phone_number_field.dart';

/// Hosts the field in a form with a Save-like validate button, the same way
/// the add-contact sheet does. [onCountry] records the country the user picks.
Widget _host({
  required TextEditingController controller,
  required DialCountry? country,
  required ValueChanged<DialCountry> onCountry,
  required GlobalKey<FormState> formKey,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Form(
        key: formKey,
        child: ListView(
          children: [
            PhoneNumberField(
              controller: controller,
              country: country,
              onCountryChanged: onCountry,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the selected dial code and the number box', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        controller: controller,
        country: defaultDialCountry,
        onCountry: (_) {},
        formKey: formKey,
      ),
    );

    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Mobile number *'), findsOneWidget);
  });

  testWidgets('a short number shows the country length message', (
    tester,
  ) async {
    final controller = TextEditingController(text: '98765');
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        controller: controller,
        country: defaultDialCountry,
        onCountry: (_) {},
        formKey: formKey,
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Enter 10 digits for India'), findsOneWidget);
  });

  testWidgets('typing more than 10 digits keeps only 10', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      _host(
        controller: controller,
        country: defaultDialCountry,
        onCountry: (_) {},
        formKey: formKey,
      ),
    );

    await tester.enterText(find.byType(TextFormField), '98765432109876');
    await tester.pump();
    expect(controller.text, '9876543210');
  });

  testWidgets('picking a country from the sheet reports the choice', (
    tester,
  ) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DialCountry? chosen;
    await tester.pumpWidget(
      _host(
        controller: controller,
        country: defaultDialCountry,
        onCountry: (country) => chosen = country,
        formKey: formKey,
      ),
    );

    await tester.tap(find.text('+91'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'qatar');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qatar'));
    await tester.pumpAndSettle();

    expect(chosen?.iso, 'QA');
  });

  test('filterCountries finds a country by dial code with a plus', () {
    final results = filterCountries('+971');
    expect(results.map((c) => c.iso), contains('AE'));
  });
}
