import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../view_models/contacts_view_model.dart';
import '../view_models/expense_view_model.dart';
import '../view_models/followups_view_model.dart';
import '../view_models/home_view_model.dart';
import '../view_models/professionals_view_model.dart';

/// Carries the shell's module view models onto a pushed route or a sheet.
///
/// The shell provides Contacts, Professionals, Follow-ups, Home and Expenses
/// below the app's Navigator, but a pushed route or a bottom sheet is built *by*
/// that Navigator — so it is a sibling of the shell, not a descendant, and
/// inherits none of them. Every detail, form and sheet that writes back into
/// one of those lists goes through the helpers below.
Future<T?> pushShellRoute<T>(BuildContext context, WidgetBuilder builder) {
  final providers = _shellProviders(context);
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(builder: (_) => _withProviders(providers, builder)),
  );
}

/// Shows a bottom sheet that can read the shell's view models, such as the
/// expense form (which saves through [ExpenseViewModel]).
Future<T?> showShellSheet<T>(BuildContext context, WidgetBuilder builder) {
  final providers = _shellProviders(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _withProviders(providers, builder),
  );
}

/// Reads each shell model that is in scope and wraps it for the new route.
/// Missing models are skipped, so a caller outside the shell still works.
List<SingleChildWidget> _shellProviders(BuildContext context) {
  final contacts = _maybeRead<ContactsViewModel>(context);
  final professionals = _maybeRead<ProfessionalsViewModel>(context);
  final followups = _maybeRead<FollowupsViewModel>(context);
  final home = _maybeRead<HomeViewModel>(context);
  final expenses = _maybeRead<ExpenseViewModel>(context);

  return [
    if (contacts != null) ChangeNotifierProvider.value(value: contacts),
    if (professionals != null)
      ChangeNotifierProvider.value(value: professionals),
    if (followups != null) ChangeNotifierProvider.value(value: followups),
    if (home != null) ChangeNotifierProvider.value(value: home),
    if (expenses != null) ChangeNotifierProvider.value(value: expenses),
  ];
}

/// Puts the carried providers above the route's own widget tree.
Widget _withProviders(
  List<SingleChildWidget> providers,
  WidgetBuilder builder,
) {
  return MultiProvider(
    providers: providers,
    child: Builder(builder: builder),
  );
}

/// `read` throws when a model is not in scope, which is the normal case for
/// any model a caller does not depend on.
T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
