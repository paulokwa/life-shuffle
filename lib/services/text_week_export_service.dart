import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import 'planner_service.dart';

class TextWeekExportService {
  const TextWeekExportService._();

  static String generate({
    required String calendarTitle,
    required List<DayPlan> plan,
    Map<String, String> privateNotesByActivityId = const {},
    bool includePrivateNotes = false,
  }) {
    final sortedPlan = List<DayPlan>.from(plan)
      ..sort((a, b) => a.date.compareTo(b.date));
    final plannedDays =
        sortedPlan.where((day) => day.activities.isNotEmpty).toList();
    final buffer = StringBuffer()
      ..writeln('$calendarTitle week')
      ..writeln(weekRangeLabel(sortedPlan))
      ..writeln();

    if (plannedDays.isEmpty) {
      buffer.writeln('No planned activities this week.');
      return buffer.toString().trimRight();
    }

    for (var dayIndex = 0; dayIndex < plannedDays.length; dayIndex++) {
      final day = plannedDays[dayIndex];
      final activities = List<PlannedActivity>.from(day.activities)
        ..sort(
          (a, b) => PlannerService.timeRank(a.timeSlot)
              .compareTo(PlannerService.timeRank(b.timeSlot)),
        );

      buffer.writeln(_dateLabel(day.date));
      for (final planned in activities) {
        buffer
          ..writeln(
            '- ${planned.timeSlot}, ${planned.title} '
            '(${planned.activity.duration})',
          )
          ..writeln('  Category: ${planned.category}')
          ..writeln('  Check-in: ${_checkStatusLabel(planned.status)}')
          ..writeln('  Locked: ${planned.locked ? "Yes" : "No"}');

        final note = privateNotesByActivityId[planned.activity.id]?.trim();
        if (includePrivateNotes && note != null && note.isNotEmpty) {
          buffer.writeln('  Notes: $note');
        }
      }
      if (dayIndex != plannedDays.length - 1) buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  /// Formatted month/day week range, e.g. `Jun 22-28, 2026`. Callers must
  /// pass an already date-sorted [plan] (also used by the print preview).
  static String weekRangeLabel(List<DayPlan> plan) {
    if (plan.isEmpty) return 'No week selected';
    final first = plan.first.date;
    final last = plan.last.date;
    if (first.year == last.year) {
      return '${_monthDay(first)}-${_monthDay(last)}, ${last.year}';
    }
    return '${_monthDay(first)}, ${first.year}-${_monthDay(last)}, ${last.year}';
  }

  static String _dateLabel(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[date.weekday - 1]}, ${_monthDay(date)}';
  }

  static String _monthDay(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  static String _checkStatusLabel(CheckStatus status) {
    return switch (status) {
      CheckStatus.done => 'Done',
      CheckStatus.partly => 'Partly done',
      CheckStatus.skipped => 'Skipped',
      CheckStatus.none => 'Unchecked',
    };
  }
}
