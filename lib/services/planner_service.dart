import 'dart:math';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;

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
  static List<DayPlan> generate({
    required DateTime weekStart,
    required List<Activity> pool,
    required int seed,
  }) {
    final rng = Random(seed);
    final activitiesPool = pool.where((activity) => activity.enabled).toList()
      ..shuffle(rng);

    // Template: 7 slots across 7 days. Shuffling the template moves rest days
    // around each week/regeneration.
    final template = [1, 2, 0, 1, 1, 2, 0];
    template.shuffle(rng);

    final plans = <DayPlan>[];
    final scheduledCounts = <String, int>{};
    final scheduledDays = <String, List<int>>{};

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final targetCount = template[i];
      final activities = <PlannedActivity>[];

      for (var j = 0; j < targetCount; j++) {
        final act = _pickActivity(
          pool: activitiesPool,
          weekday: date.weekday,
          dayIndex: i,
          scheduledCounts: scheduledCounts,
          scheduledDays: scheduledDays,
          rng: rng,
        );
        if (act == null) break;

        scheduledCounts[act.id] = (scheduledCounts[act.id] ?? 0) + 1;
        scheduledDays.putIfAbsent(act.id, () => <int>[]).add(i);
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

    return plans;
  }

  static Activity? _pickActivity({
    required List<Activity> pool,
    required int weekday,
    required int dayIndex,
    required Map<String, int> scheduledCounts,
    required Map<String, List<int>> scheduledDays,
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

  static int timeRank(String slot) {
    const order = [
      '7:00 AM',
      '9:00 AM',
      '10:00 AM',
      '11:00 AM',
      '12:00 PM',
      '3:00 PM',
      '6:30 PM',
      '7:00 PM',
      '8:00 PM',
    ];
    final i = order.indexOf(slot);
    return i < 0 ? 99 : i;
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
