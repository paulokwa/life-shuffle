import 'package:flutter/material.dart';
import 'theme/app_theme.dart' show buildAppTheme;
import 'screens/onboarding_screen.dart';
import 'widgets/bottom_nav_shell.dart';

void main() {
  runApp(const LifeShuffleApp());
}

class LifeShuffleApp extends StatelessWidget {
  const LifeShuffleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Shuffle',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _onboardingDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_onboardingDone) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }
    return const BottomNavShell();
  }
}
