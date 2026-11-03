// sales_tab.dart
//
// The Sales tab — a searchable, filterable list of past sale records.
//
// WHAT IT SHOWS:
//   - A search field (name, phone, address or product) in the body.
//   - A list of sale cards, newest first.
//   - Tapping a card opens the edit form (admin/manager only see Edit option).
//   - A "+" icon button in the AppBar and a FAB to create a new sale
//     (both shown only to admins and managers).
//
// DATA FLOW:
//   SalesTab → SalesViewModel → SalesService → GET /sales
//
// OFFLINE:
//   When offline, the last cached list is shown with a banner.
//   Any pending (queued) writes are replayed on the next successful load.

library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/sale.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';
import '../../view_models/session_view_model.dart';
import 'sale_form_screen.dart';

class SalesTab extends StatefulWidget {
  const SalesTab({super.key, this.autoLoad = true});

  /// Standalone routes load themselves. The shell owns loading for its
  /// IndexedStack tab so the widget is not fetched once while hidden and again
  /// when it becomes visible.
  final bool autoLoad;

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      // Load after the first frame so the Provider tree is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<SalesViewModel>().load();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value, SalesViewModel vm) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) vm.setSearch(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    final session = context.watch<SessionViewModel>();
    // All signed-in employees can add and edit their own sales.
    // Admins and managers can also delete any sale.
    final canWrite = session.user?.isPrivileged ?? false;
    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        backgroundColor: OgeraColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sales'),
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
            child: Row(
              children: [
                Expanded(
                  child: OgeraSearchField(
                    controller: _searchController,
                    hint: 'Search by name, phone or product…',
                    onChanged: (value) => _onSearchChanged(value, vm),
                    onClear: () => vm.setSearch(''),
                  ),
                ),
                
                if (canWrite) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _openForm(context, vm),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Sale'),
                    style: FilledButton.styleFrom(
                      backgroundColor: OgeraColors.forest,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OgeraSpacing.fieldRadius),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: vm.load,
              child: _Body(vm: vm, canWrite: canWrite),
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, SalesViewModel vm, [Sale? existing]) {
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: vm,
            child: SaleFormScreen(existing: existing),
          ),
        ))
        .then((_) => vm.load(silent: true));
  }
}

// ── Body ───────────────────────────────────────────────────────────────────

// _Body is a StatefulWidget so it can own a ScrollController.
// We MUST NOT call vm.loadMore() inside the build callback — doing so fires
// notifyListeners() during the build phase, scheduling another build
// immediately, which produces an infinite rebuild loop that floods the GPU
// buffer queue (BLASTBufferQueue errors on Android).
// Instead we listen to the scroll position and call loadMore() from a
// scroll listener, which runs outside the build phase.
class _Body extends StatefulWidget {
  const _Body({required this.vm, required this.canWrite});

  final SalesViewModel vm;
  final bool canWrite;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearBottom =
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200;
    if (nearBottom && widget.vm.hasMore && !widget.vm.isLoadingMore) {
      widget.vm.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final canWrite = widget.canWrite;

    if (vm.isLoading) {
      return const LoadingListView();
    }

    if (vm.error != null && vm.sales.isEmpty) {
      return ErrorStateView(
        message: vm.error!,
        onRetry: vm.load,
      );
    }

    if (vm.sales.isEmpty) {
      return const EmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: 'No sales yet',
        message: 'Sales records will appear here once they are added.',
      );
    }

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        // Offline banner
        if (vm.isOffline)
          const SliverToBoxAdapter(child: _OfflineBanner()),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final sale = vm.sales[index];
              return _SaleCard(
                sale: sale,
                canWrite: canWrite,
                onEdit: canWrite
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<SalesViewModel>(),
                              child: SaleFormScreen(existing: sale),
                            ),
                          ),
                        )
                    : null,
                onDelete: canWrite
                    ? () => _confirmDelete(context, sale)
                    : null,
              );
            },
            childCount: vm.sales.length,
          ),
        ),

        // Load-more spinner shown below the list while fetching the next page.
        if (vm.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  void _confirmDelete(BuildContext context, Sale sale) {
    // Capture the view model and messenger before the async gap.
    final vm = context.read<SalesViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text(
          'This will permanently delete the sale record for "${sale.displayName}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: OgeraColors.danger,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      final error = await vm.delete(sale.id);
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
    });
  }
}

// ── Sale card ──────────────────────────────────────────────────────────────

class _SaleCard extends StatelessWidget {
  const _SaleCard({
    required this.sale,
    required this.canWrite,
    this.onEdit,
    this.onDelete,
  });

  final Sale sale;
  final bool canWrite;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = sale.purchaseDate != null
        ? '${sale.purchaseDate!.day}/${sale.purchaseDate!.month}/${sale.purchaseDate!.year}'
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: OgeraColors.blueSoft,
          child: const Icon(Icons.receipt_long, color: OgeraColors.blue),
        ),
        title: Text(sale.displayName, style: theme.textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sale.purchasedProduct != null)
              Text(sale.purchasedProduct!, style: theme.textTheme.bodySmall),
            if (dateStr != null)
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OgeraColors.muted,
                ),
              ),
            if (sale.phone != null)
              Text(sale.phone!, style: theme.textTheme.bodySmall),
            if (sale.branch != null && sale.branch!.trim().isNotEmpty)
              Text(
                sale.branch!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: OgeraColors.muted,
                ),
              ),
          ],
        ),
        trailing: canWrite
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: OgeraColors.danger),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

// ── Offline banner ─────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OgeraColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 16, color: OgeraColors.warning),
          const SizedBox(width: 8),
          Text(
            'Showing offline data. Pull to refresh when connected.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
