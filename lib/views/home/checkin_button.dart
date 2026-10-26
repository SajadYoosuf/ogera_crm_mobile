/// Field check-in card for the Home tab.
///
/// Layout, top to bottom:
///   1. Header: a check-in icon, the title, and a status chip.
///   2. The Check in / Check out button, centred under the header.
///   3. A centred line that depends on today's status:
///        not started → "You haven't started your field work today"
///        on field    → the current address (first two words) and a tiny
///                      refresh button on the right
///        completed   → "Today's field visit completed"
///
/// The card only reads [HomeViewModel]. The view model decides the status
/// ([HomeViewModel.fieldDayStatus]); this widget just draws it, so the screen
/// can never disagree with the data.
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
    final status = home.fieldDayStatus;
    final style = _StatusStyle.of(status);

    return OgeraCard(
      accent: style.color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(home: home, style: style),
          const SizedBox(height: 16),
          if (status == FieldDayStatus.notStarted ||
              status == FieldDayStatus.onField)
            _ToggleButton(home: home, status: status, style: style),
          const SizedBox(height: 12),
          _CentreLine(home: home, status: status),
          if (home.actionError != null) ...[
            const SizedBox(height: 10),
            Text(
              home.actionError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: OgeraColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Colour, icon and chip wording for each status, in one place.
class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.color,
    required this.icon,
    required this.tone,
  });

  final String label;
  final Color color;
  final IconData icon;
  final StatusTone tone;

  static _StatusStyle of(FieldDayStatus status) => switch (status) {
    FieldDayStatus.loading => const _StatusStyle(
      label: 'Checking',
      color: OgeraColors.muted,
      icon: Icons.hourglass_empty_rounded,
      tone: StatusTone.neutral,
    ),
    FieldDayStatus.error => const _StatusStyle(
      label: 'Unavailable',
      color: OgeraColors.danger,
      icon: Icons.error_outline_rounded,
      tone: StatusTone.danger,
    ),
    FieldDayStatus.notStarted => const _StatusStyle(
      label: 'Not started',
      color: OgeraColors.forestInteractive,
      icon: Icons.login_rounded,
      tone: StatusTone.neutral,
    ),
    FieldDayStatus.onField => const _StatusStyle(
      label: 'On field duty',
      color: OgeraColors.success,
      icon: Icons.timer_rounded,
      tone: StatusTone.success,
    ),
    FieldDayStatus.completed => const _StatusStyle(
      label: 'Visit completed',
      color: OgeraColors.info,
      icon: Icons.task_alt_rounded,
      tone: StatusTone.info,
    ),
  };
}

// ─────────────────────────────────────────────────────────────────────────────

/// Top row: the check-in icon, the title with a short subtitle, and the chip.
class _Header extends StatelessWidget {
  const _Header({required this.home, required this.style});

  final HomeViewModel home;
  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [OgeraColors.forest, OgeraColors.forestInteractive],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: OgeraColors.forest.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(style.icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Field check-in',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                _subtitle(home),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: OgeraColors.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusChip(label: style.label, tone: style.tone, icon: style.icon),
      ],
    );
  }

  /// The small grey line under the title. Times come from the server record.
  String _subtitle(HomeViewModel home) {
    final record = home.attendance;
    return switch (home.fieldDayStatus) {
      FieldDayStatus.loading => 'Loading today’s status',
      FieldDayStatus.error => 'Could not load today’s status',
      FieldDayStatus.notStarted => 'Check in when you start your field day',
      FieldDayStatus.onField when record != null =>
        'Since ${formatTime(record.checkinAt)} · '
            '${formatDuration(DateTime.now().difference(record.checkinAt))}',
      FieldDayStatus.completed when record != null =>
        'In ${formatTime(record.checkinAt)}'
            '${record.checkoutAt == null ? '' : ' · Out ${formatTime(record.checkoutAt!)}'}',
      _ => '',
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// The one main action: Check in when not started, Check out while on field.
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.home,
    required this.status,
    required this.style,
  });

  final HomeViewModel home;
  final FieldDayStatus status;
  final _StatusStyle style;

  @override
  Widget build(BuildContext context) {
    final busy = home.isCheckinLoading;
    final onField = status == FieldDayStatus.onField;

    return FilledButton.icon(
      onPressed: busy ? null : () => onField ? home.checkout() : home.checkin(),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: style.color,
      ),
      icon: Icon(
        onField ? Icons.logout_rounded : Icons.login_rounded,
        size: 18,
      ),
      label: Text(busy ? '…' : (onField ? 'Check out' : 'Check in')),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// The centred line under the button. Its content follows the status.
class _CentreLine extends StatelessWidget {
  const _CentreLine({required this.home, required this.status});

  final HomeViewModel home;
  final FieldDayStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      FieldDayStatus.loading => const _CentredText(
        'Checking today’s status…',
        color: OgeraColors.muted,
      ),
      FieldDayStatus.error => _ErrorLine(home: home),
      FieldDayStatus.notStarted => const _CentredText(
        'You haven’t started your field work today',
        color: OgeraColors.muted,
      ),
      FieldDayStatus.onField => _LocationLine(home: home),
      FieldDayStatus.completed => const _CompletedLine(),
    };
  }
}

