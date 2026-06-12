import 'package:flutter/material.dart';
import 'theme/app_theme.dart' show buildAppTheme;
import 'state/app_state.dart';
import 'services/persistence_service.dart';
import 'services/planner_service.dart';
import 'screens/onboarding_screen.dart';
import 'widgets/bottom_nav_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PersistenceService.init();

  final ids = PlannerService.defaultActivities.map((a) => a.id).toList();
  final saved = PersistenceService.load(ids);

  final appState = AppState(
    activities: PlannerService.defaultActivities,
    savedState: saved,
  );

  runApp(LifeShuffleApp(appState: appState));
}

class LifeShuffleApp extends StatelessWidget {
  const LifeShuffleApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Shuffle',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _RootRouter(appState: appState),
    );
  }
}

class _RootRouter extends StatefulWidget {
  const _RootRouter({required this.appState});

  final AppState appState;

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _onboardingDone = false;

  @override
  void dispose() {
    widget.appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_onboardingDone) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingDone = true),
      );
    }
    return AppStateScope(
      state: widget.appState,
      child: const BottomNavShell(),
    );
  }
}
