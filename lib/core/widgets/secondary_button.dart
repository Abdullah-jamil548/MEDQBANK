import 'package:flutter/material.dart';

import '../responsive/app_responsive.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: context.rs.buttonHeight,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
