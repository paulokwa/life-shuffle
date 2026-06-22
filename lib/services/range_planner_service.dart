import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/generated_plan_range.dart';
import '../models/range_type.dart';
import 'planner_service.dart';

/// Generates a [GeneratedPlanRange] for a given [RangeType], reusing
/// [PlannerService] internally rather than duplicating its scheduling
/// logic.
class RangePlannerService {
  RangePlannerService._();

  static const _daysPerWeek = 7;

  /// Generates a [GeneratedPlanRange] starting at [start]. For
  /// [RangeType.week] and [RangeType.twoWeek], [start] must be the Monday
  /// of the first generated week, matching [PlannerService.generate]'s
  /// existing contract. For [RangeType.month], [start] is any date in the
  /// target calendar month.
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
        return _generateMonth(
          start: start,
          pool: pool,
          seed: seed,
          planStyle: planStyle,
          difficultyAware: difficultyAware,
          scheduledContext: scheduledContext,
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

  /// Generates Monday-aligned 7-day chunks via [PlannerService] covering
  /// [start]'s calendar month, then clips the result down to that month's
  /// actual days (the first/last chunk may extend into the previous or
  /// next month). [scheduledContext] is global-day-indexed relative to the
  /// Monday-aligned start of the first chunk (which may fall before the
  /// 1st of the month) and is split per chunk before being passed down,
  /// the same scheme [_generateTwoWeek] uses for two chunks. Each chunk
  /// after the first additionally receives the previous chunk's final day
  /// under key `-1` so no-consecutive-days and difficulty spacing carry
  /// across every week boundary in the month. Each chunk gets its own seed
  /// (`seed + chunkIndex`) so weeks don't shuffle identically.
  static RangePlannerGenerationResult _generateMonth({
    required DateTime start,
    required List<Activity> pool,
    required int seed,
    required PlanStyle planStyle,
    required bool difficultyAware,
    required Map<int, List<PlannedActivity>> scheduledContext,
  }) {
    final monthStart = DateTime(start.year, start.month, 1);
    final monthEnd = DateTime(start.year, start.month + 1, 0);
    final internalStart = PlannerService.mondayOf(monthStart);
    final internalEnd = PlannerService.mondayOf(monthEnd)
        .add(const Duration(days: _daysPerWeek - 1));

    final allDays = <DayPlan>[];
    var targetActivityCount = 0;
    var scheduledActivityCount = 0;
    var enabledActivityCount = 0;
    var previousChunkLastDay = const <PlannedActivity>[];
    var chunkStart = internalStart;
    var chunkIndex = 0;

    while (!chunkStart.isAfter(internalEnd)) {
      final chunkOffset = chunkIndex * _daysPerWeek;
      final chunkContext = <int, List<PlannedActivity>>{
        for (final entry in scheduledContext.entries)
          if (entry.key >= chunkOffset &&
              entry.key < chunkOffset + _daysPerWeek)
            entry.key - chunkOffset: entry.value,
      };
      if (previousChunkLastDay.isNotEmpty) {
        chunkContext[-1] = previousChunkLastDay;
      }

      final chunk = PlannerService.generateWithDiagnostics(
        weekStart: chunkStart,
        pool: pool,
        seed: seed + chunkIndex,
        planStyle: planStyle,
        difficultyAware: difficultyAware,
        scheduledContext: chunkContext,
      );

      targetActivityCount += chunk.targetActivityCount;
      scheduledActivityCount += chunk.scheduledActivityCount;
      enabledActivityCount = chunk.enabledActivityCount;
      allDays.addAll(chunk.plan);
      previousChunkLastDay = chunk.plan.last.activities;

      chunkStart = chunkStart.add(const Duration(days: _daysPerWeek));
      chunkIndex++;
    }

    final monthDays = allDays
        .where(
          (day) =>
              !day.date.isBefore(monthStart) && !day.date.isAfter(monthEnd),
        )
        .toList();

    return RangePlannerGenerationResult(
      range: GeneratedPlanRange(type: RangeType.month, days: monthDays),
      targetActivityCount: targetActivityCount,
      scheduledActivityCount: scheduledActivityCount,
      enabledActivityCount: enabledActivityCount,
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
