import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/api_client.dart';
import '../services/crm_services.dart';
import '../services/expense_service.dart';
import '../services/home_service.dart';
import '../services/notification_service.dart';
import '../services/pipeline_service.dart';
import '../services/tasks_service.dart';
import '../theme/ogera_colors.dart';
import '../view_models/contacts_view_model.dart';
import '../view_models/expense_view_model.dart';
import '../view_models/followups_view_model.dart';
import '../view_models/home_view_model.dart';
import '../view_models/notification_view_model.dart';
import '../view_models/pipeline_view_model.dart';
import '../view_models/professionals_view_model.dart';
import '../view_models/session_view_model.dart';
import '../view_models/tasks_view_model.dart';
import 'contacts/add_contact_sheet.dart';
import 'contacts/contacts_tab.dart';
import 'professionals/professional_form_screen.dart';
import 'home/home_tab.dart';
import 'home/quick_action_sheets.dart';
import 'more/more_tab.dart';
import 'pipeline/pipeline_tab.dart';
import 'tasks/tasks_tab.dart';
import 'shell_scope.dart';

/// Signed-in shell: bottom bar, a centre-docked quick-action button, and the
/// module view models the tabs share.
///
/// Tab order: Home · Contacts · Tasks · Pipeline · More.
/// Tasks is a placeholder until Sprint 2; Pipeline is live from Sprint 3.
///
/// The centre button fans out three circle buttons: Add contact, Activity log,
/// and Add expense (staff only). Module view models are provided here, not per
/// screen, so a tab keeps its scroll position and loaded pages when the user
/// moves around. They are torn down on sign-out, which is why they are not global.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _fabOpen = false;

  /// Drives the fan-out animation: 0 is closed, 1 is fully open.
  late final AnimationController _fabController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  /// Opens or closes the fan of circle buttons, and plays the animation.
  void _setFabOpen(bool open) {
    if (_fabOpen == open) return;
    setState(() => _fabOpen = open);
    open ? _fabController.forward() : _fabController.reverse();
  }

  /// Closes the fan first, then runs the action (which opens a form or sheet),
  /// so the sheet appears over a clean screen.
  void _runFabAction(Future<void> Function() action) {
    _setFabOpen(false);
    action();
  }

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
          create: (context) => HomeViewModel(context.read<HomeService>()),
        ),
        ChangeNotifierProvider(
          create: (context) => ExpenseViewModel(context.read<ExpenseService>()),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              PipelineViewModel(PipelineService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              TasksViewModel(TasksService(context.read<ApiClient>())),
        ),
        ChangeNotifierProvider(
          create: (context) => NotificationViewModel(
            NotificationService(context.read<ApiClient>()),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Built here, under the providers, so each action can read them.
          final actions = [
            _FabAction(
              label: 'Add contact',
              icon: Icons.person_add_alt_1_rounded,
              onTap: () => _runFabAction(() => showAddContactSheet(context)),
            ),
            _FabAction(
              label: 'Activity log',
              icon: Icons.history_edu_rounded,
              onTap: () => _runFabAction(() => openActivityLog(context)),
            ),
            // Admin and manager review expenses; the backend rejects their
            // submissions with 403, so the button is not offered to them.
            if (!user.isHead)
              _FabAction(
                label: 'Add expense',
                icon: Icons.receipt_long_rounded,
                onTap: () => _runFabAction(() => openExpenseAdd(context)),
              ),
          ];

          return PopScope(
            // Back closes the fan instead of leaving the app.
            canPop: !_fabOpen,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _setFabOpen(false);
            },
            child: Scaffold(
              body: Stack(
                children: [
                  IndexedStack(
                    index: _index,
                    children: [
                      _LazyTab(
                        active: _index == 0,
                        onActivate: () {
                          context.read<HomeViewModel>().load();
                          context.read<FollowupsViewModel>().load();
                          context.read<NotificationViewModel>().load();
                        },
                        child: const HomeTab(),
                      ),
                      _LazyTab(
                        active: _index == 1,
                        onActivate: () =>
                            context.read<ContactsViewModel>().load(),
                        child: const ContactsTab(),
                      ),
                      _LazyTab(
                        active: _index == 2,
                        onActivate: () => context.read<TasksViewModel>().load(),
                        child: const TasksTab(),
                      ),
                      _LazyTab(
                        active: _index == 3,
                        onActivate: () =>
                            context.read<PipelineViewModel>().load(),
                        child: const PipelineTab(),
                      ),
                      const MoreTab(),
                    ],
                  ),
                  // Dims the screen while the fan is open; tapping it closes the fan.
                  if (_fabOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setFabOpen(false),
                        child: const ColoredBox(color: Color(0x66000000)),
                      ),
                    ),
                  // Above the dimmer, so the circle buttons get the taps.
                  Positioned.fill(
                    child: _FanLayer(
                      animation: _fabController,
                      open: _fabOpen,
                      actions: actions,
                    ),
                  ),
                ],
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerDocked,
              floatingActionButton: _ShellFab(
                animation: _fabController,
                open: _fabOpen,
                onToggle: () => _setFabOpen(!_fabOpen),
              ),
              bottomNavigationBar: _NavBar(
                index: _index,
                onChanged: (index) {
                  _setFabOpen(false);
                  setState(() => _index = index);
                },
              ),
            ),
          );
        },
      ),
    );
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

