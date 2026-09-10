import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/contacts_view_model.dart';
import '../view_models/followups_view_model.dart';
import '../view_models/map_view_model.dart';
import '../view_models/professionals_view_model.dart';
import '../view_models/sales_view_model.dart';

/// Carries the shell's module view models onto a pushed route.
///
/// The shell provides Contacts, Professionals, Follow-ups, Map and Sales below
/// the app's Navigator, but a pushed route is built *by* that Navigator — so it
/// is a sibling of the shell, not a descendant, and inherits none of them.
/// Every detail and form screen is reached by a push and needs those models to
/// write back into the list it came from, so the push goes through here.
Future<T?> pushShellRoute<T>(BuildContext context, WidgetBuilder builder) {
  final contacts = _maybeRead<ContactsViewModel>(context);
  final professionals = _maybeRead<ProfessionalsViewModel>(context);
  final followups = _maybeRead<FollowupsViewModel>(context);
  final map = _maybeRead<MapViewModel>(context);
  // Sales is Head-only, so a staff session simply has none to carry.
  final sales = _maybeRead<SalesViewModel>(context);

  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(
      builder: (_) => MultiProvider(
        providers: [
          if (contacts != null) ChangeNotifierProvider.value(value: contacts),
          if (professionals != null)
            ChangeNotifierProvider.value(value: professionals),
          if (followups != null) ChangeNotifierProvider.value(value: followups),
          if (map != null) ChangeNotifierProvider.value(value: map),
          if (sales != null) ChangeNotifierProvider.value(value: sales),
        ],
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// `read` throws when a model is not in scope, which is the normal case for
/// Sales on a staff session and for any model a caller does not depend on.
T? _maybeRead<T>(BuildContext context) {
  try {
    return context.read<T>();
  } on ProviderNotFoundException {
    return null;
  }
}
