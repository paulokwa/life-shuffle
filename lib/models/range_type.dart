/// How many days a generated plan should cover.
enum RangeType { week, twoWeek, month }

RangeType rangeTypeFromName(String? value) {
  return RangeType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => RangeType.week,
  );
}

/// Like [rangeTypeFromName], but returns `null` instead of defaulting to
/// [RangeType.week] when [value] is absent/unrecognized, so callers can
/// apply a more specific fallback (e.g. defaulting view mode to whatever
/// range type was actually generated).
RangeType? rangeTypeFromNameOrNull(String? value) {
  if (value == null) return null;
  for (final type in RangeType.values) {
    if (type.name == value) return type;
  }
  return null;
}

extension RangeTypeHorizon on RangeType {
  /// Day count a freshly generated range of this type covers when anchored
  /// at [start] (normally today). [month] varies with [start] since
  /// calendar months vary in length; it is defined as [start] through the
  /// day before the same date next month, so it never pulls in a partial
  /// extra day.
  int horizonDays(DateTime start) {
    switch (this) {
      case RangeType.week:
        return 7;
      case RangeType.twoWeek:
        return 14;
      case RangeType.month:
        final nextMonthSameDay =
            DateTime(start.year, start.month + 1, start.day);
        return nextMonthSameDay.difference(start).inDays;
    }
  }
}
