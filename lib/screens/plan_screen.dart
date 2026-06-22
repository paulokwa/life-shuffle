import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/text_week_export_service.dart';
import '../theme/app_colors.dart';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/generated_plan_range.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/range_type.dart';
import '../models/sync_message.dart';
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';
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
                            'Add some activities then tap Regenerate below to '
                            'build your week.',
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
                      Expanded(
                        child: _OutlineButton(
                          key: const ValueKey('plan-export-button'),
                          label: 'Export',
                          onTap: () => _copyWeekPlanText(context, state),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OutlineButton(
                          key: const ValueKey('plan-publish-feed-button'),
                          label: 'Publish feed',
                          onTap: () => _showPublishingInSettingsMessage(
                            context,
                          ),
                        ),
                      ),
                    ],
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

  /// Snack bar text shown after a successful copy, by [AppState.viewMode].
  static String _exportSuccessMessage(RangeType mode) => switch (mode) {
        RangeType.week => 'Week plan copied',
        RangeType.twoWeek => '2-week plan copied',
        RangeType.month => 'Month plan copied',
      };

  static String _exportEmptyMessage(RangeType mode) => switch (mode) {
        RangeType.week => 'No planned activities this week. Empty week '
            'copied.',
        RangeType.twoWeek => 'No planned activities in this 2-week range. '
            'Empty range copied.',
        RangeType.month => 'No planned activities in the generated month '
            'range. Empty range copied.',
      };

  static Future<void> _copyWeekPlanText(
    BuildContext context,
    AppState state,
  ) async {
    final exportDays = state.exportDays;
    if (exportDays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No generated month range yet. Tap Generate above, then '
            'export.',
          ),
        ),
      );
      return;
    }

    final hasPlannedActivities =
        exportDays.any((day) => day.activities.isNotEmpty);
    final text = TextWeekExportService.generate(
      calendarTitle: state.calendarTitle,
      plan: exportDays,
      rangeType: state.viewMode,
      options: state.exportPrintOptions,
      difficultyEnabled: state.difficultyEnabled,
      energyEnabled: state.energyEnabled,
      socialEnabled: state.socialEnabled,
    );

    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not copy the plan. Try again.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasPlannedActivities
              ? _exportSuccessMessage(state.viewMode)
              : _exportEmptyMessage(state.viewMode),
        ),
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

  static void _showPublishingInSettingsMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publishing controls are in Settings.')),
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
class _RangeTypeControl extends StatelessWidget {
  const _RangeTypeControl({required this.current, required this.onChanged});

