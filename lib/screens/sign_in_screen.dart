import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final String? origin = kIsWeb ? Uri.base.origin : null;
    debugPrint('[AuthDebug] sign-in attempt, origin: ${origin ?? 'native'}');
    try {
      await AuthService.signInWithGoogle();
      // AuthGate rebuilds automatically via authStateChanges stream.
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '[AuthDebug] FirebaseAuthException code=${e.code} message=${e.message} origin=${origin ?? 'native'}');
      if (mounted) {
        setState(() {
          _error = _friendlyAuthError(e, origin);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[AuthDebug] unexpected error: $e');
      if (mounted) {
        setState(() {
          _error = 'We couldn\'t sign you in just now. Please try again.';
          _loading = false;
        });
      }
    }
  }

  String _friendlyAuthError(FirebaseAuthException e, [String? origin]) {
    // Dynamic code generated when the API key HTTP-referrer restriction blocks the request.
    if (e.code.startsWith('requests-from-referer-') &&
        e.code.endsWith('-are-blocked')) {
      return 'Sign-in is not available from this address. Try the usual Life Shuffle link or contact the app owner.';
    }
    return switch (e.code) {
      'unauthorized-domain' =>
        'Sign-in is not available from this address. Try the usual Life Shuffle link.',
      'popup-blocked' =>
        'Your browser blocked the Google sign-in window. Allow pop-ups, then try again.',
      'popup-closed-by-user' => 'Sign-in was cancelled before Google finished.',
      'operation-not-allowed' =>
        'Google sign-in is temporarily unavailable. Please try again later.',
      _ => 'We couldn\'t sign you in just now. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(),
              // Logo
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryTerracotta.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shuffle_rounded,
                  size: 32,
                  color: primaryTerracotta,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Life Shuffle',
                style: GoogleFonts.lora(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A calm way to plan your week together.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: textMuted,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryTerracotta.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: primaryTerracotta,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              GestureDetector(
                onTap: _loading ? null : _signIn,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _loading
                        ? primaryTerracotta.withValues(alpha: 0.6)
                        : primaryTerracotta,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.login_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Continue with Google',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Your plan, synced across devices.',
                style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
