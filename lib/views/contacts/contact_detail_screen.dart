import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/reference/crm_options.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/contacts_view_model.dart';
import 'contact_form_screen.dart';
import 'contacts_tab.dart';
import '../shell_scope.dart';

/// Full contact record. Edit and delete are absent — not disabled — for a staff
/// member looking at someone else's record, so the interface never offers an
/// action the API would refuse.
class ContactDetailScreen extends StatefulWidget {
  const ContactDetailScreen({super.key, required this.contactId, this.initial});

  final int contactId;
  final Contact? initial;

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  Contact? _contact;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _contact = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final contact = await context.read<ContactsService>().detail(
        widget.contactId,
      );
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _error = null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _edit() async {
    final updated = await pushShellRoute<Contact>(
      context,
      (_) => ContactFormScreen(existing: _contact),
    );
    if (updated == null || !mounted) return;
    setState(() => _contact = updated);
    context.read<ContactsViewModel>().upsert(updated);
  }

  Future<void> _delete() async {
    final contact = _contact;
    if (contact == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this contact?',
      message:
          '${contact.displayName} will be removed from the CRM. This cannot be undone.',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ContactsService>().delete(contact.id);
      if (!mounted) return;
      context.read<ContactsViewModel>().removeById(contact.id);
      showToast(context, 'Contact deleted.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = _contact;

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact')),
        body: _isLoading
            ? const LoadingListView()
            : ErrorStateView(
                message: _error ?? 'Contact not found',
                onRetry: _load,
              ),
      );
    }

    final canEdit = canEditContact(context, contact);

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Contact'),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: 'Edit contact',
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
                      Text(
                        'Delete',
                        style: TextStyle(color: OgeraColors.danger),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: StatusChip(
                  label: 'View only',
                  icon: Icons.lock_outline_rounded,
                  dense: true,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            OgeraSpacing.screen,
            32,
          ),
          children: [
            _Header(contact: contact),
            const SizedBox(height: OgeraSpacing.gap),
            if (contact.hasLocation) ...[
              _MapPreview(contact: contact),
              const SizedBox(height: OgeraSpacing.gap),
            ],
            _Section(
              title: 'Location',
              icon: Icons.place_outlined,
              children: [
                DetailRow(
                  label: 'Address',
                  value: contact.address,
                  icon: Icons.home_outlined,
                ),
                DetailRow(label: 'District', value: contact.district),
                DetailRow(label: 'Panchayath', value: contact.panchayath),
                DetailRow(label: 'Ward', value: contact.ward),
                if (contact.hasLocation)
                  DetailRow(
                    label: 'Coordinates',
                    value: '${contact.latitude}, ${contact.longitude}',
                    icon: Icons.my_location_rounded,
                    onTap: () => Launchers.directions(
                      context,
                      latitude: contact.lat,
                      longitude: contact.lng,
                    ),
                  ),
              ],
            ),
            _Section(
              title: 'Site details',
              icon: Icons.water_drop_outlined,
              children: [
                DetailRow(
                  label: 'House stage',
                  value: CrmOptions.houseStageLabel(contact.houseStage),
                ),
                DetailRow(label: 'Current tank', value: contact.currentTank),
                DetailRow(label: 'Water source', value: contact.waterSource),
                DetailRow(
                  label: 'Tank interest',
                  value: contact.tankSizeInterest,
                ),
                DetailRow(label: 'Awareness', value: contact.awarenessLevel),
              ],
            ),
            _Section(
              title: 'Origin',
              icon: Icons.share_outlined,
              children: [
                DetailRow(
                  label: 'Source',
                  value: contact.source == null
                      ? null
                      : CrmOptions.sourceLabel(contact.source!),
                ),
                DetailRow(label: 'Referred by', value: contact.referralSummary),
                if (contact.professionalPhone != null)
                  DetailRow(
                    label: 'Referrer phone',
                    value: contact.professionalPhone,
                    icon: Icons.call_outlined,
                    onTap: () =>
                        Launchers.call(context, contact.professionalPhone!),
                  ),
                DetailRow(
                  label: 'Campaign',
                  value: contact.isCampaignTarget ? 'Campaign target' : null,
                ),
                DetailRow(label: 'Added by', value: contact.addedBy),
                DetailRow(
                  label: 'Created',
                  value: formatMoment(contact.createdAt),
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
            if ((contact.remarks ?? '').isNotEmpty)
              _Section(
                title: 'Remarks',
                icon: Icons.notes_rounded,
                children: [
                  Text(
                    contact.remarks!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final isLead = contact.contactType == ContactType.lead;
    return OgeraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OgeraAvatar(
                name: contact.name,
                phone: contact.phone,
                size: 56,
                color: isLead ? OgeraColors.blue : OgeraColors.info,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      contact.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StatusChip(
                          label: isLead ? 'Lead' : 'Awareness',
                          tone: isLead ? StatusTone.brand : StatusTone.info,
                        ),
                        if ((contact.stage ?? '').isNotEmpty)
                          StatusChip(
                            label: humanizeSlug(contact.stage!),
                            tone: StatusTone.neutral,
                          ),
                        if (contact.isCampaignTarget)
                          const StatusChip(
                            label: 'Campaign',
                            tone: StatusTone.warning,
                            icon: Icons.campaign_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HeaderAction(
                icon: Icons.call_rounded,
                label: 'Call',
                color: OgeraColors.blue,
                onTap: () => Launchers.call(
                  context,
                  contact.phone,
                  countryCode: contact.countryCode,
                ),
              ),
              _HeaderAction(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => Launchers.whatsapp(
                  context,
                  contact.phone,
                  countryCode: contact.countryCode,
                ),
              ),
              _HeaderAction(
                icon: Icons.directions_rounded,
                label: 'Directions',
                color: OgeraColors.warning,
                onTap: contact.hasLocation || (contact.address ?? '').isNotEmpty
                    ? () => Launchers.directions(
                        context,
                        latitude: contact.lat,
                        longitude: contact.lng,
                        address: contact.address,
                      )
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 23, color: enabled ? color : OgeraColors.muted),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: enabled ? OgeraColors.ink : OgeraColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A static, non-interactive map so the record shows where it is without
/// pulling the user into a full map screen.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.contact});

  final Contact contact;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(contact.lat!, contact.lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: position,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: AppConfig.osmTileUrl,
                  userAgentPackageName: AppConfig.osmTilePackage,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 36,
                        color: OgeraColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: OgeraColors.surface,
                  foregroundColor: OgeraColors.ink,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => Launchers.directions(
                  context,
                  latitude: contact.lat,
                  longitude: contact.lng,
                ),
                icon: const Icon(Icons.directions_rounded, size: 17),
                label: const Text('Directions'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // A section whose rows are all empty adds nothing but noise.
    final hasContent = children.any(
      (child) => child is! DetailRow || child.hasValue,
    );
    if (!hasContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: OgeraSpacing.gap),
      child: OgeraCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: title, icon: icon),
            ...children,
          ],
        ),
      ),
    );
  }
}
