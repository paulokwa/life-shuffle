import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/activity_plan_card.dart';
import 'check_in_one_by_one_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.now});

  /// Override for [DateTime.now] used by the check-in prompt's past-unchecked
  /// check, so tests are deterministic regardless of which real weekday they
  /// run on. Defaults to the real clock in production.
  final DateTime? now;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  // Returns true if the time slot is still upcoming or within a 1-hour grace
  // period, so an activity planned at 3 PM still shows as Next Up at 3:45 PM
  // but not at 7:37 PM.
  static bool _isUpcoming(String timeSlot) {
    final parts = timeSlot.split(' ');
    if (parts.length != 2) return true;
    final timeParts = parts[0].split(':');
    if (timeParts.length != 2) return true;
    int hour = int.tryParse(timeParts[0]) ?? 0;
    final minute = int.tryParse(timeParts[1]) ?? 0;
    final isPm = parts[1].toUpperCase() == 'PM';
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    final now = DateTime.now();
    final slot = DateTime(now.year, now.month, now.day, hour, minute);
    return now.isBefore(slot.add(const Duration(hours: 1)));
  }

  static String _formattedDate() {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  void _openOneByOneReview(AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckInOneByOneScreen(appState: state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Registering via AppStateScope.of() ensures this screen rebuilds on
    // check-in changes, regeneration, and activity enable/disable.
    final state = AppStateScope.of(context);
    final week = state.weekPlan;

    DayPlan? today;
    for (final d in week) {
      if (d.isToday) {
        today = d;
        break;
      }
    }

    final allActivities = week.expand((d) => d.activities).toList();
    final planned = allActivities.length;
    final done =
        allActivities.where((a) => a.status == CheckStatus.done).length;
    final partly =
        allActivities.where((a) => a.status == CheckStatus.partly).length;

    final todayActivities = today?.activities ?? [];
    final pending = todayActivities
        .where((a) => a.status == CheckStatus.none && _isUpcoming(a.timeSlot))
        .toList();
    final nextUp = pending.isEmpty ? null : pending.first;

    final hasPastUnchecked = state.hasPastUnchecked(now: widget.now);
    final showCheckInPrompt = hasPastUnchecked && !state.checkInPromptDismissed;

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
                  _GreetingBlock(dateLabel: _formattedDate()),
                  const SizedBox(height: 16),
                  _NextUpCard(nextUp: nextUp),
                  if (showCheckInPrompt) ...[
                    const SizedBox(height: 12),
                    _CheckInCard(
                      onCheckIn: () => _openOneByOneReview(state),
                      onDismiss: state.dismissCheckInPrompt,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ThisWeekCard(planned: planned, done: done, partly: partly),
                  const SizedBox(height: 16),
                  const _QuickActionsSection(),
                  const SizedBox(height: 16),
                  _TodaysPlanSection(activities: todayActivities),
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
  const _GreetingBlock({required this.dateLabel});

  final String dateLabel;

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
        Text(dateLabel,
            style: GoogleFonts.dmSans(fontSize: 14, color: textMuted)),
      ],
    );
  }
}

// ─── Next up card ─────────────────────────────────────────────────────────────

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.nextUp});

  final PlannedActivity? nextUp;

  IconData _icon(String category) => switch (category) {
        'Creative' => Icons.menu_book_rounded,
        'Outside' => Icons.waves_rounded,
        'Couple time' => Icons.restaurant_rounded,
        'Rest' => Icons.self_improvement_rounded,
        'Social' => Icons.people_rounded,
        'At home' => Icons.home_rounded,
        _ => Icons.star_rounded,
      };

  @override
  Widget build(BuildContext context) {
    if (nextUp == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: warmBeige,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              alignment: Alignment.center,
              child:
                  const Icon(Icons.check_rounded, size: 18, color: accentSage),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Nothing else planned today — enjoy your day',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

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
              color: Colors.white.withValues(alpha: 0.20),
            ),
            alignment: Alignment.center,
            child: Icon(_icon(nextUp!.category), size: 18, color: Colors.white),
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
                    color: Colors.white.withValues(alpha: 0.70),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nextUp!.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  nextUp!.timeSlot,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.80),
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
  const _CheckInCard({required this.onCheckIn, required this.onDismiss});

  final VoidCallback onCheckIn;
  final VoidCallback onDismiss;

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
                      'Past activities need a quick check-in',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No typing needed — just tap to mark how it went.',
                      style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
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
                  onTap: onCheckIn,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PillButton(
                  label: 'Later',
                  background: Colors.transparent,
                  textColor: textMuted,
                  hasBorder: true,
                  onTap: onDismiss,
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
    this.onTap,
  });

  final String label;
  final Color background;
  final Color textColor;
  final bool hasBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
  const _ThisWeekCard({
    required this.planned,
    required this.done,
    required this.partly,
  });

  final int planned;
  final int done;
  final int partly;

  @override
  Widget build(BuildContext context) {
    final progress = planned == 0 ? 0.0 : (done + partly * 0.5) / planned;
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
                  value: '$planned', label: 'Planned', valueColor: textPrimary),
              _StatCell(value: '$done', label: 'Done', valueColor: accentSage),
              _StatCell(value: '$partly', label: 'Partly', valueColor: sand),
            ],
          ),
          const SizedBox(height: 12),
          _ProgressBar(value: progress),
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
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted)),
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
        final filled = constraints.maxWidth * value.clamp(0.0, 1.0);
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
                      gradient: LinearGradient(colors: [accentSage, sand]),
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
  const _TodaysPlanSection({required this.activities});

  final List<PlannedActivity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 10),
        if (activities.isEmpty)
          LsCard(
            child: Text(
              'No activities planned for today. Go to the Plan tab to generate or adjust your week.',
              style: GoogleFonts.dmSans(
                  fontSize: 14, color: textMuted, height: 1.5),
            ),
          )
        else
          ...activities.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ActivityPlanCard(activity: a),
            ),
          ),
      ],
    );
  }
}
