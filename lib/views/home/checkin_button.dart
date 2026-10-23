/// Check-in card for the Home tab.
///
/// Reads [HomeViewModel]. When the employee is checked in it shows the start
/// time, how long the session has run, and a Check out button. When not, it
/// shows a Check in button. Both buttons call the view model, which updates
/// the state from the server's reply.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/home_view_model.dart';

class CheckinCard extends StatelessWidget {
  const CheckinCard({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeViewModel>();
    final record = home.attendance;
    final isOpen = home.isCheckedIn;
    final busy = home.isCheckinLoading;
    final accent = isOpen ? OgeraColors.success : OgeraColors.blue;

    return OgeraCard(
      accent: accent,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isOpen ? Icons.timer_rounded : Icons.login_rounded,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'On field duty' : 'Not checked in',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  record != null && isOpen
                      ? 'Since ${formatTime(record.checkinAt)} · '
                            '${formatDuration(DateTime.now().difference(record.checkinAt))}'
                      : 'Check in when you start your field day',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: OgeraColors.muted,
                  ),
                ),
                if (home.actionError != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Could not update your check-in. Try again.',
                    style: TextStyle(fontSize: 12, color: OgeraColors.danger),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : () => _toggle(home, isOpen),
            child: Text(busy ? '…' : (isOpen ? 'Check out' : 'Check in')),
          ),
        ],
      ),
    );
  }

  /// Checks out when open, otherwise checks in.
  Future<void> _toggle(HomeViewModel home, bool isOpen) async {
    if (isOpen) {
      await home.checkout();
    } else {
      await home.checkin();
    }
  }
}
