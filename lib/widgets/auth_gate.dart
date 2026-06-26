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
  StreamSubscription<User?>? _authSubscription;

  // Cached once so `StreamBuilder` in build() always sees the same stream
  // identity. Calling FirebaseAuth.instance.authStateChanges() fresh inside
  // build() creates a new Stream instance every rebuild, which makes
  // StreamBuilder resubscribe and briefly drop to ConnectionState.waiting
  // (showing _SplashScreen) on every AppState change, not just real auth
  // changes -- that flash unmounts and remounts BottomNavShell, resetting
  // its selected tab back to Today.
  final Stream<User?>? _authStateChanges = AuthService.isReady
      ? FirebaseAuth.instance.authStateChanges()
      : null;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_handleAppStateChanged);
    if (AuthService.isReady) {
      _authSubscription = _authStateChanges!.listen((user) {
        widget.appState.setUserId(
          user?.uid,
          email: user?.email,
          displayName: user?.displayName,
        );
      });
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_handleAppStateChanged);
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState == widget.appState) return;
    oldWidget.appState.removeListener(_handleAppStateChanged);
    widget.appState.addListener(_handleAppStateChanged);
  }

  void _handleAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Widget _mainApp({User? user}) {
    return AppStateScope(
      state: widget.appState,
      child: widget.appState.shouldWaitForInitialSync
          ? const _SplashScreen()
          : !widget.appState.displayNameConfirmed
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
                final saved = widget.appState.confirmCalendarTitle(
                  calendarName,
                );
                if (saved) {
                  setState(() {});
                }
                return saved;
              },
            )
          : widget.appState.introOnboardingCompleted
          ? const BottomNavShell()
          : OnboardingScreen(
              onComplete: widget.appState.completeIntroOnboarding,
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
      stream: _authStateChanges,
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
