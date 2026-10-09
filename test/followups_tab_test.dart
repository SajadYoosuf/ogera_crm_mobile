import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/auth_session.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/followups_view_model.dart';
import 'package:ogera_crm_mobile/views/followups/followups_tab.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

const _headUser = AuthUser(
  id: 1,
  email: 'head@ogera.com',
  name: 'Head User',
  phone: null,
  role: UserRole.salesHead,
);

const _staffUser = AuthUser(
  id: 2,
  email: 'staff@ogera.com',
  name: 'Staff User',
  phone: null,
  role: UserRole.salesStaff,
);

/// The Follow-ups module: everyone sees the same pipeline board, but only a
/// Head session can reassign leads or add one. The API fixes the stages, so
/// nobody manages them.
void main() {
  testWidgets('Head sees the stage board plus assign/add controls', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel(_headUser);
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Follow-ups'), findsOneWidget);
    // "New" appears both in the stage strip and on Priya's card, which also
    // sits in the New column.
    expect(find.text('New'), findsWidgets);
    expect(find.text('Won'), findsOneWidget); // stage strip chip only
    expect(find.text('Priya Lead'), findsOneWidget);

    expect(find.byTooltip('Manage stages'), findsNothing);
    expect(find.byTooltip('Filter by staff'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add lead'),
      findsOneWidget,
    );
  });

  testWidgets('Staff sees the same board without management controls', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel(_staffUser);
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Priya Lead'), findsOneWidget);
    expect(find.byTooltip('Manage stages'), findsNothing);
    expect(find.byTooltip('Filter by staff'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('tapping a stage chip switches the visible column', (
    tester,
  ) async {
    final viewModel = await _loadedViewModel(_headUser);
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('Priya Lead'), findsOneWidget);
    expect(find.text('Rohan Lead'), findsNothing);

    await tester.tap(find.text('Won'));
    await tester.pumpAndSettle();

    expect(find.text('Rohan Lead'), findsOneWidget);
    expect(find.text('Priya Lead'), findsNothing);
  });

  testWidgets('searching narrows the board to matching leads', (tester) async {
    final viewModel = await _loadedViewModel(_headUser);
    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'priya');
    await tester.pumpAndSettle();

    expect(find.text('Priya Lead'), findsOneWidget);

    await tester.tap(find.text('Won'));
    await tester.pumpAndSettle();
    expect(find.text('Rohan Lead'), findsNothing);
  });

  testWidgets('no pipeline stages shows the empty state', (tester) async {
    final api = fakeApiClient({
      '/contacts': (_) => pageOf([]),
      '/tasks': (_) => _noTasks,
      '/contacts/stage-types': (_) => <Map<String, dynamic>>[],
      '/employees/directory': (_) => <Map<String, dynamic>>[],
    });
    final viewModel = FollowupsViewModel(
      FollowupsService(api),
      StaffDirectoryService(api),
      _headUser,
    );
    await viewModel.load();

    await tester.pumpWidget(_harness(viewModel));
    await tester.pumpAndSettle();

    expect(find.text('No pipeline stages'), findsOneWidget);
  });
}

const _noTasks = {
  'items': <Map<String, dynamic>>[],
  'total': 0,
  'summary': {'overdue': 0, 'today': 0, 'upcoming': 0, 'done': 0},
};

Future<FollowupsViewModel> _loadedViewModel(AuthUser user) async {
  final api = fakeApiClient({
    '/contacts': (_) => pageOf([
      leadJson(id: 1, name: 'Priya Lead', stage: 'new'),
      leadJson(id: 2, name: 'Rohan Lead', stage: 'won'),
    ]),
    '/tasks': (_) => _noTasks,
    '/contacts/stage-types': (_) => [
      stageJson(id: 'new', label: 'New', orderIndex: 0),
      stageJson(id: 'won', label: 'Won', orderIndex: 1),
    ],
    '/employees/directory': (_) => <Map<String, dynamic>>[],
  });
  final viewModel = FollowupsViewModel(
    FollowupsService(api),
    StaffDirectoryService(api),
    user,
  );
  await viewModel.load();
  return viewModel;
}

Widget _harness(FollowupsViewModel viewModel) {
  return ChangeNotifierProvider<FollowupsViewModel>.value(
    value: viewModel,
    child: MaterialApp(theme: AppTheme.build(), home: const FollowupsTab()),
  );
}
