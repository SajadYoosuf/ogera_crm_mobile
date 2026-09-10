import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/professional.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/professionals_view_model.dart';
import '../../view_models/session_view_model.dart';
import '../shell_screen.dart';
import 'professional_detail_screen.dart';
import '../shell_scope.dart';

/// The referral and service-professional directory: contractors, engineers,
/// plumbers, interior designers, and electricians.
class ProfessionalsTab extends StatefulWidget {
  const ProfessionalsTab({super.key});

  @override
  State<ProfessionalsTab> createState() => _ProfessionalsTabState();
}

class _ProfessionalsTabState extends State<ProfessionalsTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfessionalsViewModel>();

    // `null` is the "All" chip; the endpoint filters one profession at a time,
    // so All fans out and merges.
    final filters = <ProfessionalType?>[null, ...ProfessionalType.values];

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Professionals'),
        actions: [
          PopupMenuButton<ProfessionalSort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: viewModel.sort,
            onSelected: viewModel.setSort,
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: ProfessionalSort.newest,
                child: Text('Newest first'),
              ),
              PopupMenuItem(
                value: ProfessionalSort.name,
                child: Text('Name A–Z'),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
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
              hint: 'Search name, phone, or place',
              onChanged: viewModel.search,
            ),
          ),
          FilterChipBar<ProfessionalType?>(
            values: filters,
            selected: viewModel.type,
            labelOf: (type) => type?.label ?? 'All',
            countOf: (type) => type == null
                ? (viewModel.isLoading ? null : viewModel.total)
                : (viewModel.type == null ? viewModel.countFor(type) : null),
            onSelected: viewModel.selectType,
          ),
          const SizedBox(height: 6),
          const Expanded(child: _ProfessionalsList()),
        ],
      ),
    );
  }
}

class _ProfessionalsList extends StatelessWidget {
  const _ProfessionalsList();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfessionalsViewModel>();

    if (viewModel.isLoading) {
      return const LoadingListView(
        itemCount: 6,
        itemHeight: 88,
      );
    }

    if (viewModel.error != null && viewModel.professionals.isEmpty) {
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: ErrorStateView(
          message: viewModel.error!,
          kind: viewModel.errorKind ?? FailureKind.server,
          onRetry: viewModel.load,
        ),
      );
    }

    if (viewModel.professionals.isEmpty) {
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: _emptyState(context, viewModel),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          6,
          OgeraSpacing.screen,
          96,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: viewModel.professionals.length,
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) =>
            ProfessionalCard(professional: viewModel.professionals[index]),
      ),
    );
  }
}

/// Three different "nothing here" cases, which need different wording and a
/// different way out: a search with no hits, a type chip with no members, and a
/// genuinely empty directory.
Widget _emptyState(BuildContext context, ProfessionalsViewModel viewModel) {
  if (viewModel.query.isNotEmpty) {
    return EmptyStateView(
      icon: Icons.search_off_rounded,
      title: 'No matching professionals',
      message: 'Nothing matches "${viewModel.query}". Try a different name, '
          'phone number, or place.',
    );
  }

  final type = viewModel.type;
  if (type != null) {
    return EmptyStateView(
      icon: type.icon,
      title: 'No ${type.label.toLowerCase()}s yet',
      message: 'Nobody is filed under ${type.label} yet. Add one, or switch to '
          'All to see every profession.',
      actionLabel: 'Add ${type.label.toLowerCase()}',
      onAction: () => openProfessionalForm(context),
    );
  }

  return EmptyStateView(
    icon: Icons.handyman_outlined,
    title: 'No professionals yet',
    message: 'Add the contractors, engineers, and plumbers who refer work to you.',
    actionLabel: 'Add professional',
    onAction: () => openProfessionalForm(context),
  );
}

class ProfessionalCard extends StatelessWidget {
  const ProfessionalCard({super.key, required this.professional});

  final Professional professional;

  @override
  Widget build(BuildContext context) {
    final type = professional.type;
    return OgeraCard(
      accent: type.color,
      onTap: () => pushShellRoute<void>(
        context,
        (_) => ProfessionalDetailScreen(professional: professional),
      ),
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(type.icon, size: 21, color: type.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.displayName,
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
                      professional.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(label: type.label, color: type.color, dense: true),
            ],
          ),
          if (professional.locationSummary != null) ...[
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  professional.hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_city_rounded,
                  size: 14,
                  color: OgeraColors.muted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    professional.locationSummary!,
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
          ],
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              QuickActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Call ${professional.displayName}',
                onPressed: () => Launchers.call(context, professional.phone),
              ),
              QuickActionButton(
                icon: Icons.chat_rounded,
                tooltip: 'WhatsApp ${professional.displayName}',
                color: const Color(0xFF25D366),
                onPressed: () =>
                    Launchers.whatsapp(context, professional.phone),
              ),
              QuickActionButton(
                icon: Icons.directions_rounded,
                tooltip: 'Directions',
                color: OgeraColors.warning,
                onPressed:
                    professional.hasLocation ||
                        (professional.address ?? '').isNotEmpty
                    ? () => Launchers.directions(
                        context,
                        latitude: professional.lat,
                        longitude: professional.lng,
                        address: professional.address ?? professional.place,
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

bool canEditProfessional(BuildContext context, Professional professional) {
  final session = context.read<SessionViewModel>();
  return professional.isEditableBy(
    userId: session.userId,
    isPrivileged: session.isPrivileged,
  );
}
