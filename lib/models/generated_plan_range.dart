import 'day_plan.dart';
import 'range_type.dart';

/// The realized output of planning a [RangeType]: the days it covers and
/// each day's planned activities. For [RangeType.week], [days] is exactly
/// the same 7 days [AppState.weekPlan] already exposes.
class GeneratedPlanRange {
  const GeneratedPlanRange({required this.type, required this.days});

  final RangeType type;
  final List<DayPlan> days;
}
