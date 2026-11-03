import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/followup.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import '../../view_models/followups_view_model.dart';
import '../contacts/contact_form_screen.dart';
import 'lead_detail_screen.dart';
import 'manage_stages_sheet.dart';
import '../shell_scope.dart';

/// One follow-up pipeline for every role.
///
/// Admin and Sales Head can manage assignments and stages. Sales Staff can see
/// the full board, but updates are limited to leads assigned to them.
class FollowupsTab extends StatelessWidget {
  const FollowupsTab({super.key});

  @override
  Widget build(BuildContext context) => const _HeadBoard();
}

// ---------------------------------------------------------------- head board

class _HeadBoard extends StatefulWidget {
  const _HeadBoard();

  @override
  State<_HeadBoard> createState() => _HeadBoardState();
}

class _HeadBoardState extends State<_HeadBoard> {
  final _pageController = PageController();
  final _searchController = TextEditingController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _goToStage(int index) {
    setState(() => _page = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FollowupsViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Follow-ups'),
        actions: [
          if (viewModel.canManageStages)
            IconButton(
              tooltip: 'Manage stages',
              onPressed: () => showManageStages(context),
              icon: const Icon(Icons.view_column_outlined),
            ),
          if (viewModel.canFilterByAssignee)
            IconButton(
              tooltip: 'Filter by staff',
              onPressed: () => _pickAssignee(context, viewModel),
              icon: Badge(
                isLabelVisible: viewModel.assigneeFilter != null,
                backgroundColor: OgeraColors.blue,
                child: const Icon(Icons.person_search_outlined),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: viewModel.canAssign
          ? FloatingActionButton.extended(
              onPressed: () => openLeadForm(context),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add lead'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Builder(
        builder: (context) {
          if (viewModel.isLoading) {
            return const LoadingListView(itemHeight: 108);
          }
          if (viewModel.error != null) {
            return ErrorStateView(
              message: viewModel.error!,
              onRetry: viewModel.load,
            );
          }
          if (viewModel.stages.isEmpty) {
            return EmptyStateView(
              icon: Icons.view_column_outlined,
              title: 'No pipeline stages',
              message:
                  'The server has not sent the pipeline stages yet. Pull '
                  'down to try again.',
              actionLabel: viewModel.canManageStages ? 'Manage stages' : null,
              onAction: viewModel.canManageStages
                  ? () => showManageStages(context)
                  : null,
            );
          }

          final stages = viewModel.stages;
          final index = _page.clamp(0, stages.length - 1);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OgeraSpacing.screen,
                  4,
                  OgeraSpacing.screen,
                  10,
                ),
                child: OgeraSearchField(
                  controller: _searchController,
                  hint: 'Search leads by name or phone',
                  onChanged: viewModel.search,
                ),
              ),
              _StageStrip(
                stages: stages,
                selected: index,
                countOf: (stage) => viewModel.countInStage(stage.id),
                onSelected: _goToStage,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemCount: stages.length,
                  itemBuilder: (context, page) =>
                      _StageColumn(stage: stages[page]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAssignee(
    BuildContext context,
    FollowupsViewModel viewModel,
  ) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter by staff',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('Everyone'),
              selected: viewModel.assigneeFilter == null,
              onTap: () => Navigator.of(context).pop(null),
            ),
            for (final member in viewModel.staff)
              ListTile(
                leading: OgeraAvatar(name: member.name, size: 36),
                title: Text(member.name),
                selected: viewModel.assigneeFilter == member.id,
                onTap: () => Navigator.of(context).pop(member.id),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    viewModel.filterByAssignee(selected);
  }
}

Future<void> openLeadForm(BuildContext context) async {
  final contacts = context.read<ContactsViewModel>();
  final followups = context.read<FollowupsViewModel>();
  final created = await pushShellRoute<dynamic>(
    context,
    (_) => const ContactFormScreen(),
  );
  if (created != null) {
    contacts.refresh();
    followups.refresh();
  }
}

/// The stage rail above the board. It doubles as a progress indicator: the
/// selected stage is filled, and every stage shows how many leads sit in it.
class _StageStrip extends StatelessWidget {
  const _StageStrip({
    required this.stages,
    required this.selected,
    required this.countOf,
    required this.onSelected,
  });

  final List<Stage> stages;
  final int selected;
  final int Function(Stage) countOf;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: OgeraSpacing.screen),
        itemCount: stages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final stage = stages[index];
          final isSelected = index == selected;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? stage.color : OgeraColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isSelected ? stage.color : OgeraColors.line,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : stage.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    stage.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : OgeraColors.ink,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : OgeraColors.canvas,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${countOf(stage)}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : OgeraColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StageColumn extends StatelessWidget {
  const _StageColumn({required this.stage});

  final Stage stage;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FollowupsViewModel>();
    final leads = viewModel.leadsInStage(stage.id);

    if (leads.isEmpty) {
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: EmptyStateView(
          icon: Icons.inbox_outlined,
          title: 'Nothing in ${stage.label}',
          message: 'Leads you move into this stage will appear here.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          12,
          OgeraSpacing.screen,
          96,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: leads.length,
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) =>
            LeadCard(lead: leads[index], stage: stage),
      ),
    );
  }
}

// ----------------------------------------------------------------- lead card

class LeadCard extends StatelessWidget {
  const LeadCard({super.key, required this.lead, this.stage});

  final Lead lead;
  final Stage? stage;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<FollowupsViewModel>();
    final bucket = lead.dueBucket;
    final due = lead.dueDate;

    return OgeraCard(
      accent: stage?.color ?? OgeraColors.line,
      onTap: () =>
          pushShellRoute<void>(context, (_) => LeadDetailScreen(lead: lead)),
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lead.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (due != null)
                StatusChip(
                  label: formatDayMonth(due),
                  color: bucket.color,
                  icon: bucket == DueBucket.overdue
                      ? Icons.error_outline_rounded
                      : Icons.event_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (stage != null)
                StatusChip(
                  label: stage!.label,
                  color: stage!.color,
                  dense: true,
                ),
              if ((lead.panchayath ?? '').isNotEmpty)
                StatusChip(
                  label: lead.panchayath!,
                  icon: Icons.location_city_rounded,
                  dense: true,
                ),
              if (!lead.isQualified)
                StatusChip(
                  label: '${lead.missingQualification.length} details missing',
                  tone: StatusTone.warning,
                  icon: Icons.info_outline_rounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 15,
                      color: OgeraColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        viewModel.assigneeLabel(lead),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: OgeraColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              QuickActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Call ${lead.displayName}',
                onPressed: () => Launchers.call(context, lead.phone),
              ),
              QuickActionButton(
                icon: Icons.chat_rounded,
                tooltip: 'WhatsApp ${lead.displayName}',
                color: const Color(0xFF25D366),
                onPressed: () => Launchers.whatsapp(context, lead.phone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
