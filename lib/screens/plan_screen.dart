import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/text_week_export_service.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/sync_message.dart';
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';
import '../widgets/status_choice.dart';
import 'week_review_screen.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _weekRange(List<DayPlan> plans) {
    final first = plans.first.date;
    final last = plans.last.date;
    const months = [
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
    if (first.month == last.month) {
      return 'Week of ${first.day}-${last.day} ${months[last.month - 1]}';
    }
    return 'Week of ${first.day} ${months[first.month - 1]} - '
        '${last.day} ${months[last.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final plans = state.weekPlan;
    final hasAnyActivities = plans.any((d) => d.activities.isNotEmpty);
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
                    _weekRange(plans),
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 20),
                  _DayStrip(plans: plans, onDayTap: openDaySheet),
                  const SizedBox(height: 16),
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
                  if (!hasAnyActivities)
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

  static Future<void> _copyWeekPlanText(
    BuildContext context,
    AppState state,
  ) async {
    final hasPlannedActivities =
        state.weekPlan.any((day) => day.activities.isNotEmpty);
    final text = TextWeekExportService.generate(
      calendarTitle: state.calendarTitle,
      plan: state.weekPlan,
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
          content: Text('Could not copy the week plan. Try again.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hasPlannedActivities
              ? 'Week plan copied'
              : 'No planned activities this week. Empty week copied.',
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
                            : 'Mark what happened. No typing needed.',
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
                        onStatusSelected: (status) =>
                            _setStatus(activity, status),
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
    required this.onStatusSelected,
  });

  final PlannedActivity activity;
  final ValueChanged<CheckStatus> onStatusSelected;

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
          ),
        ],
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
