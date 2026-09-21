import 'package:ogera_crm_mobile/models/staff_location.dart';
import 'package:ogera_crm_mobile/services/location_api_service.dart';

/// A recording double for [LocationApiService]. `LocationTrackingService`
/// only ever calls [upload] and [reportState]; the manager/read endpoints are
/// left unimplemented since nothing under test in this suite exercises them
/// (they're already covered by `staff_location_contract_test.dart`).
class FakeLocationApiService implements LocationApiService {
  final List<List<PendingPoint>> uploadedBatches = [];
  final List<String> reportedStates = [];

  /// Thrown by the next [upload] call, then cleared — set it again for a
  /// second consecutive failure.
  Object? uploadError;

  @override
  Future<void> upload(List<PendingPoint> points) async {
    if (points.isEmpty) return;
    final error = uploadError;
    if (error != null) {
      uploadError = null;
      throw error;
    }
    uploadedBatches.add(points);
  }

  @override
  Future<void> reportState(String state) async {
    reportedStates.add(state);
  }

  @override
  Future<List<StaffLocation>> live() => throw UnimplementedError();

  @override
  Future<StaffRoute> history({required int userId, required String date}) =>
      throw UnimplementedError();

  @override
  Future<StaffRoute> myRoute({required int userId, String? date}) =>
      throw UnimplementedError();
}
