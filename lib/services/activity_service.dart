/// Activity log service.
///
/// Wraps:
///   POST /contacts/{contact_id}/activities — log one activity on a contact
///
/// The backend checks that the signed-in user can see the contact, so a
/// contact outside their scope returns 404 and the sheet shows the error.
library;

import '../core/network/api_client.dart';
import '../models/activity_log.dart';

class ActivityService {
  ActivityService(this._api);

  final ApiClient _api;

  /// Saves one activity on [contactId]. Throws [ApiException] on failure.
  Future<void> log(int contactId, ActivityDraft draft) async {
    await _api.post('/contacts/$contactId/activities', body: draft.toJson());
  }
}
