/// The Contacts tab: one screen for the three contact types.
///
/// Beginner note: this file only draws the screen. The data (which contacts,
/// which page, which filters) lives in [ContactsViewModel]. The screen reads
/// the view model with `context.watch`, so it rebuilds whenever the list changes.
///
/// Layout, top to bottom:
///   1. App bar with the title and a filter button (source and date range).
///   2. Tab bar for Consumer, Partner and Dealer, each with its count.
///   3. Search box (name or phone) and a line listing any active filters.
///   4. A list of minimal cards: name, phone, lead stage, lead source, and
///      Call and WhatsApp buttons. Tap a card for the full details.
///
/// Phone numbers are shown and dialled through `phone_numbers.dart`, so the
/// number on the card is the same number the call and WhatsApp buttons use.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/utils/phone_numbers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import '../shell_scope.dart';
import 'add_contact_sheet.dart';
import 'contact_detail_screen.dart';
import 'contact_filters_sheet.dart';

class ContactsTab extends StatefulWidget {
  const ContactsTab({super.key});

  @override
  State<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<ContactsTab> {
  /// The tabs in order. Each tab maps to one `contact_type` the API knows.
  static const tabKinds = <ContactKind>[
    ContactKind.consumer,
    ContactKind.partner,
    ContactKind.dealer,
  ];

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

  /// Loads the next page when the user is close to the bottom, so a fast scroll
  /// never reaches an empty gap.
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
    final selected = tabKinds.indexOf(viewModel.kind ?? tabKinds.first);

    return DefaultTabController(
      length: tabKinds.length,
      initialIndex: selected < 0 ? 0 : selected,
      child: Scaffold(
        backgroundColor: OgeraColors.canvas,
        appBar: AppBar(
          backgroundColor: OgeraColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text('Contacts'),
          actions: [
            IconButton(
              tooltip: 'Filters',
              onPressed: () => showContactFilters(context),
              icon: Badge(
                isLabelVisible: _hasSourceOrDate(viewModel),
                backgroundColor: OgeraColors.blue,
                child: const Icon(Icons.tune_rounded, color: OgeraColors.ink),
              ),
            ),
          ],
          bottom: TabBar(
            onTap: (index) => viewModel.selectKind(tabKinds[index]),
            labelColor: OgeraColors.blue,
            unselectedLabelColor: OgeraColors.muted,
            indicatorColor: OgeraColors.blue,
            tabs: [
              for (final kind in tabKinds)
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(kind.label),
                      const SizedBox(width: 6),
                      Text(
                        '${viewModel.countFor(kind)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OgeraSpacing.screen,
                12,
                OgeraSpacing.screen,
                8,
              ),
              child: OgeraSearchField(
                controller: _searchController,
                hint: 'Search name or phone',
                onChanged: viewModel.search,
                onClear: () {
                  _searchController.clear();
                  viewModel.search('');
                },
              ),
            ),
            if (_hasSourceOrDate(viewModel))
              _ActiveFilters(viewModel: viewModel),
            Expanded(child: _ContactsList(scrollController: _scrollController)),
          ],
        ),
      ),
    );
  }
}

bool _hasSourceOrDate(ContactsViewModel viewModel) =>
    viewModel.source != null ||
    viewModel.startDate != null ||
    viewModel.endDate != null;

/// One line under the search box that says which filters are on, with a Clear
/// action, so a filtered list never looks like the full list by mistake.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.viewModel});

  final ContactsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (viewModel.source != null)
        'Source: ${CrmOptions.sourceLabel(viewModel.source!)}',
      if (viewModel.startDate != null || viewModel.endDate != null)
        'Added ${_dateText(viewModel.startDate)} to ${_dateText(viewModel.endDate)}',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(OgeraSpacing.screen, 0, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              parts.join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
            ),
          ),
          TextButton(
            onPressed: viewModel.clearFilters,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  /// Turns `2026-10-01` into `01 Oct`, or `…` when the date is not set.
  String _dateText(String? iso) {
    final date = iso == null ? null : DateTime.tryParse(iso);
    return date == null ? '…' : formatDayMonth(date);
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
      final kindName = (viewModel.kind?.label ?? 'contact').toLowerCase();
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: EmptyStateView(
          icon: filtered
              ? Icons.search_off_rounded
              : Icons.people_outline_rounded,
          title: filtered
              ? 'No matching contacts'
              : 'No $kindName contacts yet',
          message: filtered
              ? 'Try a different search, or clear the filters.'
              : 'Add a $kindName contact and it will show up here.',
          actionLabel: filtered ? 'Clear filters' : 'Add contact',
          onAction: filtered
              ? viewModel.clearFilters
              : () => showAddContactSheet(context),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          8,
          OgeraSpacing.screen,
          96,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: viewModel.contacts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
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
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Text(
          total == 1 ? '1 contact' : '$total contacts',
          style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
        ),
      ),
    );
  }
}

