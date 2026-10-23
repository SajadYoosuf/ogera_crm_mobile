/// Pipeline tab — contacts bucketed by stage for each of the three contact
/// types (Consumer, Partner, Dealer).
///
/// ## Layout
/// 1. AppBar "Pipeline" with a search icon.
/// 2. Contact-type chips: Consumer · Partner · Dealer.
///    Switching triggers a full reload for that type's stages and contacts.
/// 3. Stage strip: horizontally scrollable chips from `GET /pipeline/stages`.
///    Each chip shows the stage name and how many contacts sit in it.
///    "All" chip at the start shows every contact.
///    Tapping the same chip twice returns to "All".
/// 4. Contact list: PipelineLeadCard rows, pull to refresh.
///
/// ## No add button
/// The pipeline is a stage-view of existing contacts. New contacts are added
/// from the Contacts tab or the shell FAB. This tab has no FAB intentionally.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/state_views.dart';
import '../../services/pipeline_service.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/pipeline_view_model.dart';
import 'pipeline_lead_card.dart';

class PipelineTab extends StatefulWidget {
  const PipelineTab({super.key});

  @override
  State<PipelineTab> createState() => _PipelineTabState();
}

class _PipelineTabState extends State<PipelineTab> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PipelineViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: _searchOpen
            ? _InlineSearch(
                controller: _searchController,
                onChanged: () => setState(() {}),
                onClose: () {
                  setState(() => _searchOpen = false);
                  _searchController.clear();
                },
              )
            : const Text('Pipeline'),
        actions: [
          if (!_searchOpen)
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Search',
              onPressed: () => setState(() => _searchOpen = true),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── contact-type selector ─────────────────────────────────────────
          _ContactTypeBar(
            selected: vm.activeType,
            onSelect: vm.setContactType,
          ),

          // ── stage strip ───────────────────────────────────────────────────
          if (!vm.isLoading && vm.error == null && vm.stages.isNotEmpty)
            _StageStrip(
              stages: vm.stages,
              selected: vm.selectedStage,
              countOf: vm.countInStage,
              totalCount: vm.totalCount,
              onSelect: vm.selectStage,
            ),

          // ── contact list ──────────────────────────────────────────────────
          Expanded(
            child: _ContactList(
              vm: vm,
              searchQuery: _searchController.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── contact-type bar ────────────────────────────────────────────────────────

class _ContactTypeBar extends StatelessWidget {
  const _ContactTypeBar({required this.selected, required this.onSelect});

  final PipelineContactType selected;
  final Future<void> Function(PipelineContactType) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OgeraColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: OgeraSpacing.screen,
        vertical: 10,
      ),
      child: Row(
        children: [
          for (final type in PipelineContactType.values) ...[
            if (type != PipelineContactType.values.first)
              const SizedBox(width: 8),
            _TypeChip(
              label: type.label,
              selected: type == selected,
              onTap: () => onSelect(type),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? OgeraColors.blue : OgeraColors.canvas,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? OgeraColors.blue : OgeraColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : OgeraColors.ink,
          ),
        ),
      ),
    );
  }
}

// ─── stage strip ─────────────────────────────────────────────────────────────

class _StageStrip extends StatelessWidget {
  const _StageStrip({
    required this.stages,
    required this.selected,
    required this.countOf,
    required this.totalCount,
    required this.onSelect,
  });

  final List<PipelineStageModel> stages;
  final PipelineStageModel? selected;
  final int Function(PipelineStageModel) countOf;
  final int totalCount;
  final void Function(PipelineStageModel?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          6,
          OgeraSpacing.screen,
          0,
        ),
        children: [
          _StageChip(
            label: 'All',
            count: totalCount,
            color: OgeraColors.blue,
            isSelected: selected == null,
            onTap: () => onSelect(null),
          ),
          ...stages.map((stage) {
            final isSelected = selected?.slug == stage.slug;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _StageChip(
                label: stage.label,
                count: countOf(stage),
                color: _stageColor(stage.slug, stage.orderIndex),
                isSelected: isSelected,
                onTap: () => onSelect(stage),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Color _stageColor(String slug, int orderIndex) {
    final key = slug.toLowerCase();
    if (key.contains('won') || key.contains('closed')) {
      return OgeraColors.success;
    }
    if (key.contains('lost')) return OgeraColors.danger;
    if (key.contains('not_interest')) return const Color(0xFF9CA3AF);
    const ramp = [
      OgeraColors.blue,
      Color(0xFF6366F1),
      Color(0xFF0891B2),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
    ];
    return ramp[orderIndex.abs() % ramp.length];
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : OgeraColors.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: isSelected ? color : OgeraColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : OgeraColors.ink,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.22)
                    : OgeraColors.canvas,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count',
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
  }
}

// ─── contact list ─────────────────────────────────────────────────────────────

class _ContactList extends StatelessWidget {
  const _ContactList({required this.vm, required this.searchQuery});

  final PipelineViewModel vm;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) {
      return const LoadingListView(itemHeight: 108);
    }

    if (vm.error != null) {
      return ErrorStateView(message: vm.error!, onRetry: vm.load);
    }

    final contacts = vm.visibleContacts.where((c) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return c.displayName.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    final stageOrder = {for (final s in vm.stages) s.slug: s.orderIndex};

    if (contacts.isEmpty) {
      return RefreshableMessage(
        onRefresh: vm.load,
        child: EmptyStateView(
          icon: Icons.people_outline_rounded,
          title: vm.stages.isEmpty
              ? 'No pipeline stages'
              : vm.selectedStage != null
              ? 'No contacts in ${vm.selectedStage!.label}'
              : 'No ${vm.activeType.label.toLowerCase()} contacts yet',
          message: vm.stages.isEmpty
              ? 'Pipeline stages are configured by the admin.'
              : vm.selectedStage != null
              ? 'Contacts you move into this stage will appear here.'
              : '${vm.activeType.label} contacts will show here once added.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: vm.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          12,
          OgeraSpacing.screen,
          96,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: contacts.length,
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return PipelineLeadCard(
            contact: contact,
            stageOrderIndex: stageOrder[contact.stageSlug] ?? 0,
          );
        },
      ),
    );
  }
}

// ─── inline search ────────────────────────────────────────────────────────────

class _InlineSearch extends StatelessWidget {
  const _InlineSearch({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: 'Search by name or phone',
        border: InputBorder.none,
        hintStyle: const TextStyle(color: OgeraColors.muted),
        suffixIcon: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onClose,
        ),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