  final RangeType current;
  final ValueChanged<RangeType> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (RangeType.week, '1 week'),
      (RangeType.twoWeek, '2 weeks'),
      (RangeType.month, 'Month'),
    ];
    return Row(
      children: options.map((option) {
        final (type, label) = option;
        final selected = type == current;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            key: ValueKey('plan-range-${type.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? primaryTerracotta : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: selected ? primaryTerracotta : borderWarmStrong,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
            child: const Text('Generate'),
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
              childAspectRatio: 0.72,
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
                onTap: inRange ? () => onDayTap(plan) : null,
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
    final visibleActivities = plan.activities.take(2).toList();
    final hiddenCount = plan.activities.length - visibleActivities.length;
    return GestureDetector(
      key: ValueKey(
        inRange
            ? 'month-grid-day-${PlanScreen._dateKey(plan.date)}'
            : 'month-grid-out-of-range-cell-${PlanScreen._dateKey(plan.date)}',
      ),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: inRange ? backgroundCream : const Color(0xFFF2EEE7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inRange ? borderWarm : const Color(0x0A2C2A26),
          ),
        ),
        child: inRange
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (showMonthLabel) ...[
                        Text(
                          PlanScreen._monthAbbrevs[plan.date.month - 1],
                          key: ValueKey(
                            'month-grid-month-label-'
                            '${PlanScreen._dateKey(plan.date)}',
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
                          'month-grid-day-number-'
                          '${PlanScreen._dateKey(plan.date)}',
                        ),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: plan.isToday ? primaryTerracotta : textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ...visibleActivities.map(
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceWhite,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: borderWarm),
                        ),
                        child: Text(
                          activity.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: categoryIconColor(activity.category),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hiddenCount > 0)
                    Text(
                      '+$hiddenCount more',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: textMuted,
                      ),
                    ),
                ],
              )
            : const SizedBox.expand(),
      ),
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
  const _PlannerConflictCard({required this.message});

  final String message;

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
                  'Week regenerated',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Undo to restore the previous week.',
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
            onTap: () => onDayTap(d),
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
    return GestureDetector(
      key: ValueKey('plan-day-card-${PlanScreen._dateKey(plan.date)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
                Text(
                  'Check in',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryTerracotta,
                  ),
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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: widget.plan.activities.isEmpty
                ? const _EmptyDaySheetBody()
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
  const _EmptyDaySheetBody();

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
                    'There is nothing to mark right now.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: textMuted,
                      height: 1.35,
                    ),
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
                  label: 'Partly',
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
                  label: 'Unchecked',
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
                  'Edit this plan item',
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
          const SizedBox(height: 6),
          GestureDetector(
            key: ValueKey('day-sheet-edit-template-${activity.id}'),
            onTap: onEditTemplate,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Edit activity template',
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

/// Time-of-day pattern this sheet's time field accepts, e.g. `7:30 PM` or
/// `7:00am`. Matches the `h:mm AM/PM` shape every other display time in
/// this app already uses (see `PlannerService.timeRank`,
/// `IcsCalendarService`, and `TodayScreen`'s upcoming-activity check).
final RegExp _planItemTimePattern =
    RegExp(r'^([1-9]|1[0-2]):([0-5][0-9])\s*([AaPp][Mm])$');

class _PlanItemEditorSheet extends StatefulWidget {
  const _PlanItemEditorSheet({required this.day, required this.activity});

  final DayPlan day;
  final PlannedActivity activity;

  @override
  State<_PlanItemEditorSheet> createState() => _PlanItemEditorSheetState();
}

class _PlanItemEditorSheetState extends State<_PlanItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _timeController;
  late String _category;
  late int _difficulty;
  late String _energy;
  late String _social;

  @override
  void initState() {
    super.initState();
    _timeController = TextEditingController(text: widget.activity.timeSlot);
    _category = widget.activity.category;
    _difficulty = widget.activity.difficulty;
    _energy = widget.activity.energy;
    _social = widget.activity.social;
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
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
                  'Edit this plan item',
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
                TextFormField(
                  key: const ValueKey('plan-item-editor-time-field'),
                  controller: _timeController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Scheduled time').copyWith(
                    hintText: 'e.g. 7:30 PM',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add a time';
                    }
                    if (!_planItemTimePattern.hasMatch(value.trim())) {
                      return 'Use a time like 7:30 PM';
                    }
                    return null;
                  },
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
                    'Edit activity template',
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
      ),
    );
  }

  Future<void> _editTemplate() async {
    await showActivityFormSheet(context, activity: widget.activity.activity);
    if (mounted) setState(() {});
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final match = _planItemTimePattern.firstMatch(_timeController.text.trim())!;
    final normalizedTime =
        '${match.group(1)}:${match.group(2)} ${match.group(3)!.toUpperCase()}';
    final state = AppStateScope.of(context);
    state.editPlannedOccurrence(
      widget.day,
      widget.activity,
      timeSlot: normalizedTime,
      category: _category,
      difficulty: state.difficultyEnabled ? _difficulty : null,
      energy: state.energyEnabled ? _energy : null,
      social: state.socialEnabled ? _social : null,
    );
    Navigator.of(context).pop();
  }

  InputDecoration _inputDecoration(String label) {
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
