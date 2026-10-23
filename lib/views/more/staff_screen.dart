/// Staff directory screen — read-only list of active employees.
///
/// WHAT IT SHOWS:
///   - All active employees from GET /employees/directory.
///   - Name, role, phone number.
///   - Tap the phone icon to call.
///   - Read-only — no edit/add buttons.
///
/// WHO CAN ACCESS:
///   All signed-in employees (the backend enforces; admin accounts are hidden
///   per rule.md rule 3).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/launchers.dart' show Launchers;
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/employee.dart';
import '../../services/employees_service.dart';
import '../../theme/ogera_colors.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  bool _loading = false;
  String? _error;
  List<EmployeeDirectoryEntry> _staff = [];
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _staff = await context.read<EmployeesService>().directory();
    } catch (e) {
      _error = e.toString();
    } finally {
      setState(() => _loading = false);
    }
  }

  static const _hiddenRoles = {'admin', 'manager'};

  List<EmployeeDirectoryEntry> get _filtered {
    final visible = _staff
        .where((s) => !_hiddenRoles.contains(s.role.toLowerCase()))
        .toList();
    if (_query.isEmpty) return visible;
    return visible
        .where(
          (s) =>
              s.name.toLowerCase().contains(_query) ||
              s.role.toLowerCase().contains(_query) ||
              (s.phone ?? '').contains(_query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Staff Directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: OgeraSearchField(
              controller: _searchController,
              hint: 'Search by name or role…',
              onChanged: (_) {},
            ),
          ),
          Expanded(
            child: Builder(
              builder: (_) {
                if (_loading) return const LoadingListView(itemHeight: 64);
                if (_error != null) {
                  return ErrorStateView(message: _error!, onRetry: _load);
                }
                if (_filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.people_outline_rounded,
                    title: 'No staff',
                    message: 'No active employees found.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  itemCount: _filtered.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _StaffCard(member: _filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});
  final EmployeeDirectoryEntry member;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          OgeraAvatar(name: member.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                StatusChip(
                  label: _formatRole(member.role),
                  tone: StatusTone.neutral,
                  dense: true,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Launchers.call(context, member.phone ?? ''),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OgeraColors.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.phone_outlined,
                size: 18,
                color: OgeraColors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRole(String role) {
    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}
