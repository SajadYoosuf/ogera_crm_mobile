/// Sheets opened from the shell's centre quick-action button.
///
/// Activity log: pick a contact, then fill in the activity and save.
/// Add expense: fill in the claim and submit it for review.
///
/// Both sheets are opened through [showShellSheet] so they can use the shell's
/// view models. The rules they check mirror the backend, which still decides.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/ogera_widgets.dart';
import '../../core/widgets/state_views.dart';
import '../../models/activity_log.dart';
import '../../models/contact.dart';
import '../../models/expense.dart';
import '../../services/activity_service.dart';
import '../../services/crm_services.dart';
import '../../theme/ogera_colors.dart';
import '../../view_models/expense_view_model.dart';
import '../shell_scope.dart';

/// Used when the Settings list cannot be loaded, so the picker is never empty.
/// Same seed values as the backend's `DEFAULT_ENUMS[ACTIVITY_TYPE]`.
const _fallbackActivityTypes = {
  'phone_call': 'Phone call',
  'field_visit': 'Field visit',
  'whatsapp': 'WhatsApp',
  'meeting': 'Meeting',
  'email': 'Email',
  'demo': 'Demo',
  'internal_note': 'Internal note',
  'other': 'Other',
};

/// Flow: contact picker, then the activity form. Shows a confirmation when saved.
Future<void> openActivityLog(BuildContext context) async {
  final contact = await showShellSheet<Contact>(
    context,
    (_) => const _ContactPickerSheet(),
  );
  if (contact == null || !context.mounted) return;

  final saved = await showShellSheet<bool>(
    context,
    (_) => ActivityLogSheet(contact: contact),
  );
  if (saved == true && context.mounted) {
    _showSavedMessage(context, 'Activity logged');
  }
}

/// Opens the expense form. Only staff see this button (see the shell).
Future<void> openExpenseAdd(BuildContext context) async {
  final saved = await showShellSheet<bool>(
    context,
    (_) => const ExpenseAddSheet(),
  );
  if (saved == true && context.mounted) {
    _showSavedMessage(context, 'Expense submitted for review');
  }
}

void _showSavedMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

// ───────────────────────────────────────────────────────── contact picker

