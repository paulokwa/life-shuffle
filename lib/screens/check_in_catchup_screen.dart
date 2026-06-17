import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../state/app_state.dart';
import '../widgets/category_chip.dart';

/// Full-screen catch-up flow listing every past unchecked activity grouped
/// by day, so a user can clear a backlog of check-ins in one pass.
///
/// Pushed as a new route, so [AppState] is passed in explicitly and
/// re-provided via a fresh [AppStateScope] here rather than looked up from
/// the screen that pushed this route (a new route's context is not a
/// descendant of the previous route's widget tree).
class CheckInCatchupScreen extends StatelessWidget {
  const CheckInCatchupScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(state: appState, child: const _CatchupView());
  }
}

class _CatchupView extends StatelessWidget {
  const _CatchupView();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dayGroups = <(DayPlan, List<PlannedActivity>)>[];
    for (final day in state.weekPlan) {
      if (!day.date.isBefore(today)) continue;
      final unchecked =
          day.activities.where((a) => a.status == CheckStatus.none).toList();
      if (unchecked.isNotEmpty) dayGroups.add((day, unchecked));
    }
    final totalRemaining =
        dayGroups.fold<int>(0, (sum, g) => sum + g.$2.length);

    return Scaffold(
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: textPrimary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catch up',
                    style: GoogleFonts.lora(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    totalRemaining == 0
                        ? 'You are all caught up.'
                        : 'No typing needed — just tap to mark how it went.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dayGroups.isEmpty
                  ? const _AllCaughtUp()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: dayGroups.length,
                      itemBuilder: (context, index) {
                        final (day, items) = dayGroups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                day.fullLabel.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                  color: textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...items.map(
                                (a) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _CatchupItemCard(activity: a),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// One past activity with three explicit outcome buttons. Each tap commits a
// final status directly (rather than cycling through states), since the item
// leaves this screen the moment its status changes away from `none` — a
// cycling tap would always land on the first state (Done) before the user
// could reach Partly or Skipped.
class _CatchupItemCard extends StatelessWidget {
  const _CatchupItemCard({required this.activity});

  final PlannedActivity activity;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderWarm, width: 1),
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
                        fontWeight: FontWeight.w500,
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
                              fontSize: 12, color: textMuted),
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
          Row(
            children: [
              Expanded(
                child: _OutcomeButton(
                  label: 'Done',
                  background: accentSage,
                  foreground: Colors.white,
                  onTap: () => _setStatus(context, CheckStatus.done),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutcomeButton(
                  label: 'Partly',
                  background: sand.withValues(alpha: 0.20),
                  foreground: sand,
                  onTap: () => _setStatus(context, CheckStatus.partly),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutcomeButton(
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
      ),
    );
  }
}

class _OutcomeButton extends StatelessWidget {
  const _OutcomeButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.hasBorder = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool hasBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(100),
          border: hasBorder ? Border.all(color: borderWarmStrong) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: foreground,
          ),
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEEF6F2),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.check_rounded,
                size: 26,
                color: accentSage,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'All caught up',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No past activities are waiting on a check-in.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
