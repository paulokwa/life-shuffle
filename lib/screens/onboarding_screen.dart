import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  static const _steps = [
    _OnboardingStep(
      title: 'Your calm\nplanning partner',
      body:
          'Life Shuffle helps you and Laura build a week full of things you actually want to do — without the mental load.',
      icon: Icons.auto_awesome_rounded,
      accentColor: primaryTerracotta,
    ),
    _OnboardingStep(
      title: 'Add the activities\nyou love',
      body:
          'Build your own library of activities — from walks in the park to cosy nights in. We\'ll take it from there.',
      icon: Icons.format_list_bulleted_rounded,
      accentColor: accentSage,
    ),
    _OnboardingStep(
      title: 'Get a week plan\nin seconds',
      body:
          'Tap Shuffle and we\'ll put together a balanced, varied plan. Swap anything that doesn\'t feel right.',
      icon: Icons.bolt_rounded,
      accentColor: sand,
    ),
    _OnboardingStep(
      title: 'Check in as\nyou go',
      body:
          'Mark activities done, partly done, or skipped — no typing needed. See your progress build over time.',
      icon: Icons.check_circle_outline_rounded,
      accentColor: dustySky,
    ),
  ];

  void _next() {
    if (_page < _steps.length - 1) {
      setState(() => _page++);
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_page];
    final isLast = _page == _steps.length - 1;

    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo / wordmark row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryTerracotta.withOpacity(0.12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.shuffle_rounded,
                      size: 16,
                      color: primaryTerracotta,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Life Shuffle',
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Icon circle
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Container(
                key: ValueKey(_page),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.accentColor.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  step.icon,
                  size: 44,
                  color: step.accentColor,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Title + body
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_page),
                  children: [
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lora(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      step.body,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: textMuted,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? primaryTerracotta : warmBeige,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: _next,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: primaryTerracotta,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isLast ? 'Get started' : 'Next',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            if (!isLast) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: widget.onComplete,
                child: Text(
                  'Skip',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: textMuted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final String title;
  final String body;
  final IconData icon;
  final Color accentColor;

  const _OnboardingStep({
    required this.title,
    required this.body,
    required this.icon,
    required this.accentColor,
  });
}
