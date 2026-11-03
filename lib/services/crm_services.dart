// crm_services.dart
//
// Re-export barrel — kept so existing imports do not need updating all at once.
// The actual code has moved to three focused files:
//
//   contacts_service.dart  — ContactsService, LeadSourceCatalog, SettingsOptionsCatalog
//   followups_service.dart — FollowupsService
//   staff_service.dart     — StaffDirectoryService
//
// New code should import the specific file it needs rather than this barrel.

export 'contacts_service.dart';
export 'followups_service.dart';
export 'staff_service.dart';
