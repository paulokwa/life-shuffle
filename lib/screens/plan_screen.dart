import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/generated_plan_range.dart';
import '../models/manual_plan_item.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/range_type.dart';
import '../models/sync_message.dart';
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/bottom_nav_shell.dart' show BottomNavScope, BottomNavTab;
import '../widgets/outside_event_metadata_card.dart';
import '../widgets/status_choice.dart';
import 'activities_screen.dart'
    show DimensionFields, SheetButton, showActivityFormSheet;
import 'week_review_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static const _monthAbbrevs = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Date span label for [plans], e.g. "22-28 Jun" within one month or
  /// "22 Jun - 5 Jul" when it crosses a month boundary. Used for the week,
  /// 2-week, and month views alike, since a generated month horizon can
  /// itself span two calendar months.
  static String _dateRangeLabel(List<DayPlan> plans) {
    final first = plans.first.date;
    final last = plans.last.date;
    if (first.month == last.month) {
      return '${first.day}-${last.day} ${_monthAbbrevs[last.month - 1]}';
    }
    return '${first.day} ${_monthAbbrevs[first.month - 1]} - '
        '${last.day} ${_monthAbbrevs[last.month - 1]}';
  }

  static String _rangeLabel(AppState state) {
    final days = state.viewMode == RangeType.month
        ? state.generatedRange.days
        : state.weekPlan;
    return _dateRangeLabel(days);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isMonthView = state.viewMode == RangeType.month;
    final plans = state.weekPlan;
    final hasAnyActivities = isMonthView
        ? state.generatedRange.days.any((d) => d.activities.isNotEmpty)
        : plans.any((d) => d.activities.isNotEmpty);
    final restCount = plans.where((d) => d.activities.isEmpty).length;
    final hasEnabledActivities = state.activities.any((a) => a.enabled);

    void openDaySheet(DayPlan plan) => _openDaySheet(context, state, plan);

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
                    _rangeLabel(state),
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'VIEW PLAN AS',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _RangeTypeControl(
                    current: state.viewMode,
                    onChanged: state.setViewMode,
                  ),
                  if (state.viewMode == RangeType.twoWeek &&
                      state.hasSufficientRangeForView) ...[
                    const SizedBox(height: 8),
                    _WeekNavControl(
                      selectedIndex: state.selectedRangeWeekIndex,
                      weekCount: 2,
                      onSelected: state.selectRangeWeekIndex,
                    ),
                  ],
                  if (!state.hasSufficientRangeForView) ...[
                    const SizedBox(height: 12),
                    _RangeExpansionCard(
                      viewMode: state.viewMode,
                      onGenerate: () => state.generateRange(state.viewMode),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!isMonthView) ...[
                    _DayStrip(plans: plans, onDayTap: openDaySheet),
                    const SizedBox(height: 16),
                  ],
                  if (state.remoteUpdatedElsewhere) ...[
                    _SyncNoticeCard(
                      message: state.syncMessage!,
                      onDismiss: state.dismissRemoteUpdateNotice,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.canUndoLastRegeneration) ...[
                    _RegenerationUndoCard(
                      onUndo: state.undoLastRegeneration,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.plannerConflictMessage != null) ...[
                    _PlannerConflictCard(
                      message: state.plannerConflictMessage!,
                      onReviewRules: () => BottomNavScope.maybeOf(context)
                          ?.onNavigate(BottomNavTab.activities),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isMonthView)
                    _MonthGrid(
                      range: state.generatedRange,
                      onDayTap: openDaySheet,
                    )
                  else if (!hasAnyActivities)
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
                            hasEnabledActivities
                                ? 'Make a plan when you want a little direction.'
                                : 'Choose a few starter activities or add your own first.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => BottomNavScope.maybeOf(context)
                                ?.onNavigate(BottomNavTab.activities),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              hasEnabledActivities
                                  ? 'Review activities'
                                  : 'Add activities',
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ...plans.map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayBlock(plan: d, onTap: () => openDaySheet(d)),
                      ),
                    ),
                    if (restCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$restCount rest ${restCount == 1 ? "day" : "days"} '
                        'this week',
                        style:
                            GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: hasEnabledActivities
                          ? () {
                              final hadPlan = hasAnyActivities;
                              state.regenerate();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    hadPlan
                                        ? 'Plan shuffled. Undo is available above.'
                                        : 'Your plan is ready.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryTerracotta,
                        disabledBackgroundColor: warmBeige,
                        foregroundColor: Colors.white,
                        disabledForegroundColor: textMuted,
                        textStyle: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(
                        hasAnyActivities ? 'Shuffle unlocked' : 'Make plan',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: _OutlineButton(
                      key: const ValueKey('plan-review-week-button'),
                      label: 'Review week',
                      onTap: () => _openWeekReview(context, state),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _openWeekReview(BuildContext context, AppState state) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeekReviewScreen(appState: state),
      ),
    );
  }

  static Future<void> _openDaySheet(
    BuildContext context,
    AppState state,
    DayPlan plan,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppStateScope(
        state: state,
        child: _DayCheckInSheet(plan: plan),
      ),
    );
  }
}

/// Lets the user deliberately choose how much to generate: 1 week,
/// 2 weeks, or a month. Tapping 1 week or 2 weeks immediately (and
/// deliberately switches [AppState.viewMode], a harmless, free view switch
/// that never regenerates or discards the existing generated range. If the
/// chosen view needs more days than are currently generated, the Plan
/// screen shows [_RangeExpansionCard] instead of silently regenerating.
///
/// Laid out as a compact segmented control - one outer track with each
/// option taking an equal [Expanded] share - rather than a `Row` of
/// independently-padded pills, so the total width is always exactly the
/// available width and it cannot overflow on narrow phone screens (as low
/// as 320px). Each label scales down (never up) via [FittedBox] as a second
/// line of defense if a segment ever gets too tight to fit its text.
class _RangeTypeControl extends StatelessWidget {
  const _RangeTypeControl({required this.current, required this.onChanged});

  final RangeType current;
  final ValueChanged<RangeType> onChanged;

  static const _options = [
    (RangeType.week, '1 week'),
    (RangeType.twoWeek, '2 weeks'),
    (RangeType.month, 'Month'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('plan-range-control'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: warmBeige,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          for (final (type, label) in _options)
            Expanded(
              child: _RangeTypeSegment(
                type: type,
                label: label,
                selected: type == current,
                onTap: () => onChanged(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeTypeSegment extends StatelessWidget {
  const _RangeTypeSegment({
    required this.type,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RangeType type;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('plan-range-${type.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? primaryTerracotta : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the user pick which 7-day week of a generated 2-week range is
/// visible below, without regenerating anything.
class _WeekNavControl extends StatelessWidget {
  const _WeekNavControl({
    required this.selectedIndex,
    required this.weekCount,
    required this.onSelected,
  });

  final int selectedIndex;
  final int weekCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(weekCount, (index) {
        final selected = index == selectedIndex;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            key: ValueKey('plan-week-nav-$index'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(index),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? warmBeige : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? primaryTerracotta : borderWarmStrong,
                ),
              ),
              child: Text(
                'Week ${index + 1}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? primaryTerracotta : textPrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Shown when [AppState.hasSufficientRangeForView] is false: the user is
/// looking at a view that needs more days than [AppState.generatedRange]
/// currently has. Generating is a deliberate action distinct from just
/// looking at a view, so it gets its own explicit button here rather than
/// happening automatically on a selector tap.
class _RangeExpansionCard extends StatelessWidget {
  const _RangeExpansionCard({required this.viewMode, required this.onGenerate});

  final RangeType viewMode;
  final VoidCallback onGenerate;

  String get _label => switch (viewMode) {
        RangeType.week => '1 week',
        RangeType.twoWeek => '2 weeks',
        RangeType.month => 'a month',
      };

  String get _actionLabel => switch (viewMode) {
        RangeType.week => 'Make a 1-week plan',
        RangeType.twoWeek => 'Make a 2-week plan',
        RangeType.month => 'Make a month plan',
      };

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('plan-range-expansion-card'),
      color: const Color(0xFFFFF3EC),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x1AC8603A),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 18,
              color: primaryTerracotta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'More days needed for this view',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your current plan does not cover $_label yet.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            key: const ValueKey('plan-range-expansion-generate'),
            onPressed: onGenerate,
            style: TextButton.styleFrom(
              foregroundColor: primaryTerracotta,
              textStyle: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(_actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Read-only Monday-start grid for a [RangeType.month] range. The grid
/// spans whole calendar weeks for layout (it may itself cross a calendar
/// month boundary, since the generated range no longer is a literal
/// calendar month); cells before [GeneratedPlanRange.start] or after
/// [GeneratedPlanRange.end] are blank and dimmed, in-range cells show the
/// day number, up to two activity labels, and a `+X more` overflow count.
/// Whether [date] (already known to be in-range) should show a compact
/// month label: the first generated/visible date in the range always gets
/// one even when it isn't the 1st, and the 1st of any later month inside
/// the range gets one too, so a range spanning two calendar months (e.g.
/// Jun 22 - Jul 21) stays readable at a glance. Day numbers stay visible
/// either way; this only adds a small label alongside them.
bool _showsMonthLabel(DateTime date, DateTime rangeStart) {
  return date.day == 1 ||
      PlanScreen._dateKey(date) == PlanScreen._dateKey(rangeStart);
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.range, required this.onDayTap});

  final GeneratedPlanRange range;
  final ValueChanged<DayPlan> onDayTap;

  @override
  Widget build(BuildContext context) {
    final days = range.days;
    final rangeStart = range.start;
    final rangeEnd = range.end;
    final gridStart = DateTime(
      rangeStart.year,
      rangeStart.month,
      rangeStart.day - (rangeStart.weekday - 1),
    );
    final gridEnd = DateTime(
      rangeEnd.year,
      rangeEnd.month,
      rangeEnd.day + (DateTime.sunday - rangeEnd.weekday),
    );
    final dayByKey = {
      for (final day in days) PlanScreen._dateKey(day.date): day,
    };
    final cellCount = gridEnd.difference(gridStart).inDays + 1;

    return LsCard(
      key: const ValueKey('plan-month-grid'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            key: ValueKey('month-grid-weekday-headers'),
            children: [
              _WeekdayHeader('Mon'),
              _WeekdayHeader('Tue'),
              _WeekdayHeader('Wed'),
              _WeekdayHeader('Thu'),
              _WeekdayHeader('Fri'),
              _WeekdayHeader('Sat'),
              _WeekdayHeader('Sun'),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            key: const ValueKey('month-grid-7-column-grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cellCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              // Slightly taller than before (was 0.72) so the day number
              // and item-count summary have comfortable room on narrow
              // phone widths without clipping.
              childAspectRatio: 0.62,
            ),
            itemBuilder: (context, index) {
              final date = gridStart.add(Duration(days: index));
              final inRange =
                  !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
              final plan = dayByKey[PlanScreen._dateKey(date)] ??
                  DayPlan(date: date, activities: []);
              final showMonthLabel = inRange &&
                  _showsMonthLabel(
                    date,
                    rangeStart,
                  );
              return _MonthDayCell(
                plan: plan,
                inRange: inRange,
                showMonthLabel: showMonthLabel,
                // Rest/empty days do not invite check-in here either - same
                // rule as the day card/day strip.
                onTap: inRange && plan.activities.isNotEmpty
                    ? () => onDayTap(plan)
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textMuted,
          ),
        ),
      ),
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.plan,
    required this.inRange,
    required this.showMonthLabel,
    this.onTap,
  });

  final DayPlan plan;
  final bool inRange;
  final bool showMonthLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = inRange && plan.isToday;
    final dateKey = PlanScreen._dateKey(plan.date);
    return GestureDetector(
      key: ValueKey(
        inRange
            ? 'month-grid-day-$dateKey'
            : 'month-grid-out-of-range-cell-$dateKey',
      ),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: ValueKey('month-grid-day-cell-$dateKey'),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          // A subtle terracotta tint/border calls out today's cell without
          // making the rest of the grid noisier - every other in/out-of-
          // range cell keeps its existing look.
          color: inRange
              ? (isToday ? const Color(0x14C8603A) : backgroundCream)
              : const Color(0xFFF2EEE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inRange
                ? (isToday ? primaryTerracotta : borderWarm)
                : const Color(0x0A2C2A26),
            width: isToday ? 1.4 : 1,
          ),
        ),
        child: inRange
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scales down (never up) rather than overflowing - the
                  // month/today label next to the day number is the widest
                  // thing in a cell and is the first to run out of room on
                  // narrow phone widths.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        // "Today" takes priority over the month label in
                        // the rare case both would apply to the same cell -
                        // it's the more useful thing to flag at a glance.
                        if (isToday) ...[
                          Text(
                            'TODAY',
                            key: ValueKey('month-grid-today-label-$dateKey'),
                            style: GoogleFonts.dmSans(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: primaryTerracotta,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 3),
                        ] else if (showMonthLabel) ...[
                          Text(
                            PlanScreen._monthAbbrevs[plan.date.month - 1],
                            key: ValueKey(
                              'month-grid-month-label-$dateKey',
                            ),
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: textMuted,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          '${plan.date.day}',
                          key: ValueKey(
                            'month-grid-day-number-$dateKey',
                          ),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isToday ? primaryTerracotta : textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (inRange && plan.activities.isEmpty)
                    Expanded(
                      child: GestureDetector(
                        key: ValueKey(
                          'month-grid-add-${PlanScreen._dateKey(plan.date)}',
                        ),
                        onTap: () => showAddPlanItemSheet(
                          context,
                          date: plan.date,
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            size: 20,
                            color: primaryTerracotta,
                          ),
                        ),
                      ),
                    )
                  else
                    _MonthDaySummary(activities: plan.activities),
                ],
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

/// Compact day-cell summary shown instead of full activity chips: small
/// category-colored dots (one per activity, capped with a "+N" overflow)
/// plus a plain-language item count, so a cell stays readable at
/// month-grid size on narrow/mobile widths rather than cramming in
/// unreadable mini activity-title chips.
class _MonthDaySummary extends StatelessWidget {
  const _MonthDaySummary({required this.activities});

  final List<PlannedActivity> activities;

  @override
  Widget build(BuildContext context) {
    const maxDots = 4;
    final dotCount = activities.length < maxDots ? activities.length : maxDots;
    final overflow = activities.length - dotCount;
    final hasLocked = activities.any((a) => a.locked);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wrap (not Row) so this never hard-overflows on the narrowest
        // phone widths - it reflows to a second line instead of erroring.
        Wrap(
          spacing: 3,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < dotCount; i++)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: categoryIconColor(activities[i].category),
                  shape: BoxShape.circle,
                ),
              ),
            if (overflow > 0)
              Text(
                '+$overflow',
                style: GoogleFonts.dmSans(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: textMuted,
                ),
              ),
            if (hasLocked)
              const Icon(
                Icons.lock_rounded,
                size: 9,
                color: primaryTerracotta,
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          activities.length == 1 ? '1 item' : '${activities.length} items',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SyncNoticeCard extends StatelessWidget {
  const _SyncNoticeCard({required this.message, required this.onDismiss});

  final SyncMessage message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('plan-sync-notice-card'),
      color: const Color(0xFFEEF6F2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x1A6A9E88),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: accentSage,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.body,
                  key: const ValueKey('plan-sync-notice-body'),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('plan-sync-notice-dismiss'),
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18, color: textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

class _PlannerConflictCard extends StatelessWidget {
  const _PlannerConflictCard({
    required this.message,
    required this.onReviewRules,
  });

  final String message;
  final VoidCallback onReviewRules;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      color: const Color(0xFFFFF7E8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x1AC8943A),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 18,
              color: sand,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Some activities could not fit',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onReviewRules,
                  child: const Text('Review activity rules'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegenerationUndoCard extends StatelessWidget {
  const _RegenerationUndoCard({required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      color: const Color(0xFFFFF3EC),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x1AC8603A),
            ),
            child: const Icon(
              Icons.undo_rounded,
              size: 18,
              color: primaryTerracotta,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan shuffled',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Undo to restore the previous plan.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              foregroundColor: primaryTerracotta,
              textStyle: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Undo'),
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.plans, required this.onDayTap});

  final List<DayPlan> plans;
  final ValueChanged<DayPlan> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: plans.map((d) {
        final isToday = d.isToday;
        final hasActivities = d.activities.isNotEmpty;
        return Expanded(
          child: GestureDetector(
            key: ValueKey('plan-day-strip-${PlanScreen._dateKey(d.date)}'),
            behavior: HitTestBehavior.opaque,
            onTap: hasActivities ? () => onDayTap(d) : null,
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
                if (hasActivities)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentSage,
                    ),
                  )
                else
                  GestureDetector(
                    key: ValueKey(
                      'plan-day-strip-add-${PlanScreen._dateKey(d.date)}',
                    ),
                    onTap: () => showAddPlanItemSheet(context, date: d.date),
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(
                      Icons.add_rounded,
                      size: 14,
                      color: primaryTerracotta,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.plan, required this.onTap});

  final DayPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActivities = plan.activities.isNotEmpty;
    final canCheckIn = hasActivities && AppState.canCheckIn(plan.date);

    return GestureDetector(
      key: ValueKey('plan-day-card-${PlanScreen._dateKey(plan.date)}'),
      behavior: HitTestBehavior.opaque,
      onTap: hasActivities ? onTap : null,
      child: LsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.fullLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.6,
                      color: textMuted,
                    ),
                  ),
                ),
                // Rest/empty days show no action at all (nothing to check
                // into), and future days show a non-action "Upcoming" label
                // rather than an active-looking "Check in" - only today/past
                // days with planned activities actually invite check-in.
                if (canCheckIn)
                  Text(
                    'Check in',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryTerracotta,
                    ),
                  )
                else if (hasActivities)
                  Text(
                    'Upcoming',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textMuted,
                    ),
                  ),
                IconButton(
                  key: ValueKey(
                    'plan-day-card-add-${PlanScreen._dateKey(plan.date)}',
                  ),
                  onPressed: () => showAddPlanItemSheet(
                    context,
                    date: plan.date,
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: primaryTerracotta,
                  ),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 44, minHeight: 44),
                  tooltip: 'Add item',
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (plan.activities.isEmpty)
              Text(
                'No planned items.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: textMuted,
                ),
              )
            else
              ...plan.activities.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PlanRow(activity: a),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCheckInSheet extends StatefulWidget {
  const _DayCheckInSheet({required this.plan});

  final DayPlan plan;

  @override
  State<_DayCheckInSheet> createState() => _DayCheckInSheetState();
}

class _DayCheckInSheetState extends State<_DayCheckInSheet> {
  void _setStatus(PlannedActivity activity, CheckStatus status) {
    setState(() {
      activity.status = status;
    });
    AppStateScope.of(context).notifyCheckIn(activity);
  }

  Future<void> _editPlannedItem(PlannedActivity activity) async {
    await showPlanItemEditorSheet(
      context,
      day: widget.plan,
      activity: activity,
    );
    if (mounted) setState(() {});
  }

  Future<void> _editActivityTemplate(PlannedActivity activity) async {
    await showActivityFormSheet(context, activity: activity.activity);
    // The form sheet mutates the same Activity instance this day's
    // PlannedActivity already points to, so a rebuild is enough to show
    // the edited title/category here without re-fetching anything.
    if (mounted) setState(() {});
  }

  Future<void> _removeFromPlan(PlannedActivity activity) async {
    final confirmed = await _confirmRemoveFromPlan(context, activity.title);
    if (confirmed != true || !mounted) return;
    AppStateScope.of(context).removeFromPlan(widget.plan, activity);
    setState(() {});
  }

  static Future<bool?> _confirmRemoveFromPlan(
    BuildContext context,
    String activityTitle,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('remove-from-plan-dialog'),
        title: Text('Remove "$activityTitle" from this plan?'),
        content: const Text(
          'This only removes it from this generated plan. The activity '
          'stays in your library.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('remove-from-plan-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('remove-from-plan-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canCheckIn = AppState.canCheckIn(widget.plan.date);
    return Container(
      key: const ValueKey('day-checkin-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: backgroundCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.fullLabel,
                        style: GoogleFonts.lora(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.plan.activities.isEmpty
                            ? 'No planned items to check in.'
                            : canCheckIn
                                ? 'Mark what happened. No typing needed.'
                                : 'Check in after this day.',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('day-sheet-add-item'),
                  onPressed: () => showAddPlanItemSheet(
                    context,
                    date: widget.plan.date,
                  ),
                  icon: const Icon(Icons.add_rounded, color: primaryTerracotta),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: widget.plan.activities.isEmpty
                ? _EmptyDaySheetBody(date: widget.plan.date)
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    itemCount: widget.plan.activities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final activity = widget.plan.activities[index];
                      return _DaySheetActivityCard(
                        activity: activity,
                        canCheckIn: canCheckIn,
                        onStatusSelected: (status) =>
                            _setStatus(activity, status),
                        onEditPlannedItem: () => _editPlannedItem(activity),
                        onEditTemplate: () => _editActivityTemplate(activity),
                        onRemove: () => _removeFromPlan(activity),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDaySheetBody extends StatelessWidget {
  const _EmptyDaySheetBody({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: LsCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: warmBeige,
              ),
              child: const Icon(
                Icons.self_improvement_rounded,
                size: 18,
                color: textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nothing planned for this day',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap Add item to schedule something manually.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _OutlineButton(
                    label: 'Add item',
                    onTap: () => showAddPlanItemSheet(context, date: date),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySheetActivityCard extends StatelessWidget {
  const _DaySheetActivityCard({
    required this.activity,
    required this.canCheckIn,
    required this.onStatusSelected,
    required this.onEditPlannedItem,
    required this.onEditTemplate,
    required this.onRemove,
  });

  final PlannedActivity activity;
  final bool canCheckIn;
  final ValueChanged<CheckStatus> onStatusSelected;
  final VoidCallback onEditPlannedItem;
  final VoidCallback onEditTemplate;
  final VoidCallback onRemove;

  IconData get _icon => switch (activity.category) {
        'Creative' => Icons.menu_book_rounded,
        'Outside' => Icons.waves_rounded,
        'Couple time' => Icons.restaurant_rounded,
        'Social' => Icons.people_rounded,
        'At home' => Icons.home_rounded,
        'Rest' => Icons.self_improvement_rounded,
        _ => Icons.star_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    ManualPlanItem? manualItem;
    final manualId = activity.manualItemId;
    if (manualId != null) {
      for (final item in state.manualPlanItems) {
        if (item.id == manualId && item.isOutsideEvent) {
          manualItem = item;
          break;
        }
      }
    }

    return Container(
      key: ValueKey('day-sheet-activity-${activity.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: backgroundCream,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _icon,
                  size: 16,
                  color: categoryIconColor(activity.category),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          activity.time,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                        CategoryChip(category: activity.category),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (manualItem != null) ...[
            const SizedBox(height: 10),
            OutsideEventMetadataCard(item: manualItem),
          ],
          const SizedBox(height: 12),
          if (canCheckIn)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChoice(
                  activityId: activity.id,
                  status: CheckStatus.done,
                  selectedStatus: activity.status,
                  label: 'Done',
                  selectedColor: accentSage,
                  onTap: onStatusSelected,
                ),
                StatusChoice(
                  activityId: activity.id,
                  status: CheckStatus.partly,
                  selectedStatus: activity.status,
                  label: 'Partly done',
                  selectedColor: sand,
                  onTap: onStatusSelected,
                ),
                StatusChoice(
                  activityId: activity.id,
                  status: CheckStatus.skipped,
                  selectedStatus: activity.status,
                  label: 'Skipped',
                  selectedColor: textMuted,
                  onTap: onStatusSelected,
                ),
                StatusChoice(
                  activityId: activity.id,
                  status: CheckStatus.none,
                  selectedStatus: activity.status,
                  label: 'Clear check-in',
                  selectedColor: primaryTerracotta,
                  onTap: onStatusSelected,
                ),
              ],
            )
          else
            Text(
              'Check in after this day.',
              key: const ValueKey('day-sheet-future-notice'),
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                key: ValueKey('day-sheet-edit-activity-${activity.id}'),
                onTap: onEditPlannedItem,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Edit this date',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryTerracotta,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                key: ValueKey('day-sheet-remove-activity-${activity.id}'),
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Remove from this plan',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
          if (!activity.isManual) ...[
            const SizedBox(height: 6),
            GestureDetector(
              key: ValueKey('day-sheet-edit-template-${activity.id}'),
              onTap: onEditTemplate,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Edit future versions',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                  decoration: TextDecoration.underline,
                  decorationColor: textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opens the focused "Edit this plan item" sheet for [activity]'s
/// occurrence on [day]. This is the Plan day sheet's primary edit action -
/// distinct from `showActivityFormSheet`, which edits the reusable source
/// [Activity] template and stays available here only as a secondary
/// "Edit activity template" link.
Future<void> showPlanItemEditorSheet(
  BuildContext context, {
  required DayPlan day,
  required PlannedActivity activity,
}) {
  final appState = AppStateScope.of(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AppStateScope(
      state: appState,
      child: _PlanItemEditorSheet(day: day, activity: activity),
    ),
  );
}

/// Time-of-day pattern this sheet's picked/stored time matches, e.g.
/// `7:30 PM`. Matches the `h:mm AM/PM` shape every other display time in
/// this app already uses (see `PlannerService.timeRank`,
/// `IcsCalendarService`, and `TodayScreen`'s upcoming-activity check). Used
/// to parse the occurrence's existing time into a [TimeOfDay] for
/// [showTimePicker]'s initial selection - the picker itself, not typing,
/// is the primary way to change the time.
final RegExp _planItemTimePattern =
    RegExp(r'^([1-9]|1[0-2]):([0-5][0-9])\s*([AaPp][Mm])$');

TimeOfDay? _parsePlanItemTimeSlot(String slot) {
  final match = _planItemTimePattern.firstMatch(slot.trim());
  if (match == null) return null;
  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final isPm = match.group(3)!.toUpperCase() == 'PM';
  if (isPm && hour != 12) hour += 12;
  if (!isPm && hour == 12) hour = 0;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatPlanItemTimeSlot(TimeOfDay time) {
  final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

InputDecoration _sheetInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.dmSans(color: textMuted),
    filled: true,
    fillColor: surfaceWhite,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: borderWarm),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: borderWarm),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: primaryTerracotta),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: primaryTerracotta),
    ),
  );
}

class _PlanItemEditorSheet extends StatefulWidget {
  const _PlanItemEditorSheet({required this.day, required this.activity});

  final DayPlan day;
  final PlannedActivity activity;

  @override
  State<_PlanItemEditorSheet> createState() => _PlanItemEditorSheetState();
}

class _PlanItemEditorSheetState extends State<_PlanItemEditorSheet> {
  late String _timeSlot;
  late String _category;
  late int _difficulty;
  late String _energy;
  late String _social;

  @override
  void initState() {
    super.initState();
    _timeSlot = widget.activity.timeSlot;
    _category = widget.activity.category;
    _difficulty = widget.activity.difficulty;
    _energy = widget.activity.energy;
    _social = widget.activity.social;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasEnabledDimensions =
        state.difficultyEnabled || state.energyEnabled || state.socialEnabled;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const ValueKey('plan-item-editor-sheet'),
        decoration: const BoxDecoration(
          color: backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderWarmStrong,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Edit this date',
                style: GoogleFonts.lora(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.activity.title,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryTerracotta,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Only changes this planned item. Your activity library '
                'stays the same.',
                key: const ValueKey('plan-item-editor-scope-note'),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                key: const ValueKey('plan-item-editor-time-field'),
                onTap: _pickTime,
                behavior: HitTestBehavior.opaque,
                child: InputDecorator(
                  decoration: _inputDecoration('Scheduled time').copyWith(
                    suffixIcon: const Icon(
                      Icons.access_time_rounded,
                      color: textMuted,
                    ),
                  ),
                  child: Text(
                    _timeSlot,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('plan-item-editor-category-field'),
                initialValue: _category,
                decoration: _inputDecoration('Category'),
                items: Activity.categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _category = value);
                },
              ),
              if (hasEnabledDimensions) ...[
                const SizedBox(height: 12),
                DimensionFields(
                  difficultyEnabled: state.difficultyEnabled,
                  energyEnabled: state.energyEnabled,
                  socialEnabled: state.socialEnabled,
                  difficulty: _difficulty,
                  energy: _energy,
                  social: _social,
                  onDifficultyChanged: (value) {
                    setState(() => _difficulty = value);
                  },
                  onEnergyChanged: (value) {
                    setState(() => _energy = value);
                  },
                  onSocialChanged: (value) {
                    setState(() => _social = value);
                  },
                  inputDecoration: _inputDecoration,
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                key: const ValueKey('plan-item-editor-edit-template'),
                onTap: _editTemplate,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'Edit future versions',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                    decoration: TextDecoration.underline,
                    decorationColor: textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Changes the reusable activity, including future plans.',
                style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SheetButton(
                      label: 'Cancel',
                      foreground: textMuted,
                      background: Colors.transparent,
                      hasBorder: true,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SheetButton(
                      label: 'Save',
                      foreground: Colors.white,
                      background: primaryTerracotta,
                      onTap: _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final initialTime = _parsePlanItemTimeSlot(_timeSlot) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Scheduled time',
    );
    if (picked == null || !mounted) return;
    setState(() => _timeSlot = _formatPlanItemTimeSlot(picked));
  }

  Future<void> _editTemplate() async {
    await showActivityFormSheet(context, activity: widget.activity.activity);
    if (mounted) setState(() {});
  }

  void _save() {
    final state = AppStateScope.of(context);
    state.editPlannedOccurrence(
      widget.day,
      widget.activity,
      timeSlot: _timeSlot,
      category: _category,
      difficulty: state.difficultyEnabled ? _difficulty : null,
      energy: state.energyEnabled ? _energy : null,
      social: state.socialEnabled ? _social : null,
    );
    Navigator.of(context).pop();
  }

  InputDecoration _inputDecoration(String label) =>
      _sheetInputDecoration(label);
}

/// Opens the sheet for adding a manual plan item to [date]. If
/// [sourceActivity] is given, the sheet starts in "existing activity" mode
/// with that activity's details pre-filled.
Future<void> showAddPlanItemSheet(
  BuildContext context, {
  required DateTime date,
  Activity? sourceActivity,
}) {
  final appState = AppStateScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => AppStateScope(
      state: appState,
      child: _AddPlanItemSheet(date: date, sourceActivity: sourceActivity),
    ),
  );
}

class _AddPlanItemSheet extends StatefulWidget {
  const _AddPlanItemSheet({required this.date, this.sourceActivity});

  final DateTime date;
  final Activity? sourceActivity;

  @override
  State<_AddPlanItemSheet> createState() => _AddPlanItemSheetState();
}

class _AddPlanItemSheetState extends State<_AddPlanItemSheet> {
  final _formKey = GlobalKey<FormState>();
  Activity? _selectedSource;
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late String _category;
  late String _timeSlot;
  late int _difficulty;
  late String _energy;
  late String _social;
  bool _saveToLibrary = false;

  @override
  void initState() {
    super.initState();
    final source = widget.sourceActivity;
    _selectedSource = source;
    _titleController = TextEditingController(text: source?.title ?? '');
    _durationController = TextEditingController(
      text: '${source?.durationMinutes ?? 45}',
    );
    _category = source?.category ?? 'Outside';
    _timeSlot = _formatPlanItemTimeSlot(TimeOfDay.now());
    _difficulty = source?.difficulty ?? 3;
    _energy = source?.energy ?? 'medium';
    _social = source?.social ?? 'either';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  bool get _isNewOneOff => _selectedSource == null;

  void _applySource(Activity? source) {
    setState(() {
      _selectedSource = source;
      if (source != null) {
        _titleController.text = source.title;
        _durationController.text = '${source.durationMinutes}';
        _category = source.category;
        _difficulty = source.difficulty;
        _energy = source.energy;
        _social = source.social;
        _saveToLibrary = false;
      }
    });
  }

  Future<void> _pickTime() async {
    final initialTime = _parsePlanItemTimeSlot(_timeSlot) ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: 'Scheduled time',
    );
    if (picked == null || !mounted) return;
    setState(() => _timeSlot = _formatPlanItemTimeSlot(picked));
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = AppStateScope.of(context);
    final title = _titleController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 45;

    String? sourceActivityId = _selectedSource?.id;
    if (_isNewOneOff && _saveToLibrary) {
      sourceActivityId = state.addActivity(
        title: title,
        category: _category,
        durationMinutes: duration.clamp(5, 720),
        preferredTime: 'anytime',
        difficulty: state.difficultyEnabled ? _difficulty : null,
        energy: state.energyEnabled ? _energy : null,
        social: state.socialEnabled ? _social : null,
        maxPerWeek: 1,
        allowedWeekdays: Activity.allWeekdays,
        noConsecutiveDays: false,
        enabled: true,
      );
    }

    final item = ManualPlanItem(
      id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      dateKey: DayPlan.dateKey(widget.date),
      title: title,
      timeSlot: _timeSlot,
      category: _category,
      durationMinutes: duration.clamp(5, 720),
      difficulty: state.difficultyEnabled ? _difficulty : 3,
      energy: state.energyEnabled ? _energy : 'medium',
      social: state.socialEnabled ? _social : 'either',
      sourceActivityId: sourceActivityId,
    );
    state.addManualPlanItem(item);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hasEnabledDimensions =
        state.difficultyEnabled || state.energyEnabled || state.socialEnabled;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        key: const ValueKey('add-plan-item-sheet'),
        decoration: const BoxDecoration(
          color: backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderWarmStrong,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Add item',
                  style: GoogleFonts.lora(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DayPlan(date: widget.date, activities: const []).fullLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryTerracotta,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Activity?>(
                  key: const ValueKey('add-plan-item-source-field'),
                  value: _selectedSource,
                  decoration: _sheetInputDecoration('Add from library'),
                  items: [
                    const DropdownMenuItem<Activity?>(
                      value: null,
                      child: Text('Create a one-off item'),
                    ),
                    ...state.activities.map(
                      (activity) => DropdownMenuItem<Activity?>(
                        value: activity,
                        child: Text(activity.title),
                      ),
                    ),
                  ],
                  onChanged: (value) => _applySource(value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('add-plan-item-title-field'),
                  controller: _titleController,
                  enabled: _isNewOneOff,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInputDecoration('Title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  key: const ValueKey('add-plan-item-time-field'),
                  onTap: _pickTime,
                  behavior: HitTestBehavior.opaque,
                  child: InputDecorator(
                    decoration:
                        _sheetInputDecoration('Scheduled time').copyWith(
                      suffixIcon: const Icon(
                        Icons.access_time_rounded,
                        color: textMuted,
                      ),
                    ),
                    child: Text(
                      _timeSlot,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        color: textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('add-plan-item-category-field'),
                  value: _category,
                  decoration: _sheetInputDecoration('Category'),
                  items: Activity.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('add-plan-item-duration-field'),
                  controller: _durationController,
                  enabled: _isNewOneOff,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: _sheetInputDecoration('Duration minutes'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Use a number of minutes';
                    }
                    if (parsed > 720) return 'Keep it under 12 hours';
                    return null;
                  },
                ),
                if (hasEnabledDimensions) ...[
                  const SizedBox(height: 12),
                  DimensionFields(
                    difficultyEnabled: state.difficultyEnabled,
                    energyEnabled: state.energyEnabled,
                    socialEnabled: state.socialEnabled,
                    difficulty: _difficulty,
                    energy: _energy,
                    social: _social,
                    onDifficultyChanged: (value) {
                      setState(() => _difficulty = value);
                    },
                    onEnergyChanged: (value) {
                      setState(() => _energy = value);
                    },
                    onSocialChanged: (value) {
                      setState(() => _social = value);
                    },
                    inputDecoration: _sheetInputDecoration,
                  ),
                ],
                if (_isNewOneOff) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: surfaceWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: borderWarm),
                    ),
                    child: CheckboxListTile(
                      key: const ValueKey(
                        'add-plan-item-save-to-library-field',
                      ),
                      value: _saveToLibrary,
                      onChanged: (value) {
                        setState(() => _saveToLibrary = value ?? false);
                      },
                      title: Text(
                        'Save to activity library for future use',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SheetButton(
                        label: 'Cancel',
                        foreground: textMuted,
                        background: Colors.transparent,
                        hasBorder: true,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SheetButton(
                        key: const ValueKey('add-plan-item-save-button'),
                        label: 'Save',
                        foreground: Colors.white,
                        background: primaryTerracotta,
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  // The time stays at its natural width (it's short and
                  // must stay fully visible) while the chip - the widest,
                  // most variable-length thing in this row - takes
                  // whatever's left and ellipsizes via `CategoryChip`'s own
                  // overflow handling, rather than forcing the row wider
                  // than the screen on narrow phones.
                  Flexible(
                    child: CategoryChip(category: activity.category),
                  ),
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
              color:
                  activity.locked ? primaryTerracotta : const Color(0xFFBBB5AC),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
            color: onTap == null ? textMuted : primaryTerracotta,
          ),
        ),
      ),
    );
  }
}
