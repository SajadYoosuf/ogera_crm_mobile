import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/professional.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/theme/app_theme.dart';
import 'package:ogera_crm_mobile/view_models/professionals_view_model.dart';
import 'package:ogera_crm_mobile/views/professionals/professional_form_screen.dart';
import 'package:ogera_crm_mobile/views/professionals/professionals_tab.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Professionals tab renders loaded rows and filter counts', (
    tester,
  ) async {
    final viewModel = ProfessionalsViewModel(
      _FakeProfessionalsService(
        professionals: [
          _professional(id: 1, name: 'Arun Plumber', type: ProfessionalType.plumber),
          _professional(id: 2, name: 'Bina Engineer', type: ProfessionalType.engineer),
        ],
      ),
    );
    await viewModel.load();

    await tester.pumpWidget(_professionalsHarness(viewModel));

    expect(find.text('Professionals'), findsOneWidget);
    expect(find.text('Search name, phone, or place'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Arun Plumber'), findsOneWidget);
    expect(find.text('Bina Engineer'), findsOneWidget);
    expect(find.text('Plumber'), findsWidgets);
    expect(find.text('Engineer'), findsWidgets);
  });

  testWidgets('Professionals tab shows search-specific empty copy', (
    tester,
  ) async {
    final service = _FakeProfessionalsService();
    final viewModel = ProfessionalsViewModel(service);
    await viewModel.load();

    await tester.pumpWidget(_professionalsHarness(viewModel));
    await tester.enterText(
      find.byType(TextField),
      'missing professional',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(service.lastQuery, 'missing professional');
    expect(find.text('No matching professionals'), findsOneWidget);
    expect(
      find.textContaining('Nothing matches "missing professional"'),
      findsOneWidget,
    );
  });

  testWidgets('Professional form creates a professional from entered fields', (
    tester,
  ) async {
    final service = _FakeProfessionalsService();

    await tester.pumpWidget(_formHarness(service));

    await tester.tap(find.text('Plumber'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Maya');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone *'),
      '9876543210',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Place'),
      'Kochi',
    );
    final submit = find.widgetWithText(FilledButton, 'Add professional');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(service.createdDraft?.type, ProfessionalType.plumber);
    expect(service.createdDraft?.name, 'Maya');
    expect(service.createdDraft?.phone, '9876543210');
    expect(service.createdDraft?.place, 'Kochi');
    expect(find.text('Professional added.'), findsOneWidget);
  });
}

Widget _professionalsHarness(ProfessionalsViewModel viewModel) {
  return ChangeNotifierProvider<ProfessionalsViewModel>.value(
    value: viewModel,
    child: MaterialApp(theme: AppTheme.build(), home: const ProfessionalsTab()),
  );
}

Widget _formHarness(_FakeProfessionalsService service) {
  return Provider<ProfessionalsService>.value(
    value: service,
    child: MaterialApp(
      theme: AppTheme.build(),
      home: const ProfessionalFormScreen(),
    ),
  );
}

Professional _professional({
  required int id,
  String? name,
  ProfessionalType type = ProfessionalType.engineer,
}) {
  return Professional(
    id: id,
    phone: '98765432${id.toString().padLeft(2, '0')}',
    type: type,
    name: name,
    place: 'Kochi',
    createdAt: DateTime(2026, 1, id),
    createdByUserId: 1,
  );
}

class _FakeProfessionalsService extends ProfessionalsService {
  _FakeProfessionalsService({List<Professional> professionals = const []})
    : _professionals = professionals,
      super(_UnusedApiClient());

  final List<Professional> _professionals;
  String? lastQuery;
  ProfessionalDraft? createdDraft;

  @override
  Future<List<Professional>> list({
    ProfessionalType? type,
    String? query,
  }) async {
    lastQuery = query;
    return _professionals
        .where((professional) => type == null || professional.type == type)
        .where((professional) {
          if (query == null || query.isEmpty) return true;
          final needle = query.toLowerCase();
          return professional.displayName.toLowerCase().contains(needle) ||
              professional.phone.contains(needle) ||
              (professional.place ?? '').toLowerCase().contains(needle);
        })
        .toList(growable: false);
  }

  @override
  Future<Professional> create(ProfessionalDraft draft) async {
    createdDraft = draft;
    return Professional(
      id: 42,
      phone: draft.phone.trim(),
      type: draft.type,
      name: draft.name,
      place: draft.place,
      address: draft.address,
      district: draft.district,
      panchayath: draft.panchayath,
      latitude: draft.latitude,
      longitude: draft.longitude,
      createdAt: DateTime(2026, 1, 4),
      createdByUserId: 1,
    );
  }
}

class _UnusedApiClient extends ApiClient {}
