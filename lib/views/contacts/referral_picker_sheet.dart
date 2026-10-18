import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../models/professional.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';

/// The two referral paths a contact can be created from.
enum ReferralSource {
  contact('Existing contact', Icons.person_rounded),
  professional('Professional', Icons.handyman_rounded);

  const ReferralSource(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// What the picker hands back. Only one of the two is ever populated, because
/// the paths are mutually exclusive.
class ReferralChoice {
  const ReferralChoice.contact(this.contact)
    : professional = null,
      source = ReferralSource.contact;
  const ReferralChoice.professional(this.professional)
    : contact = null,
      source = ReferralSource.professional;

  final ReferralSource source;
  final Contact? contact;
  final Professional? professional;

  String get label => switch (source) {
    ReferralSource.contact => 'Contact · ${contact!.displayName}',
    ReferralSource.professional =>
      '${professional!.type.label} · ${professional!.displayName}',
  };
}

Future<ReferralChoice?> showReferralPicker(BuildContext context) {
  return showModalBottomSheet<ReferralChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ReferralPickerSheet(),
  );
}

class _ReferralPickerSheet extends StatefulWidget {
  const _ReferralPickerSheet();

  @override
  State<_ReferralPickerSheet> createState() => _ReferralPickerSheetState();
}

class _ReferralPickerSheetState extends State<_ReferralPickerSheet> {
  final _controller = TextEditingController();

  ReferralSource _source = ReferralSource.contact;

  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  List<Contact> _contacts = const [];
  List<Professional> _professionals = const [];

  List<ReferralSource> get _sources => ReferralSource.values;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(value.trim()),
    );
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      switch (_source) {
        case ReferralSource.contact:
          _contacts = await context.read<ContactsService>().search(query);
        case ReferralSource.professional:
          _professionals = await context.read<ProfessionalsService>().list(
            query: query.isEmpty ? null : query,
          );
      }
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _switchSource(ReferralSource source) {
    if (_source == source) return;
    setState(() => _source = source);
    _search(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Referred by',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          FilterChipBar<ReferralSource>(
            values: _sources,
            selected: _source,
            labelOf: (source) => source.label,
            onSelected: _switchSource,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: OgeraSearchField(
              controller: _controller,
              hint: switch (_source) {
                ReferralSource.contact => 'Search contact name or phone',
                ReferralSource.professional => 'Search name, phone, or place',
              },
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(child: _results(scrollController)),
        ],
      ),
    );
  }

  Widget _results(ScrollController controller) {
    if (_isLoading) return const LoadingListView(itemCount: 4, itemHeight: 64);
    if (_error != null) {
      return ErrorStateView(
        message: _error!,
        onRetry: () => _search(_controller.text.trim()),
      );
    }

    final tiles = switch (_source) {
      ReferralSource.contact =>
        _contacts
            .map(
              (contact) => _tile(
                title: contact.displayName,
                subtitle: [
                  contact.phone,
                  if ((contact.panchayath ?? '').isNotEmpty)
                    contact.panchayath!,
                ].join(' · '),
                icon: Icons.person_rounded,
                onTap: () =>
                    Navigator.of(context).pop(ReferralChoice.contact(contact)),
              ),
            )
            .toList(),
      ReferralSource.professional =>
        _professionals
            .map(
              (professional) => _tile(
                title: professional.displayName,
                subtitle: [
                  professional.type.label,
                  professional.phone,
                  if (professional.locationSummary != null)
                    professional.locationSummary!,
                ].join(' · '),
                icon: professional.type.icon,
                color: professional.type.color,
                onTap: () => Navigator.of(
                  context,
                ).pop(ReferralChoice.professional(professional)),
              ),
            )
            .toList(),
    };

    if (tiles.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        message: 'Try a different name or phone number.',
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: tiles.length,
      separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
      itemBuilder: (_, index) => tiles[index],
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color color = OgeraColors.blue,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: OgeraColors.muted,
      ),
    );
  }
}
