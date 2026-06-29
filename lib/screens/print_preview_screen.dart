import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/day_plan.dart';
import '../models/export_print_options.dart';
import '../models/generated_plan_range.dart';
import '../models/manual_plan_item.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/range_type.dart';
import '../services/browser_print.dart';
import '../services/planner_service.dart';
import '../services/text_week_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

String _viewModeLabel(RangeType mode) => switch (mode) {
      RangeType.week => 'Week view',
      RangeType.twoWeek => '2-week view',
      RangeType.month => 'Month view',
    };

/// Max content width for the printable plan, by whether it's a month grid
/// (wider) or a week/2-week day list. Shared by the on-screen preview and
/// the controls-free print-only view so both lay out identically.
double _printContentMaxWidth(RangeType viewMode) =>
    viewMode == RangeType.month ? 960 : 720;

/// Read-only, print-friendly weekly view for the selected calendar.
///
/// Pushed as a new route, so [AppState] is passed in explicitly and
/// re-provided via a fresh [AppStateScope] here, matching
/// `CheckInCatchupScreen`'s pattern (a new route's context is not a
/// descendant of the previous route's widget tree).
class PrintPreviewScreen extends StatelessWidget {
  const PrintPreviewScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(state: appState, child: const _PrintPreviewView());
  }
}

class _PrintPreviewView extends StatefulWidget {
  const _PrintPreviewView();

  @override
  State<_PrintPreviewView> createState() => _PrintPreviewViewState();
}

class _PrintPreviewViewState extends State<_PrintPreviewView> {
  // Pushes a separate, controls-free route to actually trigger the browser
  // print dialog rather than toggling a flag to hide controls for one
  // frame of *this* screen. The one-frame approach assumed
  // `triggerBrowserPrint()` blocks until the print dialog closes, which
  // holds on desktop browsers but not on mobile (the call returns
  // immediately while the OS print/PDF UI opens asynchronously) - so
  // restoring controls right after the call returned could happen well
  // before the browser/OS actually captured the page, putting the back
  // arrow and print icon right back into the captured PDF. A separate
  // route that never has those controls in its tree at all has no such
  // timing race: whenever the snapshot is taken, there is nothing to hide.
  Future<void> _handlePrint() async {
    final state = AppStateScope.of(context);
    final printed = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _PrintOnlyView(appState: state),
      ),
    );
    if (!mounted || printed != false) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Use your browser or device print option to print this page.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      key: const ValueKey('print-preview-screen'),
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _printContentMaxWidth(state.viewMode),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScreenControlsRow(onPrint: _handlePrint),
                  const SizedBox(height: 16),
                  const _PrintableContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen route containing only [_PrintableContent] - no back arrow,
/// no "Print preview" label, no print icon, ever - shown while the browser
/// print/PDF dialog is open. [_PrintPreviewView] stays underneath on the
/// navigation stack with its controls intact, so the user can always get
/// back to it (system/browser back) and print again.
class _PrintOnlyView extends StatefulWidget {
  const _PrintOnlyView({required this.appState});

  final AppState appState;

  @override
  State<_PrintOnlyView> createState() => _PrintOnlyViewState();
}

