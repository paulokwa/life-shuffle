import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../state/app_state.dart';
import '../widgets/category_chip.dart';
import '../widgets/ls_card.dart';
import 'check_in_catchup_screen.dart';

/// Calmer, sequential alternative to [CheckInCatchupScreen]: shows one past
/// unchecked activity at a time instead of a full list. Recomputes the
/// past-unchecked queue on every rebuild (no internal index), so marking the
/// current item naturally advances to the next one once [AppState] notifies.
///
/// Pushed as a new route, so [AppState] is passed in explicitly and
/// re-provided via a fresh [AppStateScope] here rather than looked up from
/// the screen that pushed this route (a new route's context is not a
/// descendant of the previous route's widget tree).
class CheckInOneByOneScreen extends StatelessWidget {
  const CheckInOneByOneScreen({super.key, required this.appState, this.now});

  final AppState appState;

  /// Override for [DateTime.now] used by the past-unchecked filter, so tests
  /// are deterministic regardless of which real weekday they run on.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(state: appState, child: _OneByOneView(now: now));
  }
}

class _OneByOneView extends StatelessWidget {
  const _OneByOneView({this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final dayGroups = state.pastUncheckedByDay(now: now);
    final queue = <(DayPlan, PlannedActivity)>[
      for (final (day, items) in dayGroups)
        for (final activity in items) (day, activity),
    ];

    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('one-by-one-close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: textPrimary),
                  ),
                  const Spacer(),
                  if (queue.isNotEmpty)
                    TextButton(
                      key: const ValueKey('one-by-one-view-as-list'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) =>
                              CheckInCatchupScreen(appState: state, now: now),
                        ),
                      ),
                      child: Text(
                        'View as list',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: queue.isEmpty
                  ? const AllCaughtUpCard()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _OneByOneCard(
                        day: queue.first.$1,
                        activity: queue.first.$2,
                        remaining: queue.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OneByOneCard extends StatelessWidget {
  const _OneByOneCard({
    required this.day,
    required this.activity,
    required this.remaining,
  });

  final DayPlan day;
  final PlannedActivity activity;
  final int remaining;

  IconData get _icon => switch (activity.category) {
        'Creative' => Icons.menu_book_rounded,
        'Outside' => Icons.waves_rounded,
        'Couple time' => Icons.restaurant_rounded,
        'Social' => Icons.people_rounded,
        'At home' => Icons.home_rounded,
        'Rest' => Icons.self_improvement_rounded,
        _ => Icons.star_rounded,
      };

  void _setStatus(BuildContext context, CheckStatus status) {
    activity.status = status;
    AppStateScope.of(context).notifyCheckIn(activity);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$remaining ${remaining == 1 ? "item" : "items"} to review',
          style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
        ),
        const SizedBox(height: 20),
        LsCard(
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: warmBeige,
                ),
                alignment: Alignment.center,
                child: Icon(
                  _icon,
                  size: 24,
                  color: categoryIconColor(activity.category),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                day.fullLabel.toUpperCase(),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: textMuted,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                activity.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    activity.time,
                    style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                  ),
                  CategoryChip(category: activity.category),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No typing needed — just tap to mark how it went.',
          style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutcomeButton(
                label: 'Done',
                background: accentSage,
                foreground: Colors.white,
                onTap: () => _setStatus(context, CheckStatus.done),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutcomeButton(
                label: 'Partly done',
                background: sand.withValues(alpha: 0.20),
                foreground: sand,
                onTap: () => _setStatus(context, CheckStatus.partly),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutcomeButton(
                label: 'Skipped',
                background: Colors.transparent,
                foreground: textMuted,
                hasBorder: true,
                onTap: () => _setStatus(context, CheckStatus.skipped),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
