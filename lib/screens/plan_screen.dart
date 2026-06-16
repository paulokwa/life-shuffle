import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  static String _weekRange(List<DayPlan> plans) {
    final first = plans.first.date;
    final last = plans.last.date;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (first.month == last.month) {
      return 'Week of ${first.day}–${last.day} ${months[last.month - 1]}';
    }
    return 'Week of ${first.day} ${months[first.month - 1]} – ${last.day} ${months[last.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final plans = state.weekPlan;
    final activeDays = plans.where((d) => d.activities.isNotEmpty).toList();
    final restCount = plans.where((d) => d.activities.isEmpty).length;

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
                  Text(
                    'Plan',
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    _weekRange(plans),
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 20),
                  _DayStrip(plans: plans),
                  const SizedBox(height: 16),
                  if (activeDays.isEmpty)
                    LsCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No plan yet',
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add some activities then tap Regenerate below to build your week.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ...activeDays.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayBlock(plan: d),
                      ),
                    ),
                    if (restCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$restCount rest ${restCount == 1 ? "day" : "days"} this week',
                        style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => state.regenerate(),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryTerracotta,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Regenerate unlocked',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _OutlineButton(label: 'Export')),
                      const SizedBox(width: 10),
                      Expanded(child: _OutlineButton(label: 'Publish feed')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Day strip ────────────────────────────────────────────────────────────────

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.plans});

  final List<DayPlan> plans;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: plans.map((d) {
        final isToday = d.isToday;
        final hasActivities = d.activities.isNotEmpty;
        return Expanded(
          child: Column(
            children: [
              Text(
                d.weekdayShort,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? primaryTerracotta : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  d.dayOfMonth,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isToday
                        ? Colors.white
                        : hasActivities
                            ? textPrimary
                            : textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasActivities && !isToday
                      ? accentSage
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Day block card ───────────────────────────────────────────────────────────

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.plan});

  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.fullLabel,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...plan.activities.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PlanRow(activity: a),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan row with tappable lock ──────────────────────────────────────────────

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.activity});

  final PlannedActivity activity;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    activity.timeSlot,
                    style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(width: 8),
                  CategoryChip(category: activity.category),
                ],
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => state.toggleLock(activity),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              activity.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 16,
              color: activity.locked ? primaryTerracotta : const Color(0xFFBBB5AC),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Outline button ───────────────────────────────────────────────────────────

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderWarmStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}
