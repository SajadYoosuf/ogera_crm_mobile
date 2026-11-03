import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/contact.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/contacts_view_model.dart';
import 'package:ogera_crm_mobile/views/contacts/contacts_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The Contacts tab: the Consumer / Partner / Dealer tabs, search, and the
/// resulting list all read from the query the server was actually sent, so the
/// fake API below filters by the `contact_type` and `search` parameters the way
/// the real one would.
void main() {
  testWidgets('Consumer is the default tab and shows only consumers', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel();
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Search name or phone'), findsOneWidget);
    expect(find.text('Consumer'), findsOneWidget);
    expect(find.text('Amina Consumer'), findsOneWidget);
    expect(find.text('Ravi Partner'), findsNothing);
    expect(find.text('Sunil Dealer'), findsNothing);
  });

  testWidgets('tabs show live counts from the type-counts endpoint', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel();
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(viewModel.countFor(null), 3);
    expect(viewModel.countFor(ContactKind.partner), 1);
    expect(find.text('Lead'), findsNothing);
    expect(find.text('Awareness'), findsNothing);
  });

  testWidgets('choosing Partner re-fetches and shows only partner contacts', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel();
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    // "Partner" is also each partner card's badge; the tab row comes first in
    // the tree, so the first match is the tab.
    await tester.tap(find.text('Partner').first);
    await tester.pumpAndSettle();

    expect(find.text('Ravi Partner'), findsOneWidget);
    expect(find.text('Amina Consumer'), findsNothing);
    expect(find.text('Sunil Dealer'), findsNothing);
  });

  testWidgets('searching filters the current list and debounces the request', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel();
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    // The search is debounced 350ms; a shorter pump must not have fetched yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Amina Consumer'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No matching contacts'), findsOneWidget);
  });
}

Future<ContactsViewModel> _loadedViewModel() async {
  final api = fakeApiClient({
    '/contacts/type-counts': (_) => {
      'all': 3,
      'consumer': 1,
      'partner': 1,
      'dealer': 1,
    },
    '/contacts': (uri) {
      final kind = uri.queryParameters['contact_type'];
      final search = uri.queryParameters['search']?.toLowerCase();
      final all = [
        contactJson(id: 1, name: 'Amina Consumer'),
        contactJson(id: 2, name: 'Ravi Partner', kind: 'partner'),
        contactJson(id: 3, name: 'Sunil Dealer', kind: 'dealer'),
      ];
      final filtered = all.where((contact) {
        final matchesKind = kind == null || contact['contact_type'] == kind;
        final matchesSearch =
            search == null ||
            search.isEmpty ||
            (contact['name'] as String).toLowerCase().contains(search);
        return matchesKind && matchesSearch;
      }).toList();
      final limit = int.parse(uri.queryParameters['limit'] ?? '20');
      return pageOf(
        filtered.take(limit).toList(),
        total: filtered.length,
        limit: limit,
      );
    },
  });
  final viewModel = ContactsViewModel(ContactsService(api));
  await viewModel.load();
  return viewModel;
}

Widget _harness(ContactsViewModel viewModel) {
  return ChangeNotifierProvider<ContactsViewModel>.value(
    value: viewModel,
    child: MaterialApp(theme: AppTheme.build(), home: const ContactsTab()),
  );
}
