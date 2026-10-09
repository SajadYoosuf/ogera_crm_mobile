import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/professional.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/view_models/professionals_view_model.dart';

void main() {
  group('ProfessionalsViewModel', () {
    test('loads professionals newest first and exposes type counts', () async {
      final service = _FakeProfessionalsService(
        professionals: [
          _professional(
            id: 1,
            name: 'Babu',
            type: ProfessionalType.plumber,
            createdAt: DateTime(2026, 1, 1),
          ),
          _professional(
            id: 2,
            name: 'Anu',
            type: ProfessionalType.engineer,
            createdAt: DateTime(2026, 1, 3),
          ),
        ],
      );
      final viewModel = ProfessionalsViewModel(service);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.professionals.map((item) => item.id), [2, 1]);
      expect(viewModel.total, 2);
      expect(viewModel.countFor(ProfessionalType.engineer), 1);
      expect(viewModel.countFor(ProfessionalType.plumber), 1);
    });

    test(
      'passes selected type and trimmed search query to the service',
      () async {
        final service = _FakeProfessionalsService();
        final viewModel = ProfessionalsViewModel(service);

        viewModel.selectType(ProfessionalType.contractor);
        await _flushMicrotasks();
        viewModel.search('  kochi  ');
        await Future<void>.delayed(const Duration(milliseconds: 400));

        expect(service.lastType, ProfessionalType.contractor);
        expect(service.lastQuery, 'kochi');
      },
    );

    test('sorts the loaded list by name without another fetch', () async {
      final service = _FakeProfessionalsService(
        professionals: [
          _professional(id: 1, name: 'Zara'),
          _professional(id: 2, name: 'Arun'),
        ],
      );
      final viewModel = ProfessionalsViewModel(service);
      await viewModel.load();

      viewModel.setSort(ProfessionalSort.name);

      expect(viewModel.professionals.map((item) => item.displayName), [
        'Arun',
        'Zara',
      ]);
      expect(service.listCalls, 1);
    });

    test('clears stale data and reports API failures', () async {
      final service = _FakeProfessionalsService(
        professionals: [_professional(id: 1, name: 'Arun')],
      );
      final viewModel = ProfessionalsViewModel(service);
      await viewModel.load();

      service.error = const ApiException(
        'You do not have access to this.',
        statusCode: 403,
      );
      await viewModel.load();

      expect(viewModel.professionals, isEmpty);
      expect(viewModel.error, 'You do not have access to this.');
      expect(viewModel.errorKind, FailureKind.forbidden);
      expect(viewModel.isLoading, isFalse);
    });

    test('upserts and removes local rows', () async {
      final viewModel = ProfessionalsViewModel(
        _FakeProfessionalsService(
          professionals: [_professional(id: 1, name: 'Arun')],
        ),
      );
      await viewModel.load();

      viewModel.upsert(_professional(id: 1, name: 'Arun Updated'));
      viewModel.upsert(_professional(id: 2, name: 'Beena'));
      viewModel.removeById(1);

      expect(viewModel.professionals.map((item) => item.displayName), [
        'Beena',
      ]);
    });
  });

  group('ProfessionalFormViewModel', () {
    test('validates phone numbers before save', () {
      final viewModel = ProfessionalFormViewModel(_FakeProfessionalsService());

      expect(viewModel.validatePhone(''), 'Enter a phone number.');
      expect(viewModel.validatePhone('12345'), 'Enter at least 10 digits.');
      expect(viewModel.validatePhone('+91 98765 43210'), isNull);
    });

    test('creates a new professional draft', () async {
      final service = _FakeProfessionalsService();
      final viewModel = ProfessionalFormViewModel(service);
      viewModel.draft
        ..name = 'Maya'
        ..phone = ' 9876543210 '
        ..district = 'Kozhikode'
        ..address = 'Beach Road'
        ..type = ProfessionalType.interiorDesigner;

      final saved = await viewModel.save();

      expect(saved?.displayName, 'Maya');
      // A partner contact: the profession travels as the API's value.
      expect(service.createdDraft?.toApiJson(), {
        'contact_type': 'partner',
        'phone': '9876543210',
        'name': 'Maya',
        'address': 'Beach Road',
        'district': 'Kozhikode',
        'partner_profile': {'profession_type': 'interior_designer'},
      });
      expect(viewModel.isSaving, isFalse);
      expect(viewModel.error, isNull);
    });

    test(
      'asks for a district and an address before calling the server',
      () async {
        final service = _FakeProfessionalsService();
        final viewModel = ProfessionalFormViewModel(service);
        viewModel.draft.phone = '9876543210';

        expect(await viewModel.save(), isNull);
        expect(viewModel.error, 'Select the district.');

        viewModel.draft.district = 'Kozhikode';
        expect(await viewModel.save(), isNull);
        expect(viewModel.error, 'Enter the address.');
        expect(service.createdDraft, isNull);
      },
    );

    test('shows the server message when the save is rejected', () async {
      final viewModel = ProfessionalFormViewModel(
        _FakeProfessionalsService(
          saveError: const ApiException(
            'Partner type is not valid.',
            statusCode: 422,
          ),
        ),
      );
      viewModel.draft
        ..phone = '9876543210'
        ..district = 'Kozhikode'
        ..address = 'Beach Road'
        ..type = ProfessionalType.engineer;

      final saved = await viewModel.save();

      expect(saved, isNull);
      expect(viewModel.error, 'Partner type is not valid.');
      expect(viewModel.isSaving, isFalse);
    });
  });
}

Future<void> _flushMicrotasks() => Future<void>.delayed(Duration.zero);

Professional _professional({
  required int id,
  String? name,
  ProfessionalType type = ProfessionalType.engineer,
  DateTime? createdAt,
}) {
  return Professional(
    id: id,
    phone: '98765432${id.toString().padLeft(2, '0')}',
    type: type,
    name: name,
    place: 'Kochi',
    createdAt: createdAt ?? DateTime(2026, 1, id),
    createdByUserId: 1,
  );
}

class _FakeProfessionalsService extends ProfessionalsService {
  _FakeProfessionalsService({
    List<Professional> professionals = const [],
    this.error,
    this.saveError,
  }) : _professionals = professionals,
       super(_UnusedApiClient());

  final List<Professional> _professionals;
  ApiException? error;
  ApiException? saveError;
  int listCalls = 0;
  ProfessionalType? lastType;
  String? lastQuery;
  ProfessionalDraft? createdDraft;

  @override
  Future<List<Professional>> list({
    ProfessionalType? type,
    String? query,
  }) async {
    listCalls += 1;
    lastType = type;
    lastQuery = query;
    final failure = error;
    if (failure != null) throw failure;
    return _professionals;
  }

  @override
  Future<Professional> create(ProfessionalDraft draft) async {
    createdDraft = draft;
    final failure = saveError;
    if (failure != null) throw failure;
    return Professional(
      id: 99,
      phone: draft.phone.trim(),
      type: draft.type,
      name: draft.name,
      place: draft.place,
      address: draft.address,
      district: draft.district,
      panchayath: draft.panchayath,
      latitude: draft.latitude,
      longitude: draft.longitude,
      createdAt: DateTime(2026, 1, 9),
      createdByUserId: 1,
    );
  }
}

class _UnusedApiClient extends ApiClient {}
