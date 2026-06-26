import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../state/app_state.dart';
import '../widgets/category_chip.dart';
import '../widgets/ls_card.dart';
import '../widgets/status_choice.dart';

/// Full-current-week check-in review: every day of [AppState.weekPlan],
/// including already-checked items, so a user can look back over (and
/// correct) the whole week in one continuous scroll instead of opening each
/// day's bottom sheet individually.
///
/// Pushed as a new route, so [AppState] is passed in explicitly and
/// re-provided via a fresh [AppStateScope] here rather than looked up from
/// the screen that pushed this route (a new route's context is not a
/// descendant of the previous route's widget tree).
class WeekReviewScreen extends StatelessWidget {
  const WeekReviewScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(state: appState, child: const _WeekReviewView());
  }
}

class _WeekReviewView extends StatelessWidget {
  const _WeekReviewView();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final days = state.weekPlan;
    final hasAnyActivities = days.any((d) => d.activities.isNotEmpty);

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
                    'Week review',
                    style: GoogleFonts.lora(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mark what happened across the week. No typing needed.',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: hasAnyActivities
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
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
                              if (day.activities.isEmpty)
                                Text(
                                  'No planned items.',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    color: textMuted,
                                  ),
                                )
                              else
                                ...day.activities.map(
                                  (a) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _WeekReviewItemCard(
                                      activity: a,
                                      canCheckIn: AppState.canCheckIn(day.date),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    )
                  : const _NoWeekToReview(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekReviewItemCard extends StatelessWidget {
  const _WeekReviewItemCard({required this.activity, required this.canCheckIn});

  final PlannedActivity activity;
  final bool canCheckIn;

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
                  onTap: (status) => _setStatus(context, status),
                ),
                StatusChoice(
                  activityId: activity.id,
                  status: CheckStatus.partly,
                  selectedStatus: activity.status,
                  label: 'Partly',
                  selectedColor: sand,
                  onTap: (status) => _setStatus(context, status),
                ),
                StatusChoice(
                  activityId: activity.id,
                  status: CheckStatus.skipped,
                  selectedStatus: activity.status,
                  label: 'Skipped',
                  selectedColor: textMuted,
                  onTap: (status) => _setStatus(context, status),
                ),
              ],
            )
          else
            Text(
              'Check in after this day.',
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
            ),
        ],
      ),
    );
  }
}

class _NoWeekToReview extends StatelessWidget {
  const _NoWeekToReview();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: LsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nothing planned this week',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Add some activities then regenerate your week to review '
                'check-ins here.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: textMuted,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