class _PrintOnlyViewState extends State<_PrintOnlyView> {
  @override
  void initState() {
    super.initState();
    // Waits for this controls-free frame to actually paint before
    // triggering print, then only pops itself automatically when printing
    // could not be started at all (non-web). When it did start, this view
    // is left in place - there's no reliable cross-browser signal that the
    // print/PDF flow has finished, so auto-restoring controls would
    // reintroduce the original timing race. The user backs out manually
    // once they're done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final printed = triggerBrowserPrint();
      if (!printed && mounted) {
        Navigator.of(context).pop(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: widget.appState,
      child: Scaffold(
        key: const ValueKey('print-only-screen'),
        backgroundColor: surfaceWhite,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _printContentMaxWidth(widget.appState.viewMode),
                ),
                child: const _PrintableContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The actual printable plan: calendar title, view/range labels, and the
/// day list or month grid. Shared, unchanged, between the on-screen
/// preview (under [_ScreenControlsRow]) and [_PrintOnlyView] (alone), so
/// both ever show exactly the same plan content.
class _PrintableContent extends StatelessWidget {
  const _PrintableContent();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final viewMode = state.viewMode;
    final isMonthView = viewMode == RangeType.month;
    final monthRangeReady = isMonthView && state.hasSufficientRangeForView;

    final sortedWeekPlan = List<DayPlan>.from(state.weekPlan)
      ..sort((a, b) => a.date.compareTo(b.date));
    final hasAnyPlanned =
        sortedWeekPlan.any((day) => day.activities.isNotEmpty);

    final rangeLabel = isMonthView
        ? (monthRangeReady
            ? TextWeekExportService.weekRangeLabel(state.generatedRange.days)
            : null)
        : TextWeekExportService.weekRangeLabel(sortedWeekPlan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.calendarTitle,
          key: const ValueKey('print-preview-calendar-title'),
          style: GoogleFonts.lora(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _viewModeLabel(viewMode),
          key: const ValueKey('print-preview-view-label'),
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryTerracotta,
          ),
        ),
        if (rangeLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            rangeLabel,
            key: const ValueKey('print-preview-week-range'),
            style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
          ),
        ],
        if (viewMode == RangeType.twoWeek) ...[
          const SizedBox(height: 4),
          Text(
            'Printing the visible week only. Use Copy text in '
            'Settings for the full generated 2-week range.',
            key: const ValueKey('print-preview-two-week-note'),
            style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
          ),
        ],
        const SizedBox(height: 24),
        if (isMonthView)
          if (!monthRangeReady)
            const _PendingRangeNotice()
          else
            _PrintMonthGrid(range: state.generatedRange)
        else if (!hasAnyPlanned)
          const _EmptyWeekNotice()
        else
          ...sortedWeekPlan.map(
            (day) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _PrintDaySection(day: day),
            ),
          ),
      ],
    );
  }
}

/// Back/print controls for [_PrintPreviewView] only. Printing pushes the
/// separate, controls-free [_PrintOnlyView] rather than hiding this row in
/// place, so it never appears in printed/PDF output regardless of when the
/// browser actually captures the page.
class _ScreenControlsRow extends StatelessWidget {
  const _ScreenControlsRow({required this.onPrint});

  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('print-preview-back-button'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: textPrimary),
        ),
        Expanded(
          child: Text(
            'Print preview',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('print-preview-print-button'),
          onPressed: onPrint,
          icon: const Icon(Icons.print_rounded, color: textPrimary),
          tooltip: 'Print',
        ),
      ],
    );
  }
}

class _PrintDaySection extends StatelessWidget {
  const _PrintDaySection({required this.day});

  final DayPlan day;

  @override
  Widget build(BuildContext context) {
    final activities = List<PlannedActivity>.from(day.activities)
      ..sort(
        (a, b) => PlannerService.timeRank(a.timeSlot)
            .compareTo(PlannerService.timeRank(b.timeSlot)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day.fullLabel,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Divider(height: 1, color: borderWarmStrong),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          Text(
            'No planned items',
            style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
          )
        else
          ...activities.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PrintActivityRow(activity: a),
            ),
          ),
      ],
    );
  }
}

class _PrintActivityRow extends StatelessWidget {
  const _PrintActivityRow({required this.activity});

  final PlannedActivity activity;

