/// How many days a generated plan should cover.
///
/// Only [week] is actually generated today; [twoWeek] and [month] exist so
/// persisted state and the planning service shape are stable for later
/// slices that add those ranges.
enum RangeType { week, twoWeek, month }

RangeType rangeTypeFromName(String? value) {
  return RangeType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => RangeType.week,
  );
}
