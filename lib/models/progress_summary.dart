import 'day_plan.dart';
import 'mock_data.dart' show CheckStatus;

class ProgressSummary {
  const ProgressSummary({
    required this.days,
    required this.planned,
    required this.done,
    required this.partly,
    required this.skipped,
    required this.unchecked,
  });

  final int days;
  final int planned;
  final int done;
  final int partly;
  final int skipped;
  final int unchecked;

  int get checked => done + partly + skipped;
  bool get hasHistory => planned > 0;
}

class DifficultyProgressSummary {
  const DifficultyProgressSummary({
    required this.days,
    required this.planned,
    required this.done,
    required this.partly,
    required this.skipped,
  });

  final int days;
  final int planned;
  final int done;
  final int partly;
  final int skipped;

  bool get hasHardActivities => planned > 0;
}

class ProgressSummaryCalculator {
  const ProgressSummaryCalculator._();

  static ProgressSummary recent(
    List<DayPlan> plans, {
    required int days,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(Duration(days: days - 1));

    var planned = 0;
    var done = 0;
    var partly = 0;
    var skipped = 0;
    var unchecked = 0;

    for (final day in plans) {
      final date = _dateOnly(day.date);
      if (date.isBefore(start) || date.isAfter(today)) continue;

      for (final activity in day.activities) {
        planned++;
        switch (activity.status) {
          case CheckStatus.done:
            done++;
          case CheckStatus.partly:
            partly++;
          case CheckStatus.skipped:
            skipped++;
          case CheckStatus.none:
            unchecked++;
        }
      }
    }

    return ProgressSummary(
      days: days,
      planned: planned,
      done: done,
      partly: partly,
      skipped: skipped,
      unchecked: unchecked,
    );
  }

  static DifficultyProgressSummary recentHard(
    List<DayPlan> plans, {
    required int days,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final start = today.subtract(Duration(days: days - 1));

    var planned = 0;
    var done = 0;
    var partly = 0;
    var skipped = 0;

    for (final day in plans) {
      final date = _dateOnly(day.date);
      if (date.isBefore(start) || date.isAfter(today)) continue;

      for (final activity in day.activities) {
        if (activity.activity.difficulty < 4) continue;
        planned++;
        switch (activity.status) {
          case CheckStatus.done:
            done++;
          case CheckStatus.partly:
            partly++;
          case CheckStatus.skipped:
            skipped++;
          case CheckStatus.none:
            break;
        }
      }
    }

    return DifficultyProgressSummary(
      days: days,
      planned: planned,
      done: done,
      partly: partly,
      skipped: skipped,
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
