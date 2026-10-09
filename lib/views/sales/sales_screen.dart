import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/sale.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';
import 'sale_detail_screen.dart';
import 'sale_filters_sheet.dart';
import 'sale_form_screen.dart';
import '../shell_scope.dart';

/// The Sales Ledger — Admin and Sales Head only.
///
/// A staff session never reaches this screen: it is not in their navigation,
/// the view model is not constructed for them, and the API refuses the calls.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<SalesViewModel>().loadMore();
    }
  }

  Future<void> _create() async {
    final viewModel = context.read<SalesViewModel>();
    final created = await pushShellRoute<Sale>(
      context,
      (_) => const SaleFormScreen(),
    );
    if (created != null) viewModel.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesViewModel>();

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Sales Ledger'),
        actions: [
          IconButton(
            tooltip: 'Filters',
            onPressed: () => showSaleFilters(context),
            icon: Badge(
              isLabelVisible: viewModel.hasFilters,
              backgroundColor: OgeraColors.blue,
              child: const Icon(Icons.tune_rounded),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: OgeraColors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add sale'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              hint: 'Search buyer, phone, address, or product',
              onChanged: viewModel.search,
            ),
          ),
          _SummaryBar(viewModel: viewModel),
          const SizedBox(height: 10),
          Expanded(child: _SalesList(scrollController: _scrollController)),
        ],
      ),
    );
  }
}

/// How many sales match the search and filters. The register keeps no price
/// or quantity, so the old revenue and tank totals are gone with them.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.viewModel});

  final SalesViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OgeraSpacing.screen),
      child: OgeraCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        child: Row(
          children: [
            _Metric(
              label: viewModel.hasFilters ? 'Matching sales' : 'Total sales',
              value: '${viewModel.total}',
              icon: Icons.receipt_long_outlined,
              color: OgeraColors.blue,
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: OgeraColors.muted),
          ),
        ],
      ),
    );
  }
}

class _SalesList extends StatelessWidget {
  const _SalesList({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SalesViewModel>();

    if (viewModel.isLoading) return const LoadingListView(itemHeight: 104);

    if (viewModel.error != null && viewModel.sales.isEmpty) {
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: ErrorStateView(
          message: viewModel.error!,
          onRetry: viewModel.load,
        ),
      );
    }

    if (viewModel.sales.isEmpty) {
      final filtered = viewModel.hasFilters || viewModel.query.isNotEmpty;
      return RefreshableMessage(
        onRefresh: viewModel.refresh,
        child: EmptyStateView(
          icon: filtered
              ? Icons.search_off_rounded
              : Icons.receipt_long_outlined,
          title: filtered ? 'No matching sales' : 'No sales recorded yet',
          message: filtered
              ? 'Try a different search, or clear the filters to see the whole ledger.'
              : 'Completed sales you record will appear here with their totals.',
          actionLabel: filtered ? 'Clear filters' : null,
          onAction: filtered ? viewModel.clearFilters : null,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.refresh,
      child: ListView.separated(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          4,
          OgeraSpacing.screen,
          110,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: viewModel.sales.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: OgeraSpacing.gap),
        itemBuilder: (context, index) {
          if (index == viewModel.sales.length) {
            if (viewModel.isLoadingMore) {
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
            if (viewModel.hasMore) return const SizedBox(height: 24);
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Center(
                child: Text(
                  viewModel.total == 1 ? '1 sale' : '${viewModel.total} sales',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: OgeraColors.muted,
                  ),
                ),
              ),
            );
          }
          return SaleCard(sale: viewModel.sales[index]);
        },
      ),
    );
  }
}

class SaleCard extends StatelessWidget {
  const SaleCard({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final date = sale.saleDateTime;
    final location = [
      sale.panchayath,
      sale.ward,
    ].where((part) => (part ?? '').isNotEmpty).join(' · ');

    return OgeraCard(
      accent: OgeraColors.success,
      onTap: () =>
          pushShellRoute<void>(context, (_) => SaleDetailScreen(sale: sale)),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.buyerName,
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
                      sale.buyerPhone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    sale.totalPrice == null
                        ? '—'
                        : formatCurrency(sale.totalPrice!),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: OgeraColors.success,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      formatDayMonth(date),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if ((sale.tankSize ?? '').isNotEmpty)
                StatusChip(
                  label: sale.quantity == null
                      ? sale.tankSize!
                      : '${sale.tankSize} × ${sale.quantity}',
                  tone: StatusTone.brand,
                  icon: Icons.water_drop_outlined,
                  dense: true,
                ),
              if (location.isNotEmpty)
                StatusChip(
                  label: location,
                  icon: Icons.location_city_rounded,
                  dense: true,
                ),
              if ((sale.sourceOfSale ?? '').isNotEmpty)
                StatusChip(
                  label: SaleOptions.label(
                    SaleOptions.sourcesOfSale,
                    sale.sourceOfSale,
                  ),
                  tone: StatusTone.info,
                  dense: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
