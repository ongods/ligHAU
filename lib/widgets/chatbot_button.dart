import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChatbotButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ChatbotButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.smart_toy, color: AppColors.onPrimary),
    );
  }
}
