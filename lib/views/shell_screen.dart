import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_session.dart';
import '../services/crm_services.dart';
import '../theme/ogera_colors.dart';
import '../view_models/contacts_view_model.dart';
import '../view_models/followups_view_model.dart';
import '../view_models/professionals_view_model.dart';
import '../view_models/session_view_model.dart';
import 'contacts/contact_form_screen.dart';
import 'contacts/contacts_tab.dart';
import 'followups/followups_tab.dart';
import 'home/home_tab.dart';
import 'more/more_tab.dart';
import 'professionals/professional_form_screen.dart';
import 'professionals/professionals_tab.dart';
import 'shell_scope.dart';

/// Bottom navigation, fixed order: Home · Contacts · Professionals ·
/// Home · Contacts · Pros · Follow-ups · More.
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
            const MoreTab(),
          ],
          ),
          floatingActionButton: _buildFab(context),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: _NavBar(
            index: _index,
            onChanged: (index) => setState(() => _index = index),
          ),
        ),
      ),
    );
  }

  /// Build context-specific FAB for each tab
  Widget? _buildFab(BuildContext context) {
    return switch (_index) {
      1 => _DirectActionFab(
        icon: Icons.person_add_alt_1_rounded,
        tooltip: 'Add contact',
        onPressed: () => openContactForm(context),
      ),
      2 => _DirectActionFab(
        icon: Icons.handyman_rounded,
        tooltip: 'Add professional',
        onPressed: () => openProfessionalForm(context),
      ),
      0 => QuickActionFab(user: context.read<SessionViewModel>().user!),
      _ => null,
    };
  }
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
            icon: Icon(Icons.more_horiz_rounded),
            selectedIcon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

/// Expandable quick action: Add Contact and Add Professional for everyone.
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _action(
          label: 'Add contact',
          icon: Icons.person_add_alt_1_rounded,
          order: 2,
          onTap: () => _run(() => openContactForm(context)),
        ),
        _action(
          label: 'Add professional',
          icon: Icons.handyman_rounded,
          order: 1,
          onTap: () => _run(() => openProfessionalForm(context)),
        ),
        const SizedBox(width: 8),
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
      axisAlignment: 0,
      child: FadeTransition(
        opacity: _controller,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: OgeraColors.ink,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: OgeraColors.surface,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: OgeraColors.line),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Icon(icon, size: 18, color: OgeraColors.blue),
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

/// Simple FAB that directly opens a form without nested menu
class _DirectActionFab extends StatelessWidget {
  const _DirectActionFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: OgeraColors.blue,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 27),
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
