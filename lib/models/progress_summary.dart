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

class RhythmProgressSummary {
  const RhythmProgressSummary({
    required this.currentStreakDays,
    required this.past7DonePartly,
    required this.previous7DonePartly,
    required this.past7Planned,
    required this.previous7Planned,
  });

  final int currentStreakDays;
  final int past7DonePartly;
  final int previous7DonePartly;
  final int past7Planned;
  final int previous7Planned;

  int get comparisonDelta => past7DonePartly - previous7DonePartly;
  bool get hasAnyHistory => past7Planned > 0 || previous7Planned > 0;
  bool get hasComparisonHistory => previous7Planned > 0;
}

class UpcomingActivitySummary {
  const UpcomingActivitySummary({
    required this.date,
    required this.time,
    required this.title,
    required this.category,
  });

  final DateTime date;
  final String time;
  final String title;
  final String category;
}

class LookingAheadSummary {
  const LookingAheadSummary({
    required this.days,
    required this.planned,
    required this.activities,
  });

  final int days;
  final int planned;
  final List<UpcomingActivitySummary> activities;

  bool get hasUpcoming => planned > 0;
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

  static RhythmProgressSummary rhythm(
    List<DayPlan> plans, {
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final past7Start = today.subtract(const Duration(days: 6));
    final previous7Start = today.subtract(const Duration(days: 13));
    final previous7End = today.subtract(const Duration(days: 7));

    var past7Planned = 0;
    var past7DonePartly = 0;
    var previous7Planned = 0;
    var previous7DonePartly = 0;
    final hasDoneOrPartlyByDate = <DateTime, bool>{};

    for (final day in plans) {
      final date = _dateOnly(day.date);
      if (date.isAfter(today)) continue;

      final dayDonePartly = day.activities
          .where((activity) => _isDoneOrPartly(activity.status))
          .length;
      if (dayDonePartly > 0) {
        hasDoneOrPartlyByDate[date] = true;
      }

      if (!date.isBefore(past7Start)) {
        past7Planned += day.activities.length;
        past7DonePartly += dayDonePartly;
      } else if (!date.isBefore(previous7Start) &&
          !date.isAfter(previous7End)) {
        previous7Planned += day.activities.length;
        previous7DonePartly += dayDonePartly;
      }
    }

    var currentStreakDays = 0;
    var cursor = today;
    while (hasDoneOrPartlyByDate[cursor] == true) {
      currentStreakDays++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    return RhythmProgressSummary(
      currentStreakDays: currentStreakDays,
      past7DonePartly: past7DonePartly,
      previous7DonePartly: previous7DonePartly,
      past7Planned: past7Planned,
      previous7Planned: previous7Planned,
    );
  }

  static LookingAheadSummary lookingAhead(
    List<DayPlan> plans, {
    int days = 7,
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final end = today.add(Duration(days: days - 1));
    final upcoming = <_UpcomingCandidate>[];

    for (final day in plans) {
      final date = _dateOnly(day.date);
      if (date.isBefore(today) || date.isAfter(end)) continue;

      for (final activity in day.activities) {
        upcoming.add(
          _UpcomingCandidate(
            date: date,
            time: activity.time,
            title: activity.title,
            category: activity.category,
          ),
        );
      }
    }

    upcoming.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;
      return _timeRank(a.time).compareTo(_timeRank(b.time));
    });

    return LookingAheadSummary(
      days: days,
      planned: upcoming.length,
      activities: upcoming
          .take(3)
          .map(
            (activity) => UpcomingActivitySummary(
              date: activity.date,
              time: activity.time,
              title: activity.title,
              category: activity.category,
            ),
          )
          .toList(),
    );
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isDoneOrPartly(CheckStatus status) =>
      status == CheckStatus.done || status == CheckStatus.partly;

  static int _timeRank(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(value.trim());
    if (match == null) return 24 * 60;

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = (match.group(3) ?? '').toUpperCase();
    if (period == 'AM' && hour == 12) hour = 0;
    if (period == 'PM' && hour != 12) hour += 12;
    return hour * 60 + minute;
  }
}

class _UpcomingCandidate {
  const _UpcomingCandidate({
    required this.date,
    required this.time,
    required this.title,
    required this.category,
  });

  final DateTime date;
  final String time;
  final String title;
  final String category;
}
