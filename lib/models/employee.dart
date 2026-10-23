/// Dart models for the employee directory.
///
/// Two classes:
///   EmployeeDirectoryEntry — lightweight row from GET /employees/directory
///   EmployeeDetail         — fuller profile from GET /employees/{id}
///
/// Neither class has a password field — the backend never returns one.
library;

import '../core/utils/formatters.dart';

class EmployeeDirectoryEntry {
  const EmployeeDirectoryEntry({
    required this.id,
    required this.name,
    required this.role,
    this.phone,
  });

  final int id;
  final String name;
  final String role;
  final String? phone;

  factory EmployeeDirectoryEntry.fromJson(Map<String, dynamic> json) {
    return EmployeeDirectoryEntry(
      id: asInt(json['id']) ?? 0,
      name: asText(json['name']) ?? '',
      role: asText(json['role']) ?? '',
      phone: asText(json['phone']),
    );
  }
}

class EmployeeDetail {
  const EmployeeDetail({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.branch,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? branch;
  final bool isActive;

  factory EmployeeDetail.fromJson(Map<String, dynamic> json) {
    return EmployeeDetail(
      id: asInt(json['id']) ?? 0,
      name: asText(json['name']) ?? '',
      email: asText(json['email']) ?? '',
      role: asText(json['role']) ?? '',
      phone: asText(json['phone']),
      branch: asText(json['branch']),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }
}
