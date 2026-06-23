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

  /// Generates a [GeneratedPlanRange] of [type] covering
  /// `type.horizonDays(start)` consecutive days starting at [start]
  /// (normally today). Never includes a day before [start].
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
    return _generateHorizon(
      type: type,
      start: start,
      dayCount: type.horizonDays(start),
      pool: pool,
      seed: seed,
      planStyle: planStyle,
      difficultyAware: difficultyAware,
      scheduledContext: scheduledContext,
    );
  }

  /// Generates [dayCount] consecutive days starting at [start] via
  /// Planner-aligned 7-day chunks, stitching them together. [scheduledContext]
  /// is global-day-indexed relative to [start] (0-6 for chunk 1, 7-13 for
  /// chunk 2, and so on) and is split per chunk before being passed down;
  /// each chunk after the first additionally receives the previous chunk's
  /// final day under key `-1` so no-consecutive-days and difficulty spacing
  /// carry across every chunk boundary. Each chunk gets its own seed
  /// (`seed + chunkIndex`) so chunks don't shuffle identically. The final
  /// chunk may generate a few days past [dayCount]; those are clipped off
  /// rather than ever generating a day before [start].
  static RangePlannerGenerationResult _generateHorizon({
    required RangeType type,
    required DateTime start,
    required int dayCount,
    required List<Activity> pool,
    required int seed,
    required PlanStyle planStyle,
    required bool difficultyAware,
    required Map<int, List<PlannedActivity>> scheduledContext,
  }) {
    final allDays = <DayPlan>[];
    var targetActivityCount = 0;
    var scheduledActivityCount = 0;
    var enabledActivityCount = 0;
    var mustIncludeShortfallCount = 0;
    var previousChunkLastDay = const <PlannedActivity>[];
    var chunkStart = start;
    var chunkIndex = 0;
    var generatedCount = 0;

    while (generatedCount < dayCount) {
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
      mustIncludeShortfallCount += chunk.mustIncludeShortfallCount;
      allDays.addAll(chunk.plan);
      previousChunkLastDay = chunk.plan.last.activities;

      generatedCount += _daysPerWeek;
      chunkStart = chunkStart.add(const Duration(days: _daysPerWeek));
      chunkIndex++;
    }

    final horizonEnd = start.add(Duration(days: dayCount - 1));
    final clippedDays = allDays
        .where(
          (day) => !day.date.isBefore(start) && !day.date.isAfter(horizonEnd),
        )
        .toList();

    return RangePlannerGenerationResult(
      range: GeneratedPlanRange(type: type, days: clippedDays),
      targetActivityCount: targetActivityCount,
      scheduledActivityCount: scheduledActivityCount,
      enabledActivityCount: enabledActivityCount,
      mustIncludeShortfallCount: mustIncludeShortfallCount,
    );
  }
}

class RangePlannerGenerationResult {
  const RangePlannerGenerationResult({
    required this.range,
    required this.targetActivityCount,
    required this.scheduledActivityCount,
    required this.enabledActivityCount,
    this.mustIncludeShortfallCount = 0,
  });

  final GeneratedPlanRange range;
  final int targetActivityCount;
  final int scheduledActivityCount;
  final int enabledActivityCount;

  /// Sum of [PlannerGenerationResult.mustIncludeShortfallCount] across every
  /// weekly chunk in this horizon.
  final int mustIncludeShortfallCount;

  int get unfilledActivityCount => targetActivityCount - scheduledActivityCount;

  bool get hasBlockedActivitySlots =>
      enabledActivityCount > 0 && unfilledActivityCount > 0;
}
