/// Placeholder for bottom-bar tabs whose screens are built in a later sprint
/// (Tasks in Sprint 2, Pipeline in Sprint 3). It keeps the bar complete now.
library;

import 'package:flutter/material.dart';

import '../../core/widgets/state_views.dart';
import '../../theme/ogera_colors.dart';

class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OgeraColors.canvas,
      appBar: AppBar(title: Text(title)),
      body: EmptyStateView(
        icon: icon,
        title: 'Coming soon',
        message: '$title is being built in an upcoming sprint.',
      ),
    );
  }
}
