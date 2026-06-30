import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ls_card.dart';

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
          'Make a plan from your activities and rules. Shuffle the unlocked parts whenever you want a fresh mix.',
      icon: Icons.bolt_rounded,
      accentColor: sand,
    ),
    _OnboardingStep(
      title: 'Check in as\nyou go',
      body:
          'Mark activities done, partly done, or skipped — no typing needed. Look back gently at what worked for you.',
      icon: Icons.check_circle_outline_rounded,
      accentColor: dustySky,
    ),
  ];

  static const _dimensionsStep = _OnboardingStep(
    title: 'Choose planning\ndetails',
    body:
        'Life Shuffle can use a few extra details to make plans feel more realistic. You can change these later in Settings.',
    icon: Icons.tune_rounded,
    accentColor: primaryTerracotta,
  );

  int get _lastPage => _steps.length;

  void _next() {
    if (_page < _lastPage) {
      setState(() => _page++);
    } else {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDimensionsPage = _page == _lastPage;
    final step = isDimensionsPage ? _dimensionsStep : _steps[_page];
    final isLast = _page == _lastPage;

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
            Expanded(
              child: isDimensionsPage
                  ? _DimensionsStepBody(step: step)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                      ],
                    ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _lastPage + 1,
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

class _DimensionsStepBody extends StatelessWidget {
  const _DimensionsStepBody({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
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
          const SizedBox(height: 24),
          LsCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _OnboardingDimensionRow(
                  icon: Icons.speed_rounded,
                  label: 'Difficulty',
                  helper: 'Helps avoid stacking too many hard activities.',
                  value: state.difficultyEnabled,
                  onChanged: state.setDifficultyEnabled,
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: borderWarm,
                  indent: 16,
                  endIndent: 16,
                ),
                _OnboardingDimensionRow(
                  icon: Icons.battery_4_bar_rounded,
                  label: 'Energy',
                  helper:
                      'Helps match activities to low, medium, or high energy days.',
                  value: state.energyEnabled,
                  onChanged: state.setEnergyEnabled,
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: borderWarm,
                  indent: 16,
                  endIndent: 16,
                ),
                _OnboardingDimensionRow(
                  icon: Icons.groups_2_rounded,
                  label: 'Social',
                  helper:
                      'Helps mark activities as solo, together, group, or either.',
                  value: state.socialEnabled,
                  onChanged: state.setSocialEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingDimensionRow extends StatelessWidget {
  const _OnboardingDimensionRow({
    required this.icon,
    required this.label,
    required this.helper,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String helper;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: warmBeige,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: primaryTerracotta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  helper,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.25,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeThumbColor: primaryTerracotta,
            activeTrackColor: primaryTerracotta.withValues(alpha: 0.32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
