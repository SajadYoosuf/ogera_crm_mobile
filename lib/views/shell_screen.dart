import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_session.dart';
import '../services/crm_services.dart';
import '../services/location_api_service.dart';
import '../theme/ogera_colors.dart';
import '../view_models/contacts_view_model.dart';
import '../view_models/followups_view_model.dart';
import '../view_models/map_view_model.dart';
import '../view_models/professionals_view_model.dart';
import '../view_models/sales_view_model.dart';
import '../view_models/session_view_model.dart';
import 'contacts/contact_form_screen.dart';
import 'contacts/contacts_tab.dart';
import 'followups/followups_tab.dart';
import 'home/home_tab.dart';
import 'map/map_tab.dart';
import 'more/more_tab.dart';
import 'professionals/professional_form_screen.dart';
import 'professionals/professionals_tab.dart';
import 'sales/sale_form_screen.dart';
import 'shell_scope.dart';

/// Bottom navigation, fixed order: Home · Contacts · Professionals ·
/// Follow-ups · Map · More.
///
/// The tabs are identical for both roles; what changes is what each one shows.
/// Module view models are provided here rather than per screen so a tab keeps
/// its scroll position, filters, and loaded pages while the user moves around —
/// and they are torn down on sign-out, which is why they are not global.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final user = session.user;
    if (user == null) return const SizedBox.shrink();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) =>
              ContactsViewModel(context.read<ContactsService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ProfessionalsViewModel(context.read<ProfessionalsService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => FollowupsViewModel(
            context.read<FollowupsService>(),
            context.read<StaffDirectoryService>(),
            user,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MapViewModel(
            contacts: context.read<ContactsService>(),
            professionals: context.read<ProfessionalsService>(),
            locations: context.read<LocationApiService>(),
            canViewStaff: user.isHead,
          ),
        ),
        // The Sales Ledger is Head-only, so a staff session never builds it.
        if (user.isHead)
          ChangeNotifierProvider(
            create: (context) =>
                SalesViewModel(context.read<SalesService>()),
          ),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: IndexedStack(
          index: _index,
          children: [
            _LazyTab(
              active: _index == 0,
              onActivate: () {
                context.read<ContactsViewModel>().load();
                context.read<FollowupsViewModel>().load();
                if (user.isHead) context.read<SalesViewModel>().load();
              },
              child: const HomeTab(),
            ),
            _LazyTab(
              active: _index == 1,
              onActivate: () => context.read<ContactsViewModel>().load(),
              child: const ContactsTab(),
            ),
            _LazyTab(
              active: _index == 2,
              onActivate: () => context.read<ProfessionalsViewModel>().load(),
              child: const ProfessionalsTab(),
            ),
            _LazyTab(
              active: _index == 3,
              onActivate: () => context.read<FollowupsViewModel>().load(),
              child: const FollowupsTab(),
            ),
            _LazyTab(
              active: _index == 4,
              onActivate: () => context.read<MapViewModel>().load(),
              child: const MapTab(),
            ),
            const MoreTab(),
          ],
          ),
          floatingActionButton: _showsQuickAction
              ? QuickActionFab(user: user)
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: _NavBar(
            index: _index,
            onChanged: (index) => setState(() => _index = index),
          ),
        ),
      ),
    );
  }

  /// The quick action belongs on the tabs where creating a record is the
  /// natural next step; the map and More would only obscure content.
  bool get _showsQuickAction => _index == 0 || _index == 1 || _index == 2;
}

/// IndexedStack builds every tab up front, but network work should begin only
/// for the tab the user actually opens. The child remains mounted so its
/// scroll position and local UI state survive tab changes.
class _LazyTab extends StatefulWidget {
  const _LazyTab({
    required this.active,
    required this.onActivate,
    required this.child,
  });

  final bool active;
  final VoidCallback onActivate;
  final Widget child;

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> {
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    _activateIfNeeded();
  }

  @override
  void didUpdateWidget(_LazyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _activateIfNeeded();
  }

  void _activateIfNeeded() {
    if (!widget.active || _activated) return;
    _activated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onActivate();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: OgeraColors.line)),
      ),
      child: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onChanged,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.handyman_outlined),
            selectedIcon: Icon(Icons.handyman_rounded),
            label: 'Pros',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'Follow-ups',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

/// Expandable quick action: Add Contact and Add Professional for everyone,
/// plus Add Sale for Admin and Sales Head.
class QuickActionFab extends StatefulWidget {
  const QuickActionFab({super.key, required this.user});

  final AuthUser user;

  @override
  State<QuickActionFab> createState() => _QuickActionFabState();
}

class _QuickActionFabState extends State<QuickActionFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _controller.forward() : _controller.reverse();
  }

  Future<void> _run(Future<void> Function() action) async {
    _toggle();
    await action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _action(
          label: 'Add contact',
          icon: Icons.person_add_alt_1_rounded,
          order: widget.user.isHead ? 3 : 2,
          onTap: () => _run(() => openContactForm(context)),
        ),
        _action(
          label: 'Add professional',
          icon: Icons.handyman_rounded,
          order: widget.user.isHead ? 2 : 1,
          onTap: () => _run(() => openProfessionalForm(context)),
        ),
        if (widget.user.isHead)
          _action(
            label: 'Add sale',
            icon: Icons.receipt_long_rounded,
            order: 1,
            onTap: () => _run(() => openSaleForm(context)),
          ),
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: OgeraColors.blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedRotation(
            turns: _open ? 0.125 : 0,
            duration: const Duration(milliseconds: 220),
            child: const Icon(Icons.add_rounded, size: 27),
          ),
        ),
      ],
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required int order,
    required VoidCallback onTap,
  }) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval((order - 1) * 0.12, 1, curve: Curves.easeOutBack),
    );
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 1,
      child: FadeTransition(
        opacity: _controller,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: OgeraColors.ink,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 46,
                height: 46,
                child: Material(
                  color: OgeraColors.surface,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: const BorderSide(color: OgeraColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Icon(icon, size: 21, color: OgeraColors.blue),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared entry points, used by the quick action and by the empty states.
/// Each pushes through [pushShellRoute] so the form can write back into the
/// list it was opened from.

Future<void> openContactForm(BuildContext context) async {
  final contacts = context.read<ContactsViewModel>();
  final created = await pushShellRoute<dynamic>(
    context,
    (_) => const ContactFormScreen(),
  );
  if (created != null) contacts.refresh();
}

Future<void> openProfessionalForm(BuildContext context) async {
  final professionals = context.read<ProfessionalsViewModel>();
  final created = await pushShellRoute<dynamic>(
    context,
    (_) => const ProfessionalFormScreen(),
  );
  if (created != null) professionals.refresh();
}

Future<void> openSaleForm(BuildContext context) async {
  final sales = context.read<SalesViewModel>();
  final created = await pushShellRoute<dynamic>(
    context,
    (_) => const SaleFormScreen(),
  );
  if (created != null) sales.refresh();
}
