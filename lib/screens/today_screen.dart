import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/mock_data.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/activity_plan_card.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LifeShuffleHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GreetingBlock(),
                  const SizedBox(height: 16),
                  _NextUpCard(),
                  const SizedBox(height: 12),
                  _CheckInCard(),
                  const SizedBox(height: 12),
                  _ThisWeekCard(),
                  const SizedBox(height: 16),
                  _QuickActionsSection(),
                  const SizedBox(height: 16),
                  _TodaysPlanSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Greeting block ──────────────────────────────────────────────────────────

class _GreetingBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today',
          style: GoogleFonts.lora(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            color: textPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          todayDate,
          style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
        ),
      ],
    );
  }
}

// ─── Next up card ─────────────────────────────────────────────────────────────

class _NextUpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryTerracotta,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.20),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.waves_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT UP',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                    color: Colors.white.withOpacity(0.70),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nextUpTitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  nextUpTime,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.80),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Quick check-in card ──────────────────────────────────────────────────────

class _CheckInCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEEF6F2),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '◐',
                  style: TextStyle(fontSize: 16, color: accentSage),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3 past activities need a quick check-in',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No typing needed — just tap to mark how it went.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PillButton(
                  label: 'Check in',
                  background: accentSage,
                  textColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillButton(
                  label: 'Later',
                  background: Colors.transparent,
                  textColor: textMuted,
                  hasBorder: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.background,
    required this.textColor,
    this.hasBorder = false,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(100),
          border: hasBorder ? Border.all(color: borderWarmStrong) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

// ─── This week summary ────────────────────────────────────────────────────────

class _ThisWeekCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.0,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCell(
                value: '$weekPlanned',
                label: 'Planned',
                valueColor: textPrimary,
              ),
              _StatCell(
                value: '$weekDone',
                label: 'Done',
                valueColor: accentSage,
              ),
              _StatCell(
                value: '$weekPartly',
                label: 'Partly',
                valueColor: sand,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(value: 0.40),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: valueColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final filled = total * value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: warmBeige)),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: filled,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentSage, sand],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Quick actions ────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  const _QuickActionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                label: 'Add activity',
                icon: Icons.add_rounded,
                accentColor: primaryTerracotta,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickActionCard(
                label: 'Generate week',
                icon: Icons.bolt_rounded,
                accentColor: accentSage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                label: 'View plan',
                icon: Icons.calendar_today_rounded,
                accentColor: dustySky,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: QuickActionCard(
                label: 'View progress',
                icon: Icons.trending_up_rounded,
                accentColor: mauve,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Today's plan ─────────────────────────────────────────────────────────────

class _TodaysPlanSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "TODAY'S PLAN",
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                color: textMuted,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                'See all',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primaryTerracotta,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...todayActivities.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ActivityPlanCard(activity: a),
          ),
        ),
      ],
    );
  }
}
