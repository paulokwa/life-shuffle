import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/onboarding_screen.dart';
import '../screens/sign_in_screen.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import 'bottom_nav_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.appState});

  final AppState appState;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _onboardingDone = false;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (AuthService.isReady) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        widget.appState.setUserId(user?.uid);
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    // widget.appState.dispose(); // AppState is a ChangeNotifier but not managed here
    super.dispose();
  }

  Widget _mainApp() {
    return AppStateScope(
      state: widget.appState,
      child: _onboardingDone
          ? const BottomNavShell()
          : OnboardingScreen(
              onComplete: () => setState(() => _onboardingDone = true),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Firebase not configured yet — skip auth and run in local-only mode.
    if (!AuthService.isReady) {
      return _mainApp();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }
        if (snapshot.hasData) {
          return _mainApp();
        }
        return const SignInScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: backgroundCream,
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryTerracotta,
          ),
        ),
      ),
    );
  }
}
