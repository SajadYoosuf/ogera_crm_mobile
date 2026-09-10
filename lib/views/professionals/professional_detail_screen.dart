import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/launchers.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/contact.dart';
import '../../models/professional.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/professionals_view_model.dart';
import '../contacts/contact_detail_screen.dart';
import 'professional_form_screen.dart';
import 'professionals_tab.dart';
import '../shell_scope.dart';

class ProfessionalDetailScreen extends StatefulWidget {
  const ProfessionalDetailScreen({super.key, required this.professional});

  final Professional professional;

  @override
  State<ProfessionalDetailScreen> createState() =>
      _ProfessionalDetailScreenState();
}

class _ProfessionalDetailScreenState extends State<ProfessionalDetailScreen> {
  late Professional _professional = widget.professional;

  List<Contact> _referred = const [];
  bool _isLoadingReferred = true;

  @override
  void initState() {
    super.initState();
    _loadReferred();
  }

  /// Contacts this professional introduced. The API has no dedicated endpoint,
  /// so the phone number — which the contact stores as a referral snapshot — is
  /// the join key.
  Future<void> _loadReferred() async {
    try {
      final results = await context.read<ContactsService>().search(
        _professional.phone,
      );
      if (!mounted) return;
      setState(() {
        _referred = results
            .where(
              (contact) => contact.professionalPhone == _professional.phone,
            )
            .toList(growable: false);
        _isLoadingReferred = false;
      });
    } on ApiException {
      if (mounted) setState(() => _isLoadingReferred = false);
    }
  }

  Future<void> _edit() async {
    final updated = await pushShellRoute<Professional>(
      context,
      (_) => ProfessionalFormScreen(existing: _professional),
    );
    if (updated == null || !mounted) return;
    setState(() => _professional = updated);
    context.read<ProfessionalsViewModel>().upsert(updated);
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this professional?',
      message:
          '${_professional.displayName} will be removed from the directory. '
          'Contacts they referred keep their referral details.',
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<ProfessionalsService>().delete(_professional.id);
      if (!mounted) return;
      context.read<ProfessionalsViewModel>().removeById(_professional.id);
      showToast(context, 'Professional deleted.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final professional = _professional;
    final canEdit = canEditProfessional(context, professional);

    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(
        title: const Text('Professional'),
        actions: [
          if (canEdit) ...[
            IconButton(
              tooltip: 'Edit professional',
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          OgeraSpacing.screen,
          32,
        ),
        children: [
          _Header(professional: professional),
          const SizedBox(height: OgeraSpacing.gap),
          if (professional.hasLocation) ...[
            _MapPreview(professional: professional),
            const SizedBox(height: OgeraSpacing.gap),
          ],
          OgeraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Details',
                  icon: Icons.info_outline_rounded,
                ),
                DetailRow(label: 'Profession', value: professional.type.label),
                DetailRow(
                  label: 'Place',
                  value: professional.place,
                  icon: Icons.storefront_outlined,
                ),
                DetailRow(
                  label: 'Address',
                  value: professional.address,
                  icon: Icons.home_outlined,
                ),
                DetailRow(label: 'Panchayath', value: professional.panchayath),
                DetailRow(label: 'District', value: professional.district),
                if (professional.hasLocation)
                  DetailRow(
                    label: 'Coordinates',
                    value:
                        '${professional.latitude}, ${professional.longitude}',
                    icon: Icons.my_location_rounded,
                    onTap: () => Launchers.directions(
                      context,
                      latitude: professional.lat,
                      longitude: professional.lng,
                    ),
                  ),
                DetailRow(
                  label: 'Added',
                  value: formatMoment(professional.createdAt),
                  icon: Icons.schedule_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: OgeraSpacing.gap),
          _ReferredContacts(contacts: _referred, isLoading: _isLoadingReferred),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.professional});

  final Professional professional;

  @override
  Widget build(BuildContext context) {
    final type = professional.type;
    return OgeraCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: type.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: type.color.withValues(alpha: 0.28)),
                ),
                child: Icon(type.icon, size: 27, color: type.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      professional.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      professional.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: OgeraColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 9),
                    StatusChip(label: type.label, color: type.color),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Action(
                icon: Icons.call_rounded,
                label: 'Call',
                color: OgeraColors.blue,
                onTap: () => Launchers.call(context, professional.phone),
              ),
              _Action(
                icon: Icons.chat_rounded,
                label: 'WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => Launchers.whatsapp(context, professional.phone),
              ),
              _Action(
                icon: Icons.directions_rounded,
                label: 'Directions',
                color: OgeraColors.warning,
                onTap:
                    professional.hasLocation ||
                        (professional.address ?? '').isNotEmpty
                    ? () => Launchers.directions(
                        context,
                        latitude: professional.lat,
                        longitude: professional.lng,
                        address: professional.address ?? professional.place,
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

class _Action extends StatelessWidget {
  const _Action({
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

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.professional});

  final Professional professional;

  @override
  Widget build(BuildContext context) {
    final position = LatLng(professional.lat!, professional.lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(OgeraSpacing.cardRadius),
      child: SizedBox(
        height: 160,
        child: FlutterMap(
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
                  child: Icon(
                    professional.type.icon,
                    size: 24,
                    color: professional.type.color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferredContacts extends StatelessWidget {
  const _ReferredContacts({required this.contacts, required this.isLoading});

  final List<Contact> contacts;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return OgeraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Contacts referred',
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
                'No contacts have been referred by this professional yet.',
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
                ),
                title: Text(
                  contact.displayName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  contact.phone,
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