  String? _statusLabel(ExportPrintOptions options) {
    if (!options.showCheckInStatus) return null;
    return switch (activity.status) {
      CheckStatus.done => 'Done',
      CheckStatus.partly => 'Partly done',
      CheckStatus.skipped => 'Skipped',
      CheckStatus.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final options = state.exportPrintOptions;

    final details = [
      if (options.showTime) activity.timeSlot,
      if (options.showDuration) activity.activity.duration,
      if (options.showCategory) activity.category,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final statusLabel = _statusLabel(options);
    final showLock = options.showLockedStatus && activity.locked;
    final dimensionLabels = options.showEnabledDimensions
        ? TextWeekExportService.dimensionLabels(
            difficulty: activity.difficulty,
            energy: activity.energy,
            social: activity.social,
            difficultyEnabled: state.difficultyEnabled,
            energyEnabled: state.energyEnabled,
            socialEnabled: state.socialEnabled,
          )
        : const <String>[];
    final manualItem = state.manualPlanItems.cast<ManualPlanItem?>().firstWhere(
        (item) => item?.id == activity.manualItemId,
        orElse: () => null);
    final outsideEventLines = options.showOutsideEventDetails &&
            manualItem != null &&
            manualItem.isOutsideEvent
        ? TextWeekExportService.outsideEventDetailLines(manualItem)
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details,
                      style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                    ),
                ],
              ),
            ),
            if (showLock)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.lock_rounded, size: 14, color: textMuted),
              ),
            if (statusLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ),
          ],
        ),
        if (dimensionLabels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              dimensionLabels.join(' · '),
              style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
            ),
          ),
        if (outsideEventLines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              outsideEventLines.join(' · '),
              style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
            ),
          ),
      ],
    );
  }
}

class _EmptyWeekNotice extends StatelessWidget {
  const _EmptyWeekNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('print-preview-empty-week'),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'No planned activities this week.',
        style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
      ),
    );
  }
}

/// Shown instead of [_PrintMonthGrid] when Month view is selected but
/// [AppState.hasSufficientRangeForView] is false. Print preview never
/// generates on its own — the user must go generate the range first (on the
/// Plan screen), then come back here to print it.
class _PendingRangeNotice extends StatelessWidget {
  const _PendingRangeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('print-preview-month-pending'),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        'No generated month range yet. Go to Plan, switch to Month, and tap '
        'Generate, then come back here to print.',
        style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
      ),
    );
  }
}

/// Whether [date] (already known to be in-range) should show a compact
/// month label in the print grid. Mirrors `plan_screen.dart`'s
/// `_showsMonthLabel`: the first generated date in the range always gets
/// one even when it isn't the 1st, and the 1st of any later month inside
/// the range gets one too, so a range spanning two calendar months stays
/// readable at a glance on the printed page. Day numbers stay visible
/// either way.
bool _showsMonthLabelInPrint(DateTime date, DateTime rangeStart) {
  return date.day == 1 || DayPlan.dateKey(date) == DayPlan.dateKey(rangeStart);
}

/// Print-friendly Monday-start calendar grid for [AppState.generatedRange]
/// when [AppState.viewMode] is [RangeType.month]. Mirrors the on-screen
/// month grid in `plan_screen.dart` (the grid spans whole calendar weeks for
/// layout and can itself cross a calendar-month boundary; cells before
/// [GeneratedPlanRange.start] or after [GeneratedPlanRange.end] are blank
/// and dimmed) but lays out with a [Table] rather than a fixed-aspect-ratio
/// grid so each row grows to fit however many activities a day has, which
/// suits print/PDF output better than a fixed-size on-screen grid.
class _PrintMonthGrid extends StatelessWidget {
  const _PrintMonthGrid({required this.range});

  final GeneratedPlanRange range;

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

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

  @override
  Widget build(BuildContext context) {
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
      for (final day in range.days) DayPlan.dateKey(day.date): day,
    };
    final totalCells = gridEnd.difference(gridStart).inDays + 1;
    final weekCount = totalCells ~/ 7;

