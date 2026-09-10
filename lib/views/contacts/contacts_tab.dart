import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import '../../view_models/session_view_model.dart';
import '../shell_screen.dart';
import 'contact_detail_screen.dart';
import 'contact_filters_sheet.dart';
import '../shell_scope.dart';

/// Contacts list: search, Leads / Awareness tabs with counts, filters, paging,
/// and per-row call / WhatsApp / directions.
class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the next page once the user is within a screen of the bottom, so a
  /// fast scroll never hits an empty gap.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<ContactsViewModel>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ContactsViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => showContactFilters(context),
            icon: Badge(
              isLabelVisible:
                  viewModel.source != null ||
                  viewModel.startDate != null ||
                  viewModel.endDate != null,
              backgroundColor: OgeraColors.blue,
              child: const Icon(Icons.tune_rounded),
            ),
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
              hint: 'Search name or phone',
              onChanged: viewModel.search,
            ),
          ),
          FilterChipBar<ContactType>(
            values: ContactType.values,
            selected: viewModel.type,
            labelOf: (type) => type == ContactType.lead ? 'Leads' : 'Awareness',
            countOf: viewModel.countFor,
            onSelected: viewModel.selectType,
          ),
          const SizedBox(height: 6),
          Expanded(child: _ContactsList(scrollController: _scrollController)),
        ],
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ContactsViewModel>();

    if (viewModel.isLoading) return const LoadingListView();

    if (viewModel.error != null && viewModel.contacts.isEmpty) {
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: ErrorStateView(
          message: viewModel.error!,
          onRetry: viewModel.load,
        ),
      );
    }

    if (viewModel.contacts.isEmpty) {
      final filtered = viewModel.hasFilters;
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: EmptyStateView(
          icon: filtered
              ? Icons.search_off_rounded
              : Icons.people_outline_rounded,
          title: filtered ? 'No matching contacts' : 'No contacts yet',
          message: filtered
              ? 'Try a different search, or clear the filters to see everything.'
              : 'Add your first contact and it will show up here.',
          actionLabel: filtered ? 'Clear filters' : 'Add contact',
          onAction: filtered
              ? viewModel.clearFilters
              : () => openContactForm(context),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          6,
          OgeraSpacing.screen,
          96,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: viewModel.contacts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) {
          if (index == viewModel.contacts.length) {
            return _ListFooter(
              isLoadingMore: viewModel.isLoadingMore,
              hasMore: viewModel.hasMore,
              total: viewModel.total,
            );
          }
          return ContactCard(contact: viewModel.contacts[index]);
        },
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.isLoadingMore,
    required this.hasMore,
    required this.total,
  });

  final bool isLoadingMore;
  final bool hasMore;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
        ),
      );
    }
    if (hasMore) return const SizedBox(height: 24);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Center(
        child: Text(
          total == 1 ? '1 contact' : '$total contacts',
          style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
        ),
      ),
    );
  }
}

/// One contact row. Everything a field user acts on is reachable without
/// opening the record: call, WhatsApp, and directions.
class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final isLead = contact.contactType == ContactType.lead;
    final location = [
      contact.panchayath,
      contact.district,
    ].where((part) => (part ?? '').isNotEmpty).join(', ');

    return OgeraCard(
      onTap: () => pushShellRoute<void>(
        context,
        (_) => ContactDetailScreen(contactId: contact.id, initial: contact),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OgeraAvatar(
                name: contact.name,
                phone: contact.phone,
                color: isLead ? OgeraColors.blue : OgeraColors.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
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
                      contact.phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: isLead ? 'Lead' : 'Awareness',
                tone: isLead ? StatusTone.brand : StatusTone.info,
                dense: true,
              ),
            ],
          ),
          if (location.isNotEmpty || contact.hasLocation) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  contact.hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_city_rounded,
                  size: 14,
                  color: OgeraColors.muted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    location.isEmpty ? 'GPS location saved' : location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: OgeraColors.muted,
                    ),
                  ),
                ),
                Text(
                  formatRelative(contact.createdAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: OgeraColors.muted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 4),
          Row(
            children: [
              if (contact.isCampaignTarget)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: StatusChip(
                    label: 'Campaign',
                    tone: StatusTone.warning,
                    icon: Icons.campaign_rounded,
                    dense: true,
                  ),
                ),
              if (contact.referralSummary != null)
                Expanded(
                  child: Text(
                    contact.referralSummary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: OgeraColors.muted,
                    ),
                  ),
                )
              else
                const Spacer(),
              ContactQuickActions(contact: contact),
            ],
          ),
        ],
      ),
    );
  }
}

class ContactQuickActions extends StatelessWidget {
  const ContactQuickActions({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuickActionButton(
          icon: Icons.call_rounded,
          tooltip: 'Call ${contact.displayName}',
          onPressed: () => Launchers.call(
            context,
            contact.phone,
            countryCode: contact.countryCode,
          ),
        ),
        QuickActionButton(
          icon: Icons.chat_rounded,
          tooltip: 'WhatsApp ${contact.displayName}',
          color: const Color(0xFF25D366),
          onPressed: () => Launchers.whatsapp(
            context,
            contact.phone,
            countryCode: contact.countryCode,
          ),
        ),
        QuickActionButton(
          icon: Icons.directions_rounded,
          tooltip: 'Directions',
          color: OgeraColors.warning,
          onPressed: contact.hasLocation || (contact.address ?? '').isNotEmpty
              ? () => Launchers.directions(
                  context,
                  latitude: contact.lat,
                  longitude: contact.lng,
                  address: contact.address,
                )
              : null,
        ),
      ],
    );
  }
}

/// Read by the detail and form screens to decide whether the edit and delete
/// actions exist at all — a staff member never sees a control they cannot use.
bool canEditContact(BuildContext context, Contact contact) {
  final session = context.read<SessionViewModel>();
  return contact.isEditableBy(
    userId: session.userId,
    isPrivileged: session.isPrivileged,
  );
}