/// On field: the address, with a tiny refresh button on the right.
class _LocationLine extends StatelessWidget {
  const _LocationLine({required this.home});

  final HomeViewModel home;

  @override
  Widget build(BuildContext context) {
    final loading = home.isLocationLoading;
    final address = home.locationLabel;
    final syncText = home.isLocationSyncing
        ? 'Syncing location'
        : home.pendingLocationCount > 0
        ? '${home.pendingLocationCount} location pending'
        : null;
    final text =
        address ??
        (home.locationFailed
            ? 'Could not read your location'
            : (loading ? 'Locating…' : 'Location not available yet'));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.place_rounded, size: 16, color: OgeraColors.success),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              if (syncText != null)
                Text(
                  syncText,
                  style: const TextStyle(fontSize: 11, color: OgeraColors.warning),
                ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        IconButton(
          tooltip: 'Location details',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          iconSize: 16,
          color: OgeraColors.muted,
          onPressed: loading ? null : () => _showLocationDetails(context, home),
          icon: loading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }
}

Future<void> _showLocationDetails(BuildContext context, HomeViewModel home) async {
  await home.loadLocationHistory();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LocationDetailsSheet(home: home),
  );
}

class _LocationDetailsSheet extends StatelessWidget {
  const _LocationDetailsSheet({required this.home});

  final HomeViewModel home;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Location details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                home.isLocationSyncing
                    ? 'Syncing a location…'
                    : home.pendingLocationCount > 0
                    ? '${home.pendingLocationCount} pending locally'
                    : 'No pending local locations',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              const Text(
                'Server history — today',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(child: _serverHistory(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serverHistory(BuildContext context) {
    if (home.isLocationHistoryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (home.locationHistoryError != null) {
      return Center(child: Text(home.locationHistoryError!));
    }
    if (home.locationHistory.isEmpty) {
      return const Center(child: Text('No locations received by the server today.'));
    }
    return ListView.separated(
      itemCount: home.locationHistory.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final point =
            home.locationHistory[home.locationHistory.length - index - 1];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined, color: Colors.green),
          title: Text(formatMoment(point.recordedAt)),
          subtitle: Text(
            '${point.latitude.toStringAsFixed(6)}, '
            '${point.longitude.toStringAsFixed(6)}',
          ),
          trailing: const Text(
            'Saved',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        );
      },
    );
  }
}

/// Checked out: the day is finished.
class _CompletedLine extends StatelessWidget {
  const _CompletedLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: OgeraColors.success),
        SizedBox(width: 6),
        Text(
          'Today’s field visit completed',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Could not load today's record: say so, and offer a retry.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.home});

  final HomeViewModel home;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CentredText(
          home.attendanceError ?? 'Could not load today’s status',
          color: OgeraColors.danger,
        ),
        TextButton(
          onPressed: () => home.refreshAttendance(),
          child: const Text('Try again'),
        ),
      ],
    );
  }
}

class _CentredText extends StatelessWidget {
  const _CentredText(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: color),
    );
  }
}