/// Searches contacts and returns the one the user taps.
/// Results come from `GET /contacts`, so the server already applies visibility.
class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet();

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  String? _error;
  List<Contact> _contacts = const [];

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing before searching, to save network calls.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(value.trim()),
    );
  }

  /// Loads matching contacts. Errors are stored and shown with a retry button.
  Future<void> _search(String query) async {
    final service = context.read<ContactsService>();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final contacts = await service.search(query);
      if (mounted) setState(() => _contacts = contacts);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Log activity for…',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: OgeraSearchField(
              controller: _controller,
              hint: 'Search contact name or phone',
              onChanged: _onQueryChanged,
            ),
          ),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  Widget _results() {
    if (_isLoading) return const LoadingListView(itemCount: 4, itemHeight: 64);
    if (_error != null) {
      return ErrorStateView(
        message: _error!,
        onRetry: () => _search(_controller.text.trim()),
      );
    }
    if (_contacts.isEmpty) {
      return const EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'No contacts found',
        message: 'Try a different name or phone number.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 28),
      itemCount: _contacts.length,
      separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          onTap: () => Navigator.of(context).pop(contact),
          leading: const Icon(Icons.person_rounded, color: OgeraColors.blue),
          title: Text(
            contact.displayName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            contact.phone,
            style: const TextStyle(fontSize: 12.5, color: OgeraColors.muted),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: OgeraColors.muted,
          ),
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────── activity form

/// Form for one activity on [contact]. Returns `true` when it is saved.
///
/// Required by the backend: an activity type and non-blank notes.
/// The time is set by the server, so the form has no date field.
class ActivityLogSheet extends StatefulWidget {
  const ActivityLogSheet({super.key, required this.contact});

  final Contact contact;

  @override
  State<ActivityLogSheet> createState() => _ActivityLogSheetState();
}

class _ActivityLogSheetState extends State<ActivityLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  late final Future<Map<String, String>> _typesFuture;
  String? _activityType;
  ActivityOutcome? _outcome;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The list comes from Settings (`activity_type`); the fallback covers
    // a failed request, so the dropdown always has choices.
    final api = context.read<ApiClient>();
    _typesFuture = SettingsOptionsCatalog.of(
      api,
    ).options('activity_type', fallback: _fallbackActivityTypes);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Validates the form, then saves the activity.
  /// On success the sheet closes with `true`; on failure it stays open.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final service = context.read<ActivityService>();
    final draft = ActivityDraft(
      activityType: _activityType!,
      notes: _notesController.text,
      title: _titleController.text,
      outcome: _outcome,
    );
    try {
      await service.log(widget.contact.id, draft);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _fail(error.message);
    } catch (_) {
      _fail(
        'Could not save the activity. Check your connection and try again.',
      );
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              widget.contact.displayName,
              style: const TextStyle(fontSize: 13, color: OgeraColors.muted),
            ),
            const SizedBox(height: 16),
            _typeField(),
            const SizedBox(height: 14),
            const Text(
              'Outcome',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final outcome in ActivityOutcome.values)
                  ChoiceChip(
                    label: Text(outcome.label),
                    selected: _outcome == outcome,
                    onSelected: _isSaving
                        ? null
                        : (on) =>
                              setState(() => _outcome = on ? outcome : null),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              enabled: !_isSaving,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notesController,
              enabled: !_isSaving,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Write what happened' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: OgeraColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Saving…' : 'Save activity'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dropdown of activity types. Shows a placeholder while the list loads.
  Widget _typeField() {
    return FutureBuilder<Map<String, String>>(
      future: _typesFuture,
      builder: (context, snapshot) {
        final types = snapshot.data;
        if (types == null) return const ShimmerBox(height: 56);
        return DropdownButtonFormField<String>(
          initialValue: _activityType,
          decoration: const InputDecoration(labelText: 'Activity type'),
          items: [
            for (final entry in types.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _activityType = value),
          validator: (value) => value == null ? 'Pick an activity type' : null,
        );
      },
    );
  }
}

// ───────────────────────────────────────────────────────── expense form

/// Form for one expense claim. Returns `true` when it is submitted.
///
/// Required by the backend: a title (1–200 characters), a category, and an
/// amount above 0 with at most 2 decimal places. Admin and manager accounts
/// cannot submit claims, so the shell does not offer this sheet to them.
class ExpenseAddSheet extends StatefulWidget {
  const ExpenseAddSheet({super.key});

  @override
  State<ExpenseAddSheet> createState() => _ExpenseAddSheetState();
}

class _ExpenseAddSheetState extends State<ExpenseAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  ExpenseCategory _category = ExpenseCategory.petrol;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  /// Validates, then submits the claim through [ExpenseViewModel].
  /// The view model keeps its own error text, so the sheet shows a plain message.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });
    final viewModel = context.read<ExpenseViewModel>();
    final draft = ExpenseDraft(
      title: _titleController.text.trim(),
      category: _category,
      amount: double.parse(_amountController.text.trim()),
    );
    final saved = await viewModel.create(draft);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _error =
            'Could not submit the expense. Check your connection and try again.';
      });
    }
  }

  /// Amount must be a number above 0 with at most 2 decimal places.
  String? _validateAmount(String? value) {
    final text = (value ?? '').trim();
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) return 'Enter an amount above 0';
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)) {
      return 'Use at most 2 decimal places';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add expense', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              enabled: !_isSaving,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'What was it for?'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Enter a short title';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<ExpenseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in ExpenseCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(category.label),
                  ),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountController,
              enabled: !_isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
              validator: _validateAmount,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: OgeraColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Text(_isSaving ? 'Submitting…' : 'Submit expense'),
            ),
          ],
        ),
      ),
    );
  }
}
