import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/views/contacts/contacts_tab.dart';

/// The list card shows the country of each number, and flags a number that
/// cannot be dialled instead of showing it as if it were fine.
void main() {
  testWidgets('a UAE number shows its GCC label and the +971 form', (
    tester,
  ) async {
    await _pumpCard(tester, phone: '0501234567');

    expect(find.text('+971 501234567'), findsOneWidget);
    expect(find.text('GCC · UAE'), findsOneWidget);
    expect(find.text('Check number'), findsNothing);
  });

  testWidgets('an Indian number shows +91 and no GCC label', (tester) async {
    await _pumpCard(tester, phone: '98765 43210');

    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
    expect(find.textContaining('GCC'), findsNothing);
  });

  testWidgets('an unusable number is flagged for checking', (tester) async {
    await _pumpCard(tester, phone: '12345');

    expect(find.text('Check number'), findsOneWidget);
  });
}

Future<void> _pumpCard(WidgetTester tester, {required String phone}) async {
  final contact = Contact.fromJson({
    'id': 7,
    'name': 'Test Lead',
    'phone': phone,
    'contact_type': 'consumer',
    'created_at': '2026-10-01T10:00:00',
    'lead_source': {'id': 1, 'name': 'Meta', 'slug': 'meta'},
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(),
      home: Scaffold(body: ContactCard(contact: contact)),
    ),
  );
  await tester.pumpAndSettle();
}
