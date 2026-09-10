import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/ogera_widgets.dart';
import '../../models/followup.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/followups_view_model.dart';

/// Head-only pipeline editor: add a stage, rename one, or reorder the board.
Future<void> showManageStages(BuildContext context) {
  final viewModel = context.read<FollowupsViewModel>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: viewModel,
      child: const _ManageStagesSheet(),
    ),
  );
}

class _ManageStagesSheet extends StatefulWidget {
  const _ManageStagesSheet();

  @override
  State<_ManageStagesSheet> createState() => _ManageStagesSheetState();
}

class _ManageStagesSheetState extends State<_ManageStagesSheet> {
  bool _isBusy = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _isBusy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (error != null) showToast(context, error, isError: true);
  }

  Future<void> _addStage() async {
    final label = await _promptForLabel(title: 'New stage');
    if (label == null || !mounted) return;
    await _run(() => context.read<FollowupsViewModel>().createStage(label));
  }

  Future<void> _renameStage(Stage stage) async {
    final label = await _promptForLabel(
      title: 'Rename stage',
      initial: stage.label,
    );
    if (label == null || !mounted) return;
    await _run(
      () => context.read<FollowupsViewModel>().renameStage(stage.id, label),
    );
  }

  Future<String?> _promptForLabel({required String title, String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Stage name',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// Reordering writes a new `orderIndex` for every stage that shifted, because
  /// the API updates one stage at a time.
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final viewModel = context.read<FollowupsViewModel>();
    final stages = [...viewModel.stages];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = stages.removeAt(oldIndex);
    stages.insert(newIndex, moved);

    setState(() => _isBusy = true);
    String? failure;
    for (var index = 0; index < stages.length; index++) {
      if (stages[index].orderIndex == index) continue;
      failure = await viewModel.reorderStage(stages[index].id, index);
      if (failure != null) break;
    }
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (failure != null) showToast(context, failure, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final stages = context.watch<FollowupsViewModel>().stages;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Pipeline stages',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isBusy ? null : _addStage,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Drag to reorder. Leads keep their stage when the board changes.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: OgeraColors.muted,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (_isBusy) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              itemCount: stages.length,
              onReorder: _reorder,
              itemBuilder: (context, index) {
                final stage = stages[index];
                return Padding(
                  key: ValueKey(stage.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: OgeraCard(
                    accent: stage.color,
                    padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stage.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                stage.id,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: OgeraColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Rename',
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: _isBusy ? null : () => _renameStage(stage),
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.drag_handle_rounded,
                              color: OgeraColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
