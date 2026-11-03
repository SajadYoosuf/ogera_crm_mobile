import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';

/// The contact a new contact was referred by.
/// The backend stores this as referredByContactId on the contact record.
class ReferralChoice {
  const ReferralChoice(this.contact);

  final Contact contact;

  String get label => 'Contact · ${contact.displayName}';
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

  Timer? _debounce;
  bool _isLoading = false;
  String? _error;
  List<Contact> _contacts = const [];

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
      // kind: null searches all contact types (consumer + partner)
      _contacts = await context.read<ContactsService>().search(query);
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: OgeraSearchField(
              controller: _controller,
              hint: 'Search contact name or phone',
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

    if (_contacts.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'Nothing found',
        message: 'Try a different name or phone number.',
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: _contacts.length,
      separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
      itemBuilder: (_, index) {
        final contact = _contacts[index];
        return ListTile(
          onTap: () => Navigator.of(context).pop(ReferralChoice(contact)),
          leading: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: OgeraColors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 19,
              color: OgeraColors.blue,
            ),
          ),
          title: Text(
            contact.displayName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              contact.phone,
              if ((contact.district ?? '').isNotEmpty) contact.district!,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: OgeraColors.muted,
          ),
        );
      },
    );
  }
}
