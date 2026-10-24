// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../../core/utils/formatters.dart';
// import '../../core/utils/launchers.dart';
// import '../../core/widgets/ogera_widgets.dart';
// import '../../core/widgets/state_views.dart';
// import '../../models/contact.dart';
// import '../../theme/ogera_colors.dart';
// import '../../view_models/contacts_view_model.dart';
// import '../../view_models/session_view_model.dart';
// import '../shell_screen.dart';
// import 'contact_detail_screen.dart';
// import 'contact_filters_sheet.dart';
// import '../shell_scope.dart';

// /// The Contacts tab, laid out like the web Contacts page.
// ///
// /// Top to bottom: the app bar with the filters button, a white toolbar holding
// /// the type tabs (All Contacts · Consumer · Partner · Dealer, each with its
// /// count) and the search box, then the list of cards. Paging loads the next
// /// page as the user nears the bottom.
// ///
// /// The Add contact button is the shell's centre action, so this screen has no
// /// button of its own. Colours come from [_Web], which copies the web page, so
// /// both apps look the same.
// class ContactsTab extends StatefulWidget {
//   const ContactsTab({super.key});

//   @override
//   State<ContactsTab> createState() => _ContactsTabState();
// }

// class _ContactsTabState extends State<ContactsTab> {
//   final _searchController = TextEditingController();
//   final _scrollController = ScrollController();

//   @override
//   void initState() {
//     super.initState();
//     _scrollController.addListener(_onScroll);
//   }

//   @override
//   void dispose() {
//     _scrollController
//       ..removeListener(_onScroll)
//       ..dispose();
//     _searchController.dispose();
//     super.dispose();
//   }

//   /// Loads the next page once the user is within a screen of the bottom, so a
//   /// fast scroll never hits an empty gap.
//   void _onScroll() {
//     if (!_scrollController.hasClients) return;
//     final position = _scrollController.position;
//     if (position.pixels >= position.maxScrollExtent - 400) {
//       context.read<ContactsViewModel>().loadMore();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final viewModel = context.watch<ContactsViewModel>();

//     return Scaffold(
//       backgroundColor: _Web.canvas,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         surfaceTintColor: Colors.transparent,
//         elevation: 0,
//         title: const Text(
//           'Contacts',
//           style: TextStyle(
//             fontSize: 20,
//             fontWeight: FontWeight.w700,
//             letterSpacing: -0.2,
//             color: _Web.ink,
//           ),
//         ),
//         actions: [
//           IconButton(
//             tooltip: 'Filters',
//             onPressed: () => showContactFilters(context),
//             icon: Badge(
//               isLabelVisible:
//                   viewModel.source != null ||
//                   viewModel.startDate != null ||
//                   viewModel.endDate != null,
//               backgroundColor: OgeraColors.blue,
//               child: const Icon(Icons.tune_rounded, color: _Web.ink),
//             ),
//           ),
//           const SizedBox(width: 4),
//         ],
//       ),
//       body: Column(
//         children: [
//           _Toolbar(
//             searchController: _searchController,
//             onSearch: viewModel.search,
//             selected: viewModel.kind,
//             countOf: viewModel.countFor,
//             onSelected: viewModel.selectKind,
//           ),
//           Expanded(child: _ContactsList(scrollController: _scrollController)),
//         ],
//       ),
//     );
//   }
// }

// /// Colours and shadows copied from the web Contacts page (`ContactsView.tsx`).
// /// Keep them here so the mobile screen matches the web without touching the
// /// shared app theme.
// class _Web {
//   const _Web._();

//   static const canvas = Color(0xFFF4FBF7);
//   static const border = Color(0xFFE7E7EA);
//   static const divider = Color(0xFFEFEFF2);
//   static const tabTrack = Color(0xFFF3F3F5);
//   static const ink = Color(0xFF1A1C21);
//   static const body = Color(0xFF6B7080);
//   static const faint = Color(0xFF8A8F9C);
//   static const accent = Color(0xFF0E4D3A);

