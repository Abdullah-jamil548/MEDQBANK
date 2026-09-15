import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_tab.dart';

class McqBankPage extends StatelessWidget {
  const McqBankPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderTab(
      title: 'MCQ Bank',
      subtitle: 'Clinical cases, timed quizzes and explanations — like a ward test.',
      icon: Icons.monitor_heart_outlined,
    );
  }
}
