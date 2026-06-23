import 'dart:math';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;

enum PlanStyle { gentle, balanced, push }

/// Pure stateless planner. All mutable state lives in AppState.
class PlannerService {
  PlannerService._();

  static final List<Activity> defaultActivities = [
    Activity(
      id: 'a1',
      title: 'Cafe reading',
      category: 'Creative',
      durationMinutes: 90,
      preferredTime: 'morning',
    ),
    Activity(
      id: 'a2',
      title: 'Walk waterfront',
      category: 'Outside',
      durationMinutes: 45,
      preferredTime: 'morning',
    ),
    Activity(
      id: 'a3',
      title: 'Cook together',
      category: 'Couple time',
      durationMinutes: 60,
      preferredTime: 'evening',
    ),
    Activity(
      id: 'a4',
      title: 'Yoga at home',
      category: 'Rest',
      durationMinutes: 30,
      preferredTime: 'morning',
    ),
    Activity(
      id: 'a5',
      title: 'Farmers market',
      category: 'Outside',
      durationMinutes: 60,
      preferredTime: 'morning',
    ),
    Activity(
      id: 'a6',
      title: 'Board games night',
      category: 'Social',
      durationMinutes: 120,
      preferredTime: 'evening',
    ),
    Activity(
      id: 'a7',
      title: 'Movie night in',
      category: 'Couple time',
      durationMinutes: 120,
      preferredTime: 'evening',
    ),
    Activity(
      id: 'a8',
      title: 'Sketch or journal',
      category: 'Creative',
      durationMinutes: 45,
      preferredTime: 'afternoon',
    ),
  ];

  static DateTime mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  /// Generates a 7-day plan from [pool], shuffled with [seed].
  ///
  /// See [generateWithDiagnostics] for what [scheduledContext] carries.
  static List<DayPlan> generate({
    required DateTime weekStart,
    required List<Activity> pool,
    required int seed,
    PlanStyle planStyle = PlanStyle.balanced,
    bool difficultyAware = false,
    Map<int, List<PlannedActivity>> scheduledContext =
        const <int, List<PlannedActivity>>{},
  }) {
    return generateWithDiagnostics(
      weekStart: weekStart,
      pool: pool,
      seed: seed,
      planStyle: planStyle,
      difficultyAware: difficultyAware,
      scheduledContext: scheduledContext,
    ).plan;
  }

