import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/generated_plan_range.dart';
import '../models/range_type.dart';
import 'planner_service.dart';

/// Generates a [GeneratedPlanRange] for a given [RangeType], reusing
/// [PlannerService] internally rather than duplicating its scheduling
/// logic. [RangeType.week] and [RangeType.twoWeek] are implemented;
/// [RangeType.month] is a later MVP 2 slice.
class RangePlannerService {
  RangePlannerService._();

  static const _daysPerWeek = 7;

  /// Generates a [GeneratedPlanRange] starting at [start]. [start] must be
  /// the Monday of the first generated week, matching
  /// [PlannerService.generate]'s existing contract.
  static GeneratedPlanRange generate({
    required RangeType type,
    required DateTime start,
    required List<Activity> pool,
    required int seed,
    PlanStyle planStyle = PlanStyle.balanced,
    bool difficultyAware = false,
    Map<int, List<PlannedActivity>> scheduledContext =
        const <int, List<PlannedActivity>>{},
  }) {
    return generateWithDiagnostics(
      type: type,
      start: start,
      pool: pool,
      seed: seed,
      planStyle: planStyle,
      difficultyAware: difficultyAware,
      scheduledContext: scheduledContext,
    ).range;
  }

  static RangePlannerGenerationResult generateWithDiagnostics({
    required RangeType type,
    required DateTime start,
    required List<Activity> pool,
    required int seed,
    PlanStyle planStyle = PlanStyle.balanced,
    bool difficultyAware = false,
    Map<int, List<PlannedActivity>> scheduledContext =
        const <int, List<PlannedActivity>>{},
  }) {
    switch (type) {
      case RangeType.week:
        final weekResult = PlannerService.generateWithDiagnostics(
          weekStart: start,
          pool: pool,
          seed: seed,
          planStyle: planStyle,
          difficultyAware: difficultyAware,
          scheduledContext: scheduledContext,
        );
        return RangePlannerGenerationResult(
          range: GeneratedPlanRange(type: type, days: weekResult.plan),
          targetActivityCount: weekResult.targetActivityCount,
          scheduledActivityCount: weekResult.scheduledActivityCount,
          enabledActivityCount: weekResult.enabledActivityCount,
        );
      case RangeType.twoWeek:
        return _generateTwoWeek(
          start: start,
          pool: pool,
          seed: seed,
          planStyle: planStyle,
          difficultyAware: difficultyAware,
          scheduledContext: scheduledContext,
        );
      case RangeType.month:
        throw UnimplementedError(
          'RangePlannerService does not generate $type yet.',
        );
    }
  }

  /// Generates two Monday-aligned 7-day chunks via [PlannerService],
  /// stitching them into 14 days. [scheduledContext] is global-day-indexed
  /// (0-6 for week 1, 7-13 for week 2) and split per chunk before being
  /// passed down; week 2 additionally receives week 1's final day under
  /// key `-1` so no-consecutive-days and difficulty spacing carry across
  /// the Sunday-to-Monday boundary. Each week gets its own seed
  /// (`seed`, `seed + 1`) so they don't shuffle identically.
  static RangePlannerGenerationResult _generateTwoWeek({
    required DateTime start,
    required List<Activity> pool,
    required int seed,
    required PlanStyle planStyle,
    required bool difficultyAware,
    required Map<int, List<PlannedActivity>> scheduledContext,
  }) {
    final week1Start = start;
    final week2Start = start.add(const Duration(days: _daysPerWeek));

    final week1Context = <int, List<PlannedActivity>>{
      for (final entry in scheduledContext.entries)
        if (entry.key >= 0 && entry.key < _daysPerWeek) entry.key: entry.value,
    };
    final week2LockedContext = <int, List<PlannedActivity>>{
      for (final entry in scheduledContext.entries)
        if (entry.key >= _daysPerWeek && entry.key < _daysPerWeek * 2)
          entry.key - _daysPerWeek: entry.value,
    };

    final week1 = PlannerService.generateWithDiagnostics(
      weekStart: week1Start,
      pool: pool,
      seed: seed,
      planStyle: planStyle,
      difficultyAware: difficultyAware,
      scheduledContext: week1Context,
    );

    final week2Context = <int, List<PlannedActivity>>{
      ...week2LockedContext,
      -1: week1.plan.last.activities,
    };
    final week2 = PlannerService.generateWithDiagnostics(
      weekStart: week2Start,
      pool: pool,
      seed: seed + 1,
      planStyle: planStyle,
      difficultyAware: difficultyAware,
      scheduledContext: week2Context,
    );

    return RangePlannerGenerationResult(
      range: GeneratedPlanRange(
        type: RangeType.twoWeek,
        days: [...week1.plan, ...week2.plan],
      ),
      targetActivityCount:
          week1.targetActivityCount + week2.targetActivityCount,
      scheduledActivityCount:
          week1.scheduledActivityCount + week2.scheduledActivityCount,
      enabledActivityCount: week1.enabledActivityCount,
    );
  }
}

class RangePlannerGenerationResult {
  const RangePlannerGenerationResult({
    required this.range,
    required this.targetActivityCount,
    required this.scheduledActivityCount,
    required this.enabledActivityCount,
  });

  final GeneratedPlanRange range;
  final int targetActivityCount;
  final int scheduledActivityCount;
  final int enabledActivityCount;

  int get unfilledActivityCount => targetActivityCount - scheduledActivityCount;

  bool get hasBlockedActivitySlots =>
      enabledActivityCount > 0 && unfilledActivityCount > 0;
}
