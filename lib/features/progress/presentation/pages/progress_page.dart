import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_tab.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      title: 'Progress',
      subtitle: 'Detailed subject-wise analytics will appear here.',
      icon: Icons.insights_rounded,
    );
  }
}
