import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/persistence_service.dart';
import 'services/planner_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart' show buildAppTheme;
import 'widgets/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const localOnly = bool.fromEnvironment('LS_LOCAL_ONLY');
  if (!localOnly) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      AuthService.markReady();
    } catch (_) {
      // Firebase not configured yet. The app runs in local-only mode.
      // Replace lib/firebase_options.dart by running: flutterfire configure.
    }
  }

  await PersistenceService.init();

  final saved = PersistenceService.load(PlannerService.defaultActivities);

  final appState = AppState(
    activities: saved.activities,
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
      home: AuthGate(appState: appState),
    );
  }
}
