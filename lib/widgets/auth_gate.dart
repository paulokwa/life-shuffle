import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/calendar_name_screen.dart';
import '../screens/display_name_screen.dart';
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
      _authSubscription =
          FirebaseAuth.instance.authStateChanges().listen((user) {
        widget.appState.setUserId(user?.uid);
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Widget _mainApp({User? user}) {
    return AppStateScope(
      state: widget.appState,
      child: !widget.appState.displayNameConfirmed
          ? DisplayNameScreen(
              initialName: _defaultDisplayName(user),
              onConfirm: (displayName) {
                final saved = widget.appState.confirmDisplayName(displayName);
                if (saved) {
                  setState(() {});
                }
                return saved;
              },
            )
          : !widget.appState.calendarNameConfirmed
              ? CalendarNameScreen(
                  initialName: _defaultCalendarName(),
                  onConfirm: (calendarName) {
                    final saved =
                        widget.appState.confirmCalendarTitle(calendarName);
                    if (saved) {
                      setState(() {});
                    }
                    return saved;
                  },
                )
              : _onboardingDone
                  ? const BottomNavShell()
                  : OnboardingScreen(
                      onComplete: () => setState(() => _onboardingDone = true),
                    ),
    );
  }

  String _defaultDisplayName(User? user) {
    final saved = widget.appState.displayName?.trim();
    if (saved != null && saved.isNotEmpty) return saved;

    final googleName = user?.displayName?.trim();
    if (googleName != null && googleName.isNotEmpty) return googleName;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Kwame';
  }

  String _defaultCalendarName() {
    final saved = widget.appState.calendarTitle.trim();
    if (saved.isNotEmpty) return saved;
    return 'Kwame and Laura';
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
          return _mainApp(user: snapshot.data);
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
