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
    final shuffled = List<Activity>.from(pool)..shuffle(rng);

    // Template: 7 slots across 7 days. Shuffling the template moves rest days
    // around each week/regeneration.
    final template = [1, 2, 0, 1, 1, 2, 0];
    template.shuffle(rng);

    final plans = <DayPlan>[];
    var idx = 0;

    for (var i = 0; i < 7; i++) {
      final date = weekStart.add(Duration(days: i));
      final count = idx < shuffled.length
          ? template[i].clamp(0, shuffled.length - idx)
          : 0;

      final activities = <PlannedActivity>[];
      for (var j = 0; j < count && idx < shuffled.length; j++) {
        final act = shuffled[idx++];
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
