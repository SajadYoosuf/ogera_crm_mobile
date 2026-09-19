import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../contacts/contacts_tab.dart';

/// The contacts one staff member added in the Performance date range.
/// [staffId] is a user id, or `unattributed` for records with no creator.
class StaffContactsScreen extends StatefulWidget {
  const StaffContactsScreen({
    super.key,
    required this.staffId,
    required this.name,
    required this.range,
  });

  final String staffId;
  final String name;
  final DateTimeRange range;

  @override
  State<StaffContactsScreen> createState() => _StaffContactsScreenState();
}

class _StaffContactsScreenState extends State<StaffContactsScreen> {
  final _scroll = ScrollController();
  List<Contact> _contacts = const [];
  ContactType? _type;
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _moreFailed = false;
  String? _error;
  FailureKind _failure = FailureKind.server;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<ContactPage> _fetch(int page) {
    return context.read<ContactsService>().list(
      addedBy: widget.staffId,
      type: _type,
      startDate: isoDate(widget.range.start),
      endDate: isoDate(widget.range.end),
      page: page,
    );
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _moreFailed = false;
      _error = null;
    });
    try {
      final result = await _fetch(1);
      if (!mounted) return;
      setState(() {
        _contacts = result.contacts;
        _page = 1;
        _totalPages = result.totalPages;
        _total = result.total;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _failure = error.kind;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _moreFailed || _page >= _totalPages) {
      return;
    }
    setState(() => _isLoadingMore = true);
    try {
      final result = await _fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _contacts = [..._contacts, ...result.contacts];
        _page += 1;
        _isLoadingMore = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      // Keep what is already on screen and offer a retry at the foot of the
      // list, instead of silently stopping.
      setState(() {
        _isLoadingMore = false;
        _moreFailed = true;
        _failure = error.kind;
      });
    }
  }

  void _selectType(ContactType? type) {
    if (type == _type) return;
    _type = type;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          const SizedBox(height: 12),
          FilterChipBar<ContactType?>(
            values: const [null, ContactType.lead, ContactType.awareness],
            labelOf: (type) => type?.label ?? 'All',
            selected: _type,
            onSelected: _selectType,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OgeraSpacing.screen,
              10,
              OgeraSpacing.screen,
              4,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isLoading
                    ? 'Loading…'
                    : (_total == 1 ? '1 contact added' : '$_total contacts added'),
                style: const TextStyle(fontSize: 12, color: OgeraColors.muted),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const LoadingListView(itemHeight: 96);
    if (_error != null) {
      return RefreshableMessage(
        onRefresh: _load,
        child: ErrorStateView(
          message: _error!,
          kind: _failure,
          onRetry: _load,
        ),
      );
    }
    if (_contacts.isEmpty) {
      return RefreshableMessage(
        onRefresh: _load,
        child: const EmptyStateView(
          icon: Icons.contacts_outlined,
          title: 'No contacts',
          message: 'Nothing was added in this date range.',
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          8,
          OgeraSpacing.screen,
          32,
        ),
        itemCount: _contacts.length + (_isLoadingMore || _moreFailed ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) {
          if (index == _contacts.length && _moreFailed) {
            return InlineErrorBanner(
              message: "Couldn't load more contacts.",
              kind: _failure,
              onRetry: () {
                setState(() => _moreFailed = false);
                _loadMore();
              },
            );
          }
          if (index == _contacts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return ContactCard(contact: _contacts[index]);
        },
      ),
    );
  }
}