    return Table(
      key: const ValueKey('print-preview-month-grid'),
      border: TableBorder.all(color: borderWarm),
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          key: const ValueKey('print-preview-month-grid-weekday-headers'),
          children: [
            for (final label in _weekdayLabels) _PrintMonthHeaderCell(label),
          ],
        ),
        for (var week = 0; week < weekCount; week++)
          TableRow(
            children: [
              for (var col = 0; col < 7; col++)
                _dayCell(
                    gridStart, week * 7 + col, rangeStart, rangeEnd, dayByKey),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(
    DateTime gridStart,
    int index,
    DateTime rangeStart,
    DateTime rangeEnd,
    Map<String, DayPlan> dayByKey,
  ) {
    final date = gridStart.add(Duration(days: index));
    final inRange = !date.isBefore(rangeStart) && !date.isAfter(rangeEnd);
    return _PrintMonthDayCell(
      date: date,
      plan: dayByKey[DayPlan.dateKey(date)],
      inRange: inRange,
      showMonthLabel: inRange && _showsMonthLabelInPrint(date, rangeStart),
    );
  }
}

class _PrintMonthHeaderCell extends StatelessWidget {
  const _PrintMonthHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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

/// One cell of [_PrintMonthGrid]. Out-of-range cells (before
/// [GeneratedPlanRange.start] or after [GeneratedPlanRange.end]) render
/// blank and dimmed; in-range cells show the day number and every planned
/// activity for that date, each respecting [AppState.exportPrintOptions].
class _PrintMonthDayCell extends StatelessWidget {
  const _PrintMonthDayCell({
    required this.date,
    required this.plan,
    required this.inRange,
    required this.showMonthLabel,
  });

  final DateTime date;
  final DayPlan? plan;
  final bool inRange;
  final bool showMonthLabel;

  @override
  Widget build(BuildContext context) {
    final dateKey = DayPlan.dateKey(date);
    if (!inRange) {
      return Container(
        key: ValueKey('print-preview-month-grid-filler-$dateKey'),
        constraints: const BoxConstraints(minHeight: 64),
        color: const Color(0xFFF2EEE7),
      );
    }

    final state = AppStateScope.of(context);
    final options = state.exportPrintOptions;
    final activities = plan?.activities ?? const <PlannedActivity>[];

    return Container(
      key: ValueKey('print-preview-month-grid-day-$dateKey'),
      padding: const EdgeInsets.all(4),
      alignment: Alignment.topLeft,
      constraints: const BoxConstraints(minHeight: 64),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (showMonthLabel) ...[
                Text(
                  _PrintMonthGrid._monthAbbrevs[date.month - 1],
                  key: ValueKey(
                    'print-preview-month-grid-month-label-$dateKey',
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
                '${date.day}',
                key: ValueKey('print-preview-month-grid-day-number-$dateKey'),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: (plan?.isToday ?? false)
                      ? primaryTerracotta
                      : textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          for (final activity in activities)
            _PrintMonthActivityEntry(
              activity: activity,
              options: options,
              state: state,
            ),
        ],
      ),
    );
  }
}

/// Compact per-activity entry inside a [_PrintMonthDayCell]. Smaller and
/// denser than [_PrintActivityRow] (the weekly list view's activity row)
/// since a grid cell has far less room than a full-width day section.
class _PrintMonthActivityEntry extends StatelessWidget {
  const _PrintMonthActivityEntry({
    required this.activity,
    required this.options,
    required this.state,
  });

  final PlannedActivity activity;
  final ExportPrintOptions options;
  final AppState state;

  String? _statusLabel() {
    if (!options.showCheckInStatus) return null;
    return switch (activity.status) {
      CheckStatus.done => 'Done',
      CheckStatus.partly => 'Partly done',
      CheckStatus.skipped => 'Skipped',
      CheckStatus.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final details = [
      if (options.showTime) activity.timeSlot,
      if (options.showDuration) activity.activity.duration,
      if (options.showCategory) activity.category,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final statusLabel = _statusLabel();
    final showLock = options.showLockedStatus && activity.locked;
    final dimensionLabels = options.showEnabledDimensions
        ? TextWeekExportService.dimensionLabels(
            difficulty: activity.difficulty,
            energy: activity.energy,
            social: activity.social,
            difficultyEnabled: state.difficultyEnabled,
            energyEnabled: state.energyEnabled,
            socialEnabled: state.socialEnabled,
          )
        : const <String>[];
    final secondaryParts = [
      if (details.isNotEmpty) details,
      if (showLock) 'Locked',
      if (statusLabel != null) statusLabel,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          if (secondaryParts.isNotEmpty)
            Text(
              secondaryParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 8, color: textMuted),
            ),
          if (dimensionLabels.isNotEmpty)
            Text(
              dimensionLabels.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 8, color: textMuted),
            ),
        ],
      ),
    );
  }
}