//   static const tabShadow = [
//     BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
//   ];

//   /// Pastel monogram colours, picked by contact id so a contact keeps its tone.
//   static const avatarTones = [
//     (bg: Color(0xFFE7F5EE), fg: Color(0xFF0E4D3A)),
//     (bg: Color(0xFFE0F2FE), fg: Color(0xFF0B6AA8)),
//     (bg: Color(0xFFDCFCE7), fg: Color(0xFF167A44)),
//     (bg: Color(0xFFFEF3C7), fg: Color(0xFF9A6200)),
//     (bg: Color(0xFFFCE7F3), fg: Color(0xFFA8326E)),
//   ];
// }

// /// The colours of a contact type badge, as the web table shows them.
// ({Color bg, Color fg}) _kindTone(ContactKind kind) => switch (kind) {
//   ContactKind.consumer => (
//     bg: const Color(0xFFEEF4FF),
//     fg: const Color(0xFF1D5BBF),
//   ),
//   ContactKind.partner => (
//     bg: const Color(0xFFE7F5EE),
//     fg: const Color(0xFF0E4D3A),
//   ),
//   ContactKind.dealer => (
//     bg: const Color(0xFFFFF3E0),
//     fg: const Color(0xFFC45C00),
//   ),
// };

// /// White strip under the app bar: the type tabs, then the search box.
// class _Toolbar extends StatelessWidget {
//   const _Toolbar({
//     required this.searchController,
//     required this.onSearch,
//     required this.selected,
//     required this.countOf,
//     required this.onSelected,
//   });

//   final TextEditingController searchController;
//   final ValueChanged<String> onSearch;
//   final ContactKind? selected;
//   final int Function(ContactKind?) countOf;
//   final ValueChanged<ContactKind?> onSelected;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(bottom: BorderSide(color: _Web.border)),
//       ),
//       padding: const EdgeInsets.fromLTRB(
//         OgeraSpacing.screen,
//         12,
//         OgeraSpacing.screen,
//         12,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         children: [
//           _TypeTabs(
//             selected: selected,
//             countOf: countOf,
//             onSelected: onSelected,
//           ),
//           const SizedBox(height: 12),
//           OgeraSearchField(
//             controller: searchController,
//             hint: 'Search name or phone',
//             onChanged: onSearch,
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// The segmented tab row: a grey track with the selected tab in white, the
// /// same look as the web tabs. It scrolls sideways on narrow phones.
// class _TypeTabs extends StatelessWidget {
//   const _TypeTabs({
//     required this.selected,
//     required this.countOf,
//     required this.onSelected,
//   });

//   final ContactKind? selected;
//   final int Function(ContactKind?) countOf;
//   final ValueChanged<ContactKind?> onSelected;

//   /// The tabs in web order. `null` is "All Contacts".
//   static const _tabs = <ContactKind?>[
//     null,
//     ContactKind.consumer,
//     ContactKind.partner,
//     ContactKind.dealer,
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: Container(
//         padding: const EdgeInsets.all(2),
//         decoration: BoxDecoration(
//           color: _Web.tabTrack,
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             for (final kind in _tabs)
//               _TypeTab(
//                 label: kind?.label ?? 'All Contacts',
//                 count: countOf(kind),
//                 selected: kind == selected,
//                 onTap: () => onSelected(kind),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// /// One tab: its label and count. The count turns green when the tab is active.
// class _TypeTab extends StatelessWidget {
//   const _TypeTab({
//     required this.label,
//     required this.count,
//     required this.selected,
//     required this.onTap,
//   });

//   final String label;
//   final int count;
//   final bool selected;
//   final VoidCallback onTap;

//   @override
//   Widget build(BuildContext context) {
//     return Semantics(
//       button: true,
//       selected: selected,
//       child: GestureDetector(
//         onTap: onTap,
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 160),
//           height: 40,
//           padding: const EdgeInsets.symmetric(horizontal: 12),
//           alignment: Alignment.center,
//           decoration: BoxDecoration(
//             color: selected ? Colors.white : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//             boxShadow: selected ? _Web.tabShadow : null,
//           ),
//           child: Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 13.5,
//                   fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
//                   color: selected ? _Web.ink : _Web.body,
//                 ),
//               ),
//               const SizedBox(width: 6),
//               Text(
//                 '$count',
//                 style: TextStyle(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w500,
//                   color: selected ? _Web.accent : _Web.faint,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _ContactsList extends StatelessWidget {
//   const _ContactsList({required this.scrollController});

