import 'day_plan.dart';
import 'range_type.dart';

/// The realized output of planning a [RangeType]: the days it covers and
/// each day's planned activities. [type] is what was actually generated
/// (the planning horizon); a screen's view mode may differ from this when
/// the user is just looking at the range differently, not regenerating it.
class GeneratedPlanRange {
  const GeneratedPlanRange({required this.type, required this.days});

  final RangeType type;
  final List<DayPlan> days;

  bool get isEmpty => days.isEmpty;
  DateTime get start => days.first.date;
  DateTime get end => days.last.date;
}