  /// [scheduledContext] carries day-indexed activity context from outside
  /// this single 7-day call, keyed by day index relative to [weekStart].
  /// Indexes 0-6 are normally same-week locked items; [RangePlannerService]
  /// also passes the previous generated week's final day under key `-1` so
  /// no-consecutive-days and difficulty spacing can see across the boundary
  /// between two generated weeks (e.g. Sunday into the next Monday).
  static PlannerGenerationResult generateWithDiagnostics({
    required DateTime weekStart,
    required List<Activity> pool,
    required int seed,
    PlanStyle planStyle = PlanStyle.balanced,
    bool difficultyAware = false,
    Map<int, List<PlannedActivity>> scheduledContext =
        const <int, List<PlannedActivity>>{},
  }) {
    final rng = Random(seed);
    final activitiesPool = pool.where((activity) => activity.enabled).toList()
      ..shuffle(rng);

    // Template: activity counts per day. Shuffled each regeneration so rest
    // days move around. Totals: gentle ~3, balanced ~5, push ~7.
    final template = switch (planStyle) {
      PlanStyle.gentle => [0, 1, 0, 1, 0, 0, 1],
      PlanStyle.balanced => [1, 0, 1, 1, 0, 1, 1],
      PlanStyle.push => [1, 2, 0, 1, 1, 2, 0],
    };
    template.shuffle(rng);

    // Must-include activities are scheduled before flexible suggestions, so
    // they claim their days first. They are additive baseline items, not a
    // bite out of the day's normal plan-style quota: the flexible loop below
    // still fills the day's full template target count regardless of how
    // many must-include items already landed on it, so a must-include
    // activity can't crowd out normal plan variety. Computed before the
    // flexible loop runs but doesn't consume rng draws unless at least one
    // pool activity has mustIncludeInPlans set, so existing flexible-only
    // pools see unchanged scheduling.
    final mustIncludeByDay = _scheduleMustIncludeActivities(
      pool: activitiesPool,
      weekStart: weekStart,
      rng: rng,
    );

    final plans = <DayPlan>[];
    final scheduledCounts = <String, int>{};
    final scheduledDays = _scheduledDaysFromContext(scheduledContext);
    final hardDayCounts = _hardDayCountsFrom(scheduledContext);
    var targetActivityCount = 0;
    var scheduledActivityCount = 0;

    // Credits every must-include placement to scheduledCounts/scheduledDays/
    // hardDayCounts up front, before any flexible picks happen. Without
    // this, a day with no must-include item that's iterated before a later
    // day that does have one would still see that activity as under its
    // maxPerWeek cap (since the cap had only been "spent" on days visited
    // so far) and could double-book it via flexible fill.
    for (final entry in mustIncludeByDay.entries) {
      for (final act in entry.value) {
        scheduledCounts[act.id] = (scheduledCounts[act.id] ?? 0) + 1;
        scheduledDays.putIfAbsent(act.id, () => <int>[]).add(entry.key);
        if (_isHard(act)) {
          hardDayCounts[entry.key] = (hardDayCounts[entry.key] ?? 0) + 1;
        }
      }
    }

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final targetCount = template[i];
      targetActivityCount += targetCount;
      final activities = <PlannedActivity>[];

      final mustItemsForDay = mustIncludeByDay[i] ?? const <Activity>[];
      for (final act in mustItemsForDay) {
        scheduledActivityCount++;
        activities.add(
          PlannedActivity(
            activity: act,
            timeSlot: _timeSlotFor(act),
            status: CheckStatus.none,
          ),
        );
      }

      // Must-include items above are additive, not subtracted from this
      // count: flexible fill always targets the day's full normal
      // plan-style quota, so a must-include placement never shrinks how
      // much flexible variety the day gets. On top of that, a plan-style
      // "rest day" (targetCount 0) that a must-include item already
      // claimed still gets a chance at exactly one flexible activity, so
      // must-include means "added first, the plan still fills the rest
      // around it," not "this item alone satisfies the day." Days with no
      // must-include item keep the plan style's normal zero-target rest
      // days untouched. This doesn't change targetActivityCount: it's an
      // opportunistic top-up on top of the plan style's ask, not a new
      // formal target diagnostics should flag as blocked if unfilled.
      final flexibleAttempts =
          targetCount == 0 && mustItemsForDay.isNotEmpty ? 1 : targetCount;
      for (var j = 0; j < flexibleAttempts; j++) {
        final act = _pickActivity(
          pool: activitiesPool,
          weekday: date.weekday,
          dayIndex: i,
          scheduledCounts: scheduledCounts,
          scheduledDays: scheduledDays,
          hardDayCounts: hardDayCounts,
          difficultyAware: difficultyAware,
          rng: rng,
        );
        if (act == null) break;

        scheduledCounts[act.id] = (scheduledCounts[act.id] ?? 0) + 1;
        scheduledDays.putIfAbsent(act.id, () => <int>[]).add(i);
        if (_isHard(act)) {
          hardDayCounts[i] = (hardDayCounts[i] ?? 0) + 1;
        }
        scheduledActivityCount++;
        activities.add(
          PlannedActivity(
            activity: act,
            timeSlot: _timeSlotFor(act),
            status: CheckStatus.none,
          ),
        );
      }
      activities.sort(
        (a, b) => timeRank(a.timeSlot).compareTo(timeRank(b.timeSlot)),
      );
      plans.add(DayPlan(date: date, activities: activities));
    }

    final mustIncludeShortfallCount = _mustIncludeShortfall(
      pool: activitiesPool,
      scheduledCounts: scheduledCounts,
    );