//   final ScrollController scrollController;

//   @override
//   Widget build(BuildContext context) {
//     final viewModel = context.watch<ContactsViewModel>();

//     if (viewModel.isLoading) return const LoadingListView();

//     if (viewModel.error != null && viewModel.contacts.isEmpty) {
//       return RefreshableMessage(
//         onRefresh: viewModel.refresh,
//         child: ErrorStateView(
//           message: viewModel.error!,
//           onRetry: viewModel.load,
//         ),
//       );
//     }

//     if (viewModel.contacts.isEmpty) {
//       final filtered = viewModel.hasFilters;
//       return RefreshableMessage(
//         onRefresh: viewModel.refresh,
//         child: EmptyStateView(
//           icon: filtered
//               ? Icons.search_off_rounded
//               : Icons.people_outline_rounded,
//           title: filtered
//               ? 'No matching contacts'
//               : _emptyTitle(viewModel.kind),
//           message: filtered
//               ? 'Try a different search, or clear the filters to see everything.'
//               : 'Add your first ${_emptyNoun(viewModel.kind)} and it will show up here.',
//           actionLabel: filtered ? 'Clear filters' : 'Add contact',
//           onAction: filtered
//               ? viewModel.clearFilters
//               : () => openContactForm(context),
//         ),
//       );
//     }

//     return RefreshIndicator(
//       onRefresh: viewModel.refresh,
//       child: ListView.separated(
//         controller: scrollController,
//         padding: const EdgeInsets.fromLTRB(
//           OgeraSpacing.screen,
//           14,
//           OgeraSpacing.screen,
//           96,
//         ),
//         physics: const AlwaysScrollableScrollPhysics(),
//         itemCount: viewModel.contacts.length + 1,
//         separatorBuilder: (_, _) => const SizedBox(height: 10),
//         itemBuilder: (context, index) {
//           if (index == viewModel.contacts.length) {
//             return _ListFooter(
//               isLoadingMore: viewModel.isLoadingMore,
//               hasMore: viewModel.hasMore,
//               total: viewModel.total,
//             );
//           }
//           return ContactCard(contact: viewModel.contacts[index]);
//         },
//       ),
//     );
//   }
// }

// /// Empty-state wording for the active tab: "No partner contacts yet" or, on
// /// the All tab, "No contacts yet".
// String _emptyTitle(ContactKind? kind) => kind == null
//     ? 'No contacts yet'
//     : 'No ${kind.label.toLowerCase()} contacts yet';

// /// The noun used in the empty-state sentence, e.g. "dealer contact".
// String _emptyNoun(ContactKind? kind) =>
//     kind == null ? 'contact' : '${kind.label.toLowerCase()} contact';

// class _ListFooter extends StatelessWidget {
//   const _ListFooter({
//     required this.isLoadingMore,
//     required this.hasMore,
//     required this.total,
//   });

//   final bool isLoadingMore;
//   final bool hasMore;
//   final int total;

//   @override
//   Widget build(BuildContext context) {
//     if (isLoadingMore) {
//       return const Padding(
//         padding: EdgeInsets.symmetric(vertical: 22),
//         child: Center(
//           child: SizedBox(
//             width: 22,
//             height: 22,
//             child: CircularProgressIndicator(strokeWidth: 2.4),
//           ),
//         ),
//       );
//     }
//     if (hasMore) return const SizedBox(height: 24);
//     return Padding(
//       padding: const EdgeInsets.only(top: 20),
//       child: Center(
//         child: Text(
//           total == 1 ? '1 contact' : '$total contacts',
//           style: const TextStyle(fontSize: 12.5, color: _Web.body),
//         ),
//       ),
//     );
//   }
// }