/// Bottom bar with two tabs on the left, a gap in the middle for the docked
/// button, and three tabs on the right.
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
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        color: OgeraColors.surface,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _item(
                0,
                Icons.dashboard_outlined,
                Icons.dashboard_rounded,
                'Home',
              ),
              _item(
                1,
                Icons.people_outline_rounded,
                Icons.people_rounded,
                'Contacts',
              ),
              // Space for the docked quick-action button.
              const SizedBox(width: 72),
              _item(
                2,
                Icons.check_circle_outline_rounded,
                Icons.check_circle_rounded,
                'Tasks',
              ),
              _item(
                3,
                Icons.view_kanban_outlined,
                Icons.view_kanban_rounded,
                'Pipeline',
              ),
              _item(
                4,
                Icons.more_horiz_rounded,
                Icons.more_horiz_rounded,
                'More',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int tab, IconData icon, IconData selectedIcon, String label) {
    final selected = index == tab;
    final color = selected ? OgeraColors.blue : OgeraColors.muted;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(tab),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One circle button in the fan: what it shows and what it does.
class _FabAction {
  const _FabAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// The one quick-action button, docked in the middle of the bottom bar.
///
/// It only opens and closes the fan. The fan is drawn by [_FanLayer] in the
/// screen body: a widget can be tapped only inside its own box, and the circle
/// buttons sit above this 56px button, so they must not live inside it.
class _ShellFab extends StatelessWidget {
  const _ShellFab({
    required this.open,
    required this.onToggle,
    required this.animation,
  });

  final bool open;
  final VoidCallback onToggle;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onToggle,
      tooltip: open ? 'Close quick actions' : 'Quick actions',
      backgroundColor: OgeraColors.blue,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: RotationTransition(
        turns: Tween<double>(begin: 0, end: 0.125).animate(animation),
        child: const Icon(Icons.add_rounded, size: 27),
      ),
    );
  }
}

/// Draws the circle buttons over the screen, above the dimmer.
///
/// The box is anchored to the bottom centre of the body, which is the centre
/// of the docked button (the button sits on the top edge of the bar). Each
/// circle starts there and moves out to its offset as [animation] runs.
class _FanLayer extends StatelessWidget {
  const _FanLayer({
    required this.animation,
    required this.open,
    required this.actions,
  });

  final Animation<double> animation;
  final bool open;
  final List<_FabAction> actions;

  @override
  Widget build(BuildContext context) {
    final offsets = _fanOffsets(actions.length);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 320,
        height: 200,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (var i = 0; i < actions.length; i++)
              _FanButton(
                animation: animation,
                enabled: open,
                offset: offsets[i],
                action: actions[i],
              ),
          ],
        ),
      ),
    );
  }

  /// Where each circle ends up, measured from the centre of the docked button
  /// to the bottom of that circle. Negative y is up. The first button goes
  /// left, the middle one up, the last right, so the arc stays clear of the
  /// bar's edges.
  static List<Offset> _fanOffsets(int count) => switch (count) {
    1 => const [Offset(0, -62)],
    2 => const [Offset(-72, -54), Offset(72, -54)],
    _ => const [Offset(-96, -38), Offset(0, -78), Offset(96, -38)],
  };
}

/// One labelled circle button in the fan. Hidden and non-tappable when closed.
class _FanButton extends StatelessWidget {
  const _FanButton({
    required this.animation,
    required this.enabled,
    required this.offset,
    required this.action,
  });

  final Animation<double> animation;
  final bool enabled;
  final Offset offset;
  final _FabAction action;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Closed: build nothing, so the hidden labels are not announced.
        if (animation.value == 0) return const SizedBox.shrink();
        // Ease the progress so the circles decelerate into place.
        final t = Curves.easeOutCubic.transform(animation.value);
        // The translate must be the outermost widget. A plain box takes
        // taps only inside its own untranslated size, so anything inside
        // the translate would miss a circle that has moved.
        return Transform.translate(
          offset: offset * t,
          child: Opacity(
            opacity: t,
            child: IgnorePointer(ignoring: !enabled, child: child),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The label is tappable too. Without this, a tap on the text
          // reaches the dim backdrop, which closes the fan instead.
          GestureDetector(
            onTap: action.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: OgeraColors.ink,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                action.label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Material(
            color: OgeraColors.surface,
            elevation: 3,
            shape: const CircleBorder(
              side: BorderSide(color: OgeraColors.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: action.onTap,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(action.icon, size: 22, color: OgeraColors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared entry points for the Add contact and Add professional forms.
/// Each pushes through [pushShellRoute] so the form can write back into the
/// list it was opened from.
Future<void> openProfessionalForm(BuildContext context) async {
  final professionals = context.read<ProfessionalsViewModel>();
  final created = await pushShellRoute<dynamic>(
    context,
    (_) => const ProfessionalFormScreen(),
  );
  if (created != null) professionals.refresh();
}
