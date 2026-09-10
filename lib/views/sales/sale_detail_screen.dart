import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../models/sale.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/sales_view_model.dart';
import '../contacts/contact_detail_screen.dart';
import 'sale_form_screen.dart';
import '../shell_scope.dart';

/// One sale, with everything that hangs off it: the money, the site, the
/// referral chain, and the contacts this sale went on to generate.
class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({super.key, required this.sale});

  final Sale sale;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  late Sale _sale = widget.sale;

  List<Contact> _referrals = const [];
  bool _isLoadingReferrals = true;

  @override
  void initState() {
    super.initState();
    _loadReferrals();
  }

  Future<void> _loadReferrals() async {
    try {
      final referrals = await context.read<SalesService>().referrals(_sale.id);
      if (!mounted) return;
      setState(() {
        _referrals = referrals;
        _isLoadingReferrals = false;
      });
    } on ApiException {
      if (mounted) setState(() => _isLoadingReferrals = false);
    }
  }

  Future<void> _edit() async {
    final updated = await pushShellRoute<Sale>(
      context,
      (_) => SaleFormScreen(existing: _sale),
    );
    if (updated == null || !mounted) return;
    setState(() => _sale = updated);
    context.read<SalesViewModel>().upsert(updated);
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this sale?',
      message:
          'The sale to ${_sale.buyerName} will be removed from the ledger '
          'and its totals. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<SalesService>().delete(_sale.id);
      if (!mounted) return;
      context.read<SalesViewModel>().removeById(_sale.id);
      showToast(context, 'Sale deleted.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    final date = sale.saleDateTime;

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Sale'),
        actions: [
          IconButton(
            tooltip: 'Edit sale',
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (value) {
              if (value == 'delete') _delete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 19,
                      color: OgeraColors.danger,
                    ),
                    SizedBox(width: 10),
                    Text('Delete', style: TextStyle(color: OgeraColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          32,
        ),
        children: [
          _AmountCard(sale: sale, date: date),
          const SizedBox(height: OgeraSpacing.gap),
          OgeraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Buyer',
                  icon: Icons.person_outline_rounded,
                ),
                DetailRow(
                  label: 'Name',
                  value: sale.buyerName,
                  icon: Icons.badge_outlined,
                ),
                DetailRow(
                  label: 'Phone',
                  value: sale.buyerPhone,
                  icon: Icons.call_outlined,
                  onTap: () => Launchers.call(context, sale.buyerPhone),
                ),
                DetailRow(
                  label: 'Address',
                  value: sale.address,
                  icon: Icons.home_outlined,
                ),
                DetailRow(label: 'Panchayath', value: sale.panchayath),
                DetailRow(label: 'Ward', value: sale.ward),
              ],
            ),
          ),
          const SizedBox(height: OgeraSpacing.gap),
          OgeraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Site details',
                  icon: Icons.water_drop_outlined,
                ),
                DetailRow(
                  label: 'House stage',
                  value: sale.houseStage == null
                      ? null
                      : SaleOptions.label(
                          SaleOptions.houseStages,
                          sale.houseStage,
                        ),
                ),
                DetailRow(
                  label: 'Current tank',
                  value: sale.currentTank == null
                      ? null
                      : SaleOptions.label(
                          SaleOptions.currentTanks,
                          sale.currentTank,
                        ),
                ),
                DetailRow(
                  label: 'Water source',
                  value: sale.waterSource == null
                      ? null
                      : SaleOptions.label(
                          SaleOptions.waterSources,
                          sale.waterSource,
                        ),
                ),
                DetailRow(
                  label: 'Source of sale',
                  value: sale.sourceOfSale == null
                      ? null
                      : SaleOptions.label(
                          SaleOptions.sourcesOfSale,
                          sale.sourceOfSale,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: OgeraSpacing.gap),
          _ReferralCard(sale: sale),
          const SizedBox(height: OgeraSpacing.gap),
          _GeneratedContacts(
            contacts: _referrals,
            isLoading: _isLoadingReferrals,
          ),
          if ((sale.remarks ?? '').isNotEmpty) ...[
            const SizedBox(height: OgeraSpacing.gap),
            OgeraCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Remarks',
                    icon: Icons.notes_rounded,
                  ),
                  Text(
                    sale.remarks!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.sale, required this.date});

  final Sale sale;
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      accent: OgeraColors.success,
      padding: const EdgeInsets.all(18),
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
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: OgeraColors.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      sale.totalPrice == null
                          ? '—'
                          : formatCurrency(sale.totalPrice!),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: OgeraColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              if (date != null)
                StatusChip(
                  label: formatFullDate(date!),
                  icon: Icons.event_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              _Figure(label: 'Tank size', value: sale.tankSize ?? '—'),
              Container(width: 1, height: 30, color: OgeraColors.line),
              _Figure(
                label: 'Quantity',
                value: sale.quantity == null ? '—' : '${sale.quantity}',
              ),
              Container(width: 1, height: 30, color: OgeraColors.line),
              _Figure(
                label: 'Unit price',
                value: sale.unitPrice == null
                    ? '—'
                    : formatCurrency(sale.unitPrice!),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Launchers.call(context, sale.buyerPhone),
                  icon: const Icon(Icons.call_rounded, size: 17),
                  label: const Text('Call buyer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Launchers.whatsapp(context, sale.buyerPhone),
                  icon: const Icon(Icons.chat_rounded, size: 17),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: OgeraColors.muted),
          ),
        ],
      ),
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    final hasEngineer =
        (sale.engineerName ?? '').isNotEmpty ||
        (sale.engineerPhone ?? '').isNotEmpty;
    final hasPlumber =
        (sale.plumberName ?? '').isNotEmpty ||
        (sale.plumberPhone ?? '').isNotEmpty;
    if (!hasEngineer && !hasPlumber) return const SizedBox.shrink();

    return OgeraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Referral', icon: Icons.handyman_outlined),
          if (hasEngineer) ...[
            DetailRow(
              label: 'Engineer',
              value: sale.engineerName,
              icon: Icons.architecture_rounded,
            ),
            DetailRow(
              label: 'Phone',
              value: sale.engineerPhone,
              icon: Icons.call_outlined,
              onTap: (sale.engineerPhone ?? '').isEmpty
                  ? null
                  : () => Launchers.call(context, sale.engineerPhone!),
            ),
          ],
          if (hasPlumber) ...[
            DetailRow(
              label: 'Plumber',
              value: sale.plumberName,
              icon: Icons.plumbing_rounded,
            ),
            DetailRow(
              label: 'Phone',
              value: sale.plumberPhone,
              icon: Icons.call_outlined,
              onTap: (sale.plumberPhone ?? '').isEmpty
                  ? null
                  : () => Launchers.call(context, sale.plumberPhone!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Contacts created with this sale as their referral source — the sale's own
/// downstream pipeline.
class _GeneratedContacts extends StatelessWidget {
  const _GeneratedContacts({required this.contacts, required this.isLoading});

  final List<Contact> contacts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Contacts from this sale',
            icon: Icons.share_outlined,
            action: contacts.isEmpty
                ? null
                : StatusChip(
                    label: '${contacts.length}',
                    tone: StatusTone.brand,
                    dense: true,
                  ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: ShimmerBox(height: 52),
            )
          else if (contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'No contacts have been referred by this sale yet.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: OgeraColors.muted,
                  height: 1.45,
                ),
              ),
            )
          else
            for (final contact in contacts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: OgeraAvatar(
                  name: contact.name,
                  phone: contact.phone,
                  size: 38,
                  color: contact.contactType == ContactType.lead
                      ? OgeraColors.blue
                      : OgeraColors.info,
                ),
                title: Text(
                  contact.displayName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${contact.phone} · ${formatRelative(contact.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: OgeraColors.muted,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: OgeraColors.muted,
                ),
                onTap: () => pushShellRoute<void>(
                  context,
                  (_) => ContactDetailScreen(
                    contactId: contact.id,
                    initial: contact,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