// /// One contact card, built like a row of the web list: monogram, name and
// /// phone, type and verified badges, location, source and date. Call, WhatsApp
// /// and directions stay on the card, so a field user never has to open it.
// class ContactCard extends StatelessWidget {
//   const ContactCard({super.key, required this.contact});

//   final Contact contact;

//   @override
//   Widget build(BuildContext context) {
//     final location = [
//       contact.panchayath,
//       contact.district,
//     ].where((part) => (part ?? '').isNotEmpty).join(', ');
//     final tone = _kindTone(contact.kind);

//     return Material(
//       color: Colors.white,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(14),
//         side: const BorderSide(color: _Web.border),
//       ),
//       clipBehavior: Clip.antiAlias,
//       child: InkWell(
//         onTap: () => pushShellRoute<void>(
//           context,
//           (_) => ContactDetailScreen(contactId: contact.id, initial: contact),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   _Monogram(
//                     name: contact.name,
//                     phone: contact.phone,
//                     tone:
//                         _Web.avatarTones[contact.id % _Web.avatarTones.length],
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           contact.displayName,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                           style: const TextStyle(
//                             fontSize: 15,
//                             fontWeight: FontWeight.w600,
//                             color: _Web.ink,
//                           ),
//                         ),
//                         const SizedBox(height: 2),
//                         Text(
//                           contact.phone,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w500,
//                             color: _Web.body,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               Wrap(
//                 spacing: 6,
//                 runSpacing: 6,
//                 children: [
//                   _Badge(label: contact.kind.label, bg: tone.bg, fg: tone.fg),
//                   _VerifiedBadge(verified: contact.isVerified),
//                 ],
//               ),
//               if (!contact.isVerified && contact.missingFields.isNotEmpty) ...[
//                 const SizedBox(height: 6),
//                 Text(
//                   'Still needed: ${contact.missingFields.map(humanizeSlug).join(', ')}',
//                   style: const TextStyle(
//                     fontSize: 11.5,
//                     color: Color(0xFF9A5B00),
//                   ),
//                 ),
//               ],
//               const SizedBox(height: 10),
//               _InfoLine(
//                 icon: contact.hasLocation
//                     ? Icons.location_on_rounded
//                     : Icons.location_city_rounded,
//                 text: location.isEmpty
//                     ? (contact.hasLocation
//                           ? 'GPS location saved'
//                           : 'Location not added')
//                     : location,
//               ),
//               if (contact.source != null) ...[
//                 const SizedBox(height: 4),
//                 _InfoLine(
//                   icon: Icons.campaign_outlined,
//                   text: humanizeSlug(contact.source!),
//                 ),
//               ],
//               if (contact.referralSummary != null) ...[
//                 const SizedBox(height: 4),
//                 _InfoLine(
//                   icon: Icons.handshake_outlined,
//                   text: contact.referralSummary!,
//                 ),
//               ],
//               const SizedBox(height: 8),
//               const Divider(height: 1, color: _Web.divider),
//               const SizedBox(height: 4),
//               Row(
//                 children: [
//                   Text(
//                     formatFullDate(contact.createdAt),
//                     style: const TextStyle(
//                       fontSize: 11.5,
//                       fontWeight: FontWeight.w500,
//                       color: _Web.faint,
//                     ),
//                   ),
//                   if (contact.isCampaignTarget) ...[
//                     const SizedBox(width: 8),
//                     const StatusChip(
//                       label: 'Campaign',
//                       tone: StatusTone.warning,
//                       icon: Icons.campaign_rounded,
//                       dense: true,
//                     ),
//                   ],
//                   const Spacer(),
//                   ContactQuickActions(contact: contact),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Round monogram in one of the web's pastel tones.
// class _Monogram extends StatelessWidget {
//   const _Monogram({
//     required this.name,
//     required this.phone,
//     required this.tone,
//   });

//   final String? name;
//   final String phone;
//   final ({Color bg, Color fg}) tone;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 40,
//       height: 40,
//       alignment: Alignment.center,
//       decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
//       child: Text(
//         initialsOf(name, fallback: phone),
//         style: TextStyle(
//           color: tone.fg,
//           fontSize: 14,
//           fontWeight: FontWeight.w700,
//         ),
//       ),
//     );
//   }
// }

// /// A small rounded label, used for the contact type.
// class _Badge extends StatelessWidget {
//   const _Badge({required this.label, required this.bg, required this.fg});

//   final String label;
//   final Color bg;
//   final Color fg;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
//       ),
//     );
//   }
// }

// /// Verified or Unverified, with a coloured dot. Status is only these two (rule 2).
// class _VerifiedBadge extends StatelessWidget {
//   const _VerifiedBadge({required this.verified});

//   final bool verified;

//   @override
//   Widget build(BuildContext context) {
//     final bg = verified ? const Color(0xFFEAF8EF) : const Color(0xFFFFF7E6);
//     final fg = verified ? const Color(0xFF17703F) : const Color(0xFF9A5B00);
//     final dot = verified ? const Color(0xFF2DB565) : const Color(0xFFE59A1A);
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//       decoration: BoxDecoration(
//         color: bg,
//         borderRadius: BorderRadius.circular(999),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 6,
//             height: 6,
//             decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
//           ),
//           const SizedBox(width: 6),
//           Text(
//             verified ? 'Verified' : 'Unverified',
//             style: TextStyle(
//               color: fg,
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// One grey line with an icon, such as the district or the lead source.
// class _InfoLine extends StatelessWidget {
//   const _InfoLine({required this.icon, required this.text});

//   final IconData icon;
//   final String text;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Icon(icon, size: 14, color: _Web.faint),
//         const SizedBox(width: 6),
//         Expanded(
//           child: Text(
//             text,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: const TextStyle(fontSize: 12.5, color: _Web.body),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class ContactQuickActions extends StatelessWidget {
//   const ContactQuickActions({super.key, required this.contact});

//   final Contact contact;

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         QuickActionButton(
//           icon: Icons.call_rounded,
//           tooltip: 'Call ${contact.displayName}',
//           onPressed: () => Launchers.call(
//             context,
//             contact.phone,
//             countryCode: contact.countryCode,
//           ),
//         ),
//         QuickActionButton(
//           icon: Icons.chat_rounded,
//           tooltip: 'WhatsApp ${contact.displayName}',
//           color: const Color(0xFF25D366),
//           onPressed: () => Launchers.whatsapp(
//             context,
//             contact.phone,
//             countryCode: contact.countryCode,
//           ),
//         ),
//         QuickActionButton(
//           icon: Icons.directions_rounded,
//           tooltip: 'Directions',
//           color: OgeraColors.warning,
//           onPressed: contact.hasLocation || (contact.address ?? '').isNotEmpty
//               ? () => Launchers.directions(
//                   context,
//                   latitude: contact.lat,
//                   longitude: contact.lng,
//                   address: contact.address,
//                 )
//               : null,
//         ),
//       ],
//     );
//   }
// }

// /// Read by the detail and form screens to decide whether the edit and delete
// /// actions exist at all — a staff member never sees a control they cannot use.
// bool canEditContact(BuildContext context, Contact contact) {
//   final session = context.read<SessionViewModel>();
//   return contact.isEditableBy(
//     userId: session.userId,
//     isPrivileged: session.isPrivileged,
//   );
// }

// ---------------------------------------------------------------------------
// Placeholder — full implementation is commented out above pending redesign.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

/// Placeholder for the full ContactsTab (commented out above).
class ContactsTab extends StatelessWidget {
  const ContactsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Contacts — coming soon'));
  }
}
