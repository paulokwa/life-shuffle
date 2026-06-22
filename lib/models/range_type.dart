/// How many days a generated plan should cover.
enum RangeType { week, twoWeek, month }

RangeType rangeTypeFromName(String? value) {
  return RangeType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => RangeType.week,
  );
}
