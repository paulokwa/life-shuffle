import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../services/browser_print.dart';
import '../services/planner_service.dart';
import '../services/text_week_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

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
  // Screen-only navigation/print controls are removed from the widget tree
  // (not just visually hidden) for the one frame in which the browser
  // print dialog is triggered, so Flutter web's canvas-painted output for
  // that frame contains only the calendar content. `triggerBrowserPrint()`
  // blocks until the print dialog closes on the main browsers this app
  // targets, so it is safe to restore controls right after it returns.
  bool _printing = false;

  void _handlePrint() {
    setState(() => _printing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final printed = triggerBrowserPrint();
      if (!mounted) return;
      setState(() => _printing = false);
      if (!printed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Use your browser or device print option to print this page.'),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final sortedPlan = List<DayPlan>.from(state.weekPlan)
      ..sort((a, b) => a.date.compareTo(b.date));
    final hasAnyPlanned = sortedPlan.any((day) => day.activities.isNotEmpty);

    return Scaffold(
      key: const ValueKey('print-preview-screen'),
      backgroundColor: surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_printing) ...[
                    _ScreenControlsRow(onPrint: _handlePrint),
                    const SizedBox(height: 16),
                  ],
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
                    TextWeekExportService.weekRangeLabel(sortedPlan),
                    key: const ValueKey('print-preview-week-range'),
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 24),
                  if (!hasAnyPlanned)
                    const _EmptyWeekNotice()
                  else
                    ...sortedPlan.map(
                      (day) => Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _PrintDaySection(day: day),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back/print controls shown only on screen. Removed from the tree
/// (rather than just hidden) while [PrintPreviewScreen] triggers the
/// browser print dialog, so this row never appears in printed/PDF output.
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

  String? get _statusLabel => switch (activity.status) {
        CheckStatus.done => 'Done',
        CheckStatus.partly => 'Partly done',
        CheckStatus.skipped => 'Skipped',
        CheckStatus.none => null,
      };

  @override
  Widget build(BuildContext context) {
    final details = [
      activity.timeSlot,
      activity.activity.duration,
      activity.category,
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final statusLabel = _statusLabel;

    return Row(
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
        if (activity.locked)
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
