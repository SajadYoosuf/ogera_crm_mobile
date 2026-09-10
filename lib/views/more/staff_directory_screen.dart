import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/staff_palette.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/followup.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/followups_view_model.dart';

/// Head-only. Everyone who can be assigned follow-ups, each shown with the
/// identity colour they carry on the staff map, and how much is on their plate.
class StaffDirectoryScreen extends StatefulWidget {
  const StaffDirectoryScreen({super.key});

  @override
  State<StaffDirectoryScreen> createState() => _StaffDirectoryScreenState();
}

class _StaffDirectoryScreenState extends State<StaffDirectoryScreen> {
  List<StaffMember> _staff = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final staff = await context.read<StaffDirectoryService>().list();
      if (!mounted) return;
      setState(() {
        _staff = staff;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final followups = context.watch<FollowupsViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: const Text('Staff directory')),
      body: Builder(
        builder: (context) {
          if (_isLoading) return const LoadingListView(itemHeight: 74);
          if (_error != null) {
            return ErrorStateView(message: _error!, onRetry: _load);
          }
          if (_staff.isEmpty) {
            return const EmptyStateView(
              icon: Icons.badge_outlined,
              title: 'No staff found',
              message:
                  'Staff accounts are managed in Venting Next. Anyone with '
                  'CRM access will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                OgeraSpacing.screen,
                OgeraSpacing.screen,
                OgeraSpacing.screen,
                32,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _staff.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: OgeraSpacing.gap),
              itemBuilder: (context, index) {
                final member = _staff[index];
                final assigned = followups.visibleLeads
                    .where((lead) => lead.followupAssignedTo == member.id)
                    .length;
                // The same colour rule the staff map uses, so a person reads
                // the same in both places.
                final color = StaffPalette.colorFor(member.numericId);

                return OgeraCard(
                  accent: color,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  onTap: () {
                    followups.filterByAssignee(member.id);
                    Navigator.of(context).pop();
                    showToast(
                      context,
                      'Follow-ups filtered to ${member.name}.',
                    );
                  },
                  child: Row(
                    children: [
                      OgeraAvatar(name: member.name, size: 44, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 5),
                            StatusChip(
                              label: assigned == 1
                                  ? '1 lead assigned'
                                  : '$assigned leads assigned',
                              color: color,
                              icon: Icons.assignment_outlined,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.filter_alt_outlined,
                        size: 19,
                        color: OgeraColors.muted,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
