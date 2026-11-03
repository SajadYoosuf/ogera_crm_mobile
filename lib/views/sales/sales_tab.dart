// sales_tab.dart
//
// The Sales tab — a searchable, filterable list of past sale records.
//
// WHAT IT SHOWS:
//   - A search bar (name, phone, address or product).
//   - A list of sale cards, newest first.
//   - Tapping a card opens the edit form (admin/manager only see Edit option).
//   - A FAB to create a new sale (shown only to admins and managers).
//
// DATA FLOW:
//   SalesTab → SalesViewModel → SalesService → GET /sales
//
// OFFLINE:
//   When offline, the last cached list is shown with a banner.
//   Any pending (queued) writes are replayed on the next successful load.

library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/state_views.dart';
import '../../models/sale.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';
import '../../view_models/session_view_model.dart';
import 'sale_form_screen.dart';

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load after the first frame so the Provider tree is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<SalesViewModel>();
      vm.load();
      vm.loadProductSuggestions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SalesViewModel>();
    final session = context.watch<SessionViewModel>();
    final canWrite = session.user?.isPrivileged ?? false;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Sales'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search by name, phone or product…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      vm.setSearch('');
                    },
                  ),
              ],
              onChanged: vm.setSearch,
            ),
          ),
        ),
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton(
              onPressed: () => _openForm(context, vm),
              tooltip: 'Add sale',
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: vm.load,
        child: _Body(vm: vm, canWrite: canWrite),
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

class _Body extends StatelessWidget {
  const _Body({required this.vm, required this.canWrite});

  final SalesViewModel vm;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
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
      slivers: [
        // Offline banner
        if (vm.isOffline)
          const SliverToBoxAdapter(child: _OfflineBanner()),

        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == vm.sales.length) {
                // Load-more trigger at the end of the list.
                if (vm.hasMore) {
                  vm.loadMore();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return null;
              }
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
            childCount: vm.sales.length + (vm.hasMore ? 1 : 0),
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
