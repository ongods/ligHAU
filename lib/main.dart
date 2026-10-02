import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const LigHAUApp());
}

class LigHAUApp extends StatelessWidget {
  const LigHAUApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ligHAU',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}