    return PlannerGenerationResult(
      plan: plans,
      targetActivityCount: targetActivityCount,
      scheduledActivityCount: scheduledActivityCount,
      enabledActivityCount: activitiesPool.length,
      mustIncludeShortfallCount: mustIncludeShortfallCount,
    );
  }

  /// For each [pool] activity with `mustIncludeInPlans` set, deterministically
  /// (via [rng], derived from the generation seed) picks which day indices
  /// (0-6, relative to [weekStart]) it will be scheduled on: all of its
  /// `allowedWeekdays` if there are no more of them than `maxPerWeek`,
  /// otherwise a shuffled subset of size `maxPerWeek`. Every weekday occurs
  /// exactly once in any 7-day window, so this never competes with other
  /// must-include activities for a day and never needs to consult
  /// noConsecutiveDays/difficulty-spacing - those stay soft preferences that
  /// only shape the flexible fill afterward.
  static Map<int, List<Activity>> _scheduleMustIncludeActivities({
    required List<Activity> pool,
    required DateTime weekStart,
    required Random rng,
  }) {
    final weekdayToIndex = <int, int>{
      for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)).weekday: i,
    };

    final byDay = <int, List<Activity>>{};
    for (final activity in pool.where((a) => a.mustIncludeInPlans)) {
      final allowedDayIndices = activity.allowedWeekdays
          .map((weekday) => weekdayToIndex[weekday])
          .whereType<int>()
          .toList();
      if (allowedDayIndices.isEmpty) continue;

      final chosenDayIndices = allowedDayIndices.length <= activity.maxPerWeek
          ? allowedDayIndices
          : (List<int>.from(allowedDayIndices)..shuffle(rng))
              .take(activity.maxPerWeek)
              .toList();

      for (final dayIndex in chosenDayIndices) {
        byDay.putIfAbsent(dayIndex, () => <Activity>[]).add(activity);
      }
    }
    return byDay;
  }

  /// Sum of how far each must-include activity's actual scheduled count
  /// fell short of its `maxPerWeek`. Only nonzero when `maxPerWeek` exceeds
  /// `allowedWeekdays.length` (normally prevented by the activity editor's
  /// clamp, but possible for legacy/imported data), since otherwise
  /// [_scheduleMustIncludeActivities] always reaches `maxPerWeek` exactly.
  static int _mustIncludeShortfall({
    required List<Activity> pool,
    required Map<String, int> scheduledCounts,
  }) {
    var shortfall = 0;
    for (final activity in pool.where((a) => a.mustIncludeInPlans)) {
      final achieved = scheduledCounts[activity.id] ?? 0;
      if (achieved < activity.maxPerWeek) {
        shortfall += activity.maxPerWeek - achieved;
      }
    }
    return shortfall;
  }

  static Activity? _pickActivity({
    required List<Activity> pool,
    required int weekday,
    required int dayIndex,
    required Map<String, int> scheduledCounts,
    required Map<String, List<int>> scheduledDays,
    required Map<int, int> hardDayCounts,
    required bool difficultyAware,
    required Random rng,
  }) {
    final strictCandidates = _eligibleActivities(
      pool: pool,
      weekday: weekday,
      dayIndex: dayIndex,
      scheduledCounts: scheduledCounts,
      scheduledDays: scheduledDays,
      enforceNoConsecutive: true,
    );
    if (strictCandidates.isEmpty) return null;
    if (difficultyAware) {
      return _chooseDifficultyAware(
        strictCandidates,
        scheduledCounts,
        hardDayCounts,
        dayIndex,
        rng,
      );
    }
    return _chooseLeastUsed(strictCandidates, scheduledCounts, rng);
  }

  static List<Activity> _eligibleActivities({
    required List<Activity> pool,
    required int weekday,
    required int dayIndex,
    required Map<String, int> scheduledCounts,
    required Map<String, List<int>> scheduledDays,
    required bool enforceNoConsecutive,
  }) {
    return pool.where((activity) {
      if (!activity.enabled) return false;
      if (!activity.allowedWeekdays.contains(weekday)) return false;
      final daysForActivity = scheduledDays[activity.id] ?? const [];
      if (daysForActivity.contains(dayIndex)) return false;
      if ((scheduledCounts[activity.id] ?? 0) >= activity.maxPerWeek) {
        return false;
      }
      if (enforceNoConsecutive &&
          activity.noConsecutiveDays &&
          _hasAdjacentDay(daysForActivity, dayIndex)) {
        return false;
      }
      return true;
    }).toList();
  }

  static bool _hasAdjacentDay(List<int> days, int dayIndex) {
    return days.any((day) => (day - dayIndex).abs() == 1);
  }

  static Activity _chooseLeastUsed(
    List<Activity> candidates,
    Map<String, int> scheduledCounts,
    Random rng,
  ) {
    final shuffled = List<Activity>.from(candidates)..shuffle(rng);
    shuffled.sort(
      (a, b) => (scheduledCounts[a.id] ?? 0).compareTo(
        scheduledCounts[b.id] ?? 0,
      ),
    );
    return shuffled.first;
  }

  static Activity? _chooseDifficultyAware(
    List<Activity> candidates,
    Map<String, int> scheduledCounts,
    Map<int, int> hardDayCounts,
    int dayIndex,
    Random rng,
  ) {
    final nearbyHard = _hasNearbyHardDay(hardDayCounts, dayIndex);
    final preferred = candidates
        .where((activity) => !_isHard(activity) || !nearbyHard)
        .toList();

    if (preferred.isEmpty) {
      return null;
    }

    final shuffled = List<Activity>.from(preferred)..shuffle(rng);
    shuffled.sort((a, b) {
      final usedCompare = (scheduledCounts[a.id] ?? 0).compareTo(
        scheduledCounts[b.id] ?? 0,
      );
      if (usedCompare != 0) return usedCompare;
      return _difficultyPlacementScore(a, hardDayCounts, dayIndex).compareTo(
        _difficultyPlacementScore(b, hardDayCounts, dayIndex),
      );
    });
    return shuffled.first;
  }

  /// Seeds same/adjacent-day tracking from [scheduledContext] (see
  /// [generateWithDiagnostics]) so no-consecutive-days can see placements
  /// from outside this single call. Activities already excluded from
  /// [pool] (such as locked items) are unaffected since they're never
  /// evaluated against this map.
  static Map<String, List<int>> _scheduledDaysFromContext(
    Map<int, List<PlannedActivity>> scheduledContext,
  ) {
    final result = <String, List<int>>{};
    for (final entry in scheduledContext.entries) {
      for (final item in entry.value) {
        result.putIfAbsent(item.activity.id, () => <int>[]).add(entry.key);
      }
    }
    return result;
  }

  static Map<int, int> _hardDayCountsFrom(
    Map<int, List<PlannedActivity>> scheduledContext,
  ) {
    final result = <int, int>{};
    for (final entry in scheduledContext.entries) {
      final hardCount =
          entry.value.where((item) => _isHard(item.activity)).length;
      if (hardCount > 0) result[entry.key] = hardCount;
    }
    return result;
  }

  static bool _isHard(Activity activity) => activity.difficulty >= 4;

  static bool _hasNearbyHardDay(Map<int, int> hardDayCounts, int dayIndex) {
    return hardDayCounts.entries.any(
      (entry) => entry.value > 0 && (entry.key - dayIndex).abs() <= 1,
    );
  }

  static int _difficultyPlacementScore(
    Activity activity,
    Map<int, int> hardDayCounts,
    int dayIndex,
  ) {
    if (!_isHard(activity)) return 0;
    final hardDays = hardDayCounts.keys.toList();
    if (hardDays.isEmpty) return 1;
    final nearestDistance =
        hardDays.map((hardDay) => (hardDay - dayIndex).abs()).reduce(min);
    return 10 - nearestDistance.clamp(0, 7).toInt();
  }

  /// Sort rank for a `h:mm AM/PM` display time (e.g. `7:30 PM`), as minutes
  /// since midnight so any actual scheduled time sorts correctly - not just
  /// the fixed set of slots the planner itself generates - since occurrence
  /// time overrides (see `AppState.editPlannedOccurrence`) let a user enter
  /// any time. Unparseable input sorts last.
  static int timeRank(String slot) {
    final parts = slot.trim().split(' ');
    if (parts.length != 2) return 9999;
    final timeParts = parts[0].split(':');
    if (timeParts.length != 2) return 9999;
    var hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (hour == null || minute == null) return 9999;
    final meridiem = parts[1].toUpperCase();
    if (meridiem != 'AM' && meridiem != 'PM') return 9999;
    if (meridiem == 'PM' && hour != 12) hour += 12;
    if (meridiem == 'AM' && hour == 12) hour = 0;
    return hour * 60 + minute;
  }

  static String _timeSlotFor(Activity a) {
    if (a.category == 'Rest') return '7:00 AM';
    if (a.category == 'Outside') return '10:00 AM';
    if (a.preferredTime == 'evening' && a.category == 'Couple time') {
      return '8:00 PM';
    }
    if (a.preferredTime == 'evening') return '7:00 PM';
    if (a.preferredTime == 'afternoon') return '3:00 PM';
    return '11:00 AM';
  }
}

class PlannerGenerationResult {
  const PlannerGenerationResult({
    required this.plan,
    required this.targetActivityCount,
    required this.scheduledActivityCount,
    required this.enabledActivityCount,
    this.mustIncludeShortfallCount = 0,
  });

  final List<DayPlan> plan;
  final int targetActivityCount;
  final int scheduledActivityCount;
  final int enabledActivityCount;

  /// See [PlannerService._mustIncludeShortfall].
  final int mustIncludeShortfallCount;

  int get unfilledActivityCount => targetActivityCount - scheduledActivityCount;

  bool get hasBlockedActivitySlots =>
      enabledActivityCount > 0 && unfilledActivityCount > 0;
}
