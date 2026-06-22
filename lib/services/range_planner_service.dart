import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/generated_plan_range.dart';
import '../models/range_type.dart';
import 'planner_service.dart';

/// Generates a [GeneratedPlanRange] for a given [RangeType], reusing
/// [PlannerService] internally rather than duplicating its scheduling
/// logic. Only [RangeType.week] is implemented; [RangeType.twoWeek] and
/// [RangeType.month] are later MVP 2 slices.
class RangePlannerService {
  RangePlannerService._();

  /// Generates a [GeneratedPlanRange] starting at [start]. For
  /// [RangeType.week], [start] must be the Monday of that week, matching
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
      case RangeType.month:
        throw UnimplementedError(
          'RangePlannerService does not generate $type yet.',
        );
    }
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
