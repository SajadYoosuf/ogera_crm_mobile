import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../models/staff_location.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/map_view_model.dart';

/// The staff list that sits over the head map.
///
/// It is a draggable sheet rather than a fixed panel so the map keeps most of
/// the screen at rest, and the whole team is one drag away. Rows are ordered
/// Live first, then by how recently each person reported.
class StaffSheet extends StatelessWidget {
  const StaffSheet({super.key, required this.onSelect, required this.onFocus});

  /// Opens the route sheet for that staff member.
  final ValueChanged<StaffLocation> onSelect;

  /// Centres the map on them without leaving the list.
  final ValueChanged<StaffLocation> onFocus;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MapViewModel>();
    final staff = viewModel.staffLocations;

    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.16,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.3, 0.85],
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: OgeraColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1F0B2942),
                blurRadius: 22,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            children: [
              const _DragHandle(),
              _SheetHeader(
                total: staff.length,
                live: viewModel.liveCount,
                onSearch: viewModel.searchStaff,
              ),
              Expanded(
                child: staff.isEmpty
                    ? _EmptyStaff(liveOnly: viewModel.liveOnly)
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                        itemCount: staff.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => StaffRow(
                          staff: staff[index],
                          isSelected:
                              staff[index].userId == viewModel.selectedStaffId,
                          onTrace: () => onSelect(staff[index]),
                          onFocus: () => onFocus(staff[index]),
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

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        color: OgeraColors.line,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetHeader extends StatefulWidget {
  const _SheetHeader({
    required this.total,
    required this.live,
    required this.onSearch,
  });

  final int total;
  final int live;
  final ValueChanged<String> onSearch;

  @override
  State<_SheetHeader> createState() => _SheetHeaderState();
}

class _SheetHeaderState extends State<_SheetHeader> {
  final _controller = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Field staff',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.live} moving of ${widget.total}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: OgeraColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _isSearching ? 'Close search' : 'Search staff',
                icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded,
                ),
                onPressed: () {
                  setState(() => _isSearching = !_isSearching);
                  if (!_isSearching) {
                    _controller.clear();
                    widget.onSearch('');
                  }
                },
              ),
            ],
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
              child: OgeraSearchField(
                controller: _controller,
                hint: 'Search staff by name',
                onChanged: widget.onSearch,
              ),
            ),
        ],
      ),
    );
  }
}

/// One staff member: identity colour, state, when they last reported, and the
/// address they are at right now.
class StaffRow extends StatelessWidget {
  const StaffRow({
    super.key,
    required this.staff,
    required this.isSelected,
    required this.onTrace,
    required this.onFocus,
  });

  final StaffLocation staff;
  final bool isSelected;
  final VoidCallback onTrace;
  final VoidCallback onFocus;

  @override
  Widget build(BuildContext context) {
    final state = staff.state;
    return OgeraCard(
      accent: staff.color,
      onTap: onFocus,
      padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
      margin: isSelected ? null : EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OgeraAvatar(name: staff.name, size: 40, color: staff.color),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      staff.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusChip(
                          label: state.label,
                          color: state.color,
                          icon: state.icon,
                          dense: true,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            staff.lastSeenLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: OgeraColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onTrace,
                icon: const Icon(Icons.route_rounded, size: 17),
                label: const Text('Trace'),
                style: TextButton.styleFrom(
                  foregroundColor: staff.color,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.place_outlined,
                size: 14,
                color: OgeraColors.muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  staff.address ?? 'Address unavailable',
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: OgeraColors.muted,
                  ),
                ),
              ),
              if (staff.batteryLevel != null) ...[
                const SizedBox(width: 8),
                Icon(
                  staff.batteryLevel! <= 20
                      ? Icons.battery_alert_rounded
                      : Icons.battery_full_rounded,
                  size: 13,
                  color: staff.batteryLevel! <= 20
                      ? OgeraColors.danger
                      : OgeraColors.muted,
                ),
                const SizedBox(width: 3),
                Text(
                  '${staff.batteryLevel}%',
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
    );
  }
}

class _EmptyStaff extends StatelessWidget {
  const _EmptyStaff({required this.liveOnly});

  final bool liveOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: OgeraColors.blueSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_pin_circle_outlined,
              size: 29,
              color: OgeraColors.blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            liveOnly ? 'Nobody is moving right now' : 'No staff locations yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            liveOnly
                ? 'Turn off the Moving only filter to see everyone, including staff '
                      'who last reported earlier today.'
                : 'Locations appear here once your Sales Staff sign in and allow '
                      'location sharing.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: OgeraColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
