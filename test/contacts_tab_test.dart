import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/contacts_view_model.dart';
import 'package:ogera_crm_mobile/views/contacts/contacts_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

/// The Contacts module: the Leads/Awareness filter chips, search, and the
/// resulting list all read from the query the server was actually sent, so
/// the fake API below filters by the `type` and `query` parameters the way
/// the real one would.
void main() {
  testWidgets('defaults to the Leads filter and shows only lead contacts', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel();
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('Search name or phone'), findsOneWidget);
    expect(find.text('Amina Lead'), findsOneWidget);
    expect(find.text('Bala Awareness'), findsNothing);
  });

  testWidgets(
    'switching to Awareness re-fetches and shows only awareness contacts',
    (tester) async {
      final viewModel = await _loadedViewModel();
      await tester.pumpWidget(_harness(viewModel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Awareness'));
      await tester.pumpAndSettle();

      expect(find.text('Bala Awareness'), findsOneWidget);
      expect(find.text('Amina Lead'), findsNothing);
    },
  );

  testWidgets('searching filters the current list and debounces the request', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel();
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz-no-match');
    // The search is debounced 350ms; a shorter pump must not have fetched yet.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Amina Lead'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No matching contacts'), findsOneWidget);
  });
}

Future<ContactsViewModel> _loadedViewModel() async {
  final api = fakeApiClient({
    '/contacts': (uri) {
      final mode = uri.queryParameters['awareness_mode'];
      final search = uri.queryParameters['search']?.toLowerCase();
      final all = [
        contactJson(id: 1, name: 'Amina Lead'),
        contactJson(id: 2, name: 'Bala Awareness', type: 'awareness'),
      ];
      final filtered = all.where((contact) {
        final matchesMode =
            mode == null || '${contact['awareness_mode']}' == mode;
        final matchesSearch =
            search == null ||
            search.isEmpty ||
            (contact['name'] as String).toLowerCase().contains(search);
        return matchesMode && matchesSearch;
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