/// One contact in the list. It shows only what a field user needs to recognise
/// and reach the person: name, number, stage, source, and the two contact
/// buttons. Everything else is on the detail screen.
class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final phone = parseContactPhone(contact.phone);
    final stage = contact.currentStage;
    final source = contact.leadSource?.name;

    return OgeraCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      onTap: () => _openDetail(context, contact),
      child: Row(
        children: [
          _Monogram(name: contact.name, phone: contact.phone),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: OgeraColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                _PhoneLine(phone: phone, raw: contact.phone),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (stage != null)
                      StatusChip(
                        label: stage.stageName,
                        tone: _stageTone(stage),
                        dense: true,
                      ),
                    if (source != null && source.isNotEmpty)
                      Text(
                        source,
                        style: const TextStyle(
                          fontSize: 12,
                          color: OgeraColors.muted,
                        ),
                      ),
                  ],
                ),
                if (contact.createdByEmployee != null) ...[
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.badge_outlined, size: 14, color: OgeraColors.muted),
                          const SizedBox(width: 5),
                          Text(
                            'Created by ${contact.createdByEmployee!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: OgeraColors.muted),
                          ),
                        ],
                      ),
                      Text(
                        'Branch: ${contact.createdByEmployee!.branch?.isNotEmpty == true ? contact.createdByEmployee!.branch : 'Not available'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: OgeraColors.muted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuickActionButton(
                icon: Icons.call_rounded,
                tooltip: 'Call ${contact.displayName}',
                onPressed: () => Launchers.call(context, contact.phone),
              ),
              QuickActionButton(
                icon: Icons.chat_rounded,
                tooltip: 'WhatsApp ${contact.displayName}',
                color: const Color(0xFF25D366),
                onPressed: () => Launchers.whatsapp(context, contact.phone),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the detail screen. It returns true when the contact was edited or
/// deleted, and then the list reloads so the card is current.
Future<void> _openDetail(BuildContext context, Contact contact) async {
  final changed = await pushShellRoute<bool>(
    context,
    (_) => ContactDetailScreen(contactId: contact.id, initial: contact),
  );
  if (changed == true && context.mounted) {
    context.read<ContactsViewModel>().refresh();
  }
}

/// The number as the card shows it, with its country. Numbers we cannot parse
/// get a visible warning, so a wrong number is spotted before anyone dials it.
class _PhoneLine extends StatelessWidget {
  const _PhoneLine({required this.phone, required this.raw});

  final ContactPhone? phone;
  final String raw;

  @override
  Widget build(BuildContext context) {
    if (phone == null) {
      return Row(
        children: [
          Flexible(
            child: Text(
              raw.isEmpty ? 'No number' : raw,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
            ),
          ),
          const SizedBox(width: 6),
          const StatusChip(
            label: 'Check number',
            tone: StatusTone.warning,
            icon: Icons.warning_amber_rounded,
            dense: true,
          ),
        ],
      );
    }
    return Row(
      children: [
        Flexible(
          child: Text(
            phone!.display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
          ),
        ),
        const SizedBox(width: 6),
        StatusChip(
          label: phone!.isGcc
              ? 'GCC · ${phone!.countryName}'
              : phone!.countryName,
          tone: phone!.isGcc ? StatusTone.info : StatusTone.neutral,
          dense: true,
        ),
      ],
    );
  }
}

/// Colour of the stage chip: won is green, lost is red, aware is blue, and the
/// rest stay neutral brand green. Status is never colour alone; the label is
/// always shown too.
StatusTone _stageTone(LeadStageInfo stage) {
  if (stage.isLost) return StatusTone.danger;
  final slug = stage.stageSlug;
  if (slug.contains('won') || slug.contains('closed')) {
    return StatusTone.success;
  }
  if (stage.isAware) return StatusTone.info;
  return StatusTone.brand;
}

/// Round monogram with the contact's initials.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.name, required this.phone});

  final String? name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: OgeraColors.blueSoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(name, fallback: phone),
        style: const TextStyle(
          color: OgeraColors.forest,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
