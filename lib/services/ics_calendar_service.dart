import '../models/day_plan.dart';
import '../models/manual_plan_item.dart';
import 'text_week_export_service.dart';

class IcsCalendarService {
  IcsCalendarService._();

  static String generate({
    required String calendarId,
    required String calendarTitle,
    required List<DayPlan> plan,
    DateTime? generatedAt,
    Map<String, ManualPlanItem> manualPlanItemsById = const {},
  }) {
    final timestamp = _formatUtc(generatedAt ?? DateTime.now().toUtc());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Life Shuffle//Life Shuffle Calendar//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${_escapeText(calendarTitle)}',
      'X-WR-CALDESC:${_escapeText('Read-only Life Shuffle plan generated in-app.')}',
    ];

    final items = <_IcsPlannedItem>[];
    for (final day in plan) {
      for (final activity in day.activities) {
        items.add(_IcsPlannedItem(day: day, plannedActivity: activity));
      }
    }
    items.sort((a, b) {
      final dateCompare = a.day.date.compareTo(b.day.date);
      if (dateCompare != 0) return dateCompare;
      return _timeMinutes(a.plannedActivity.timeSlot)
          .compareTo(_timeMinutes(b.plannedActivity.timeSlot));
    });

    for (final item in items) {
      final activity = item.plannedActivity.activity;
      final start = _dateTimeFor(item.day.date, item.plannedActivity.timeSlot);
      final end = start.add(Duration(minutes: activity.durationMinutes));
      final category = activity.category.trim();
      final manualItem = manualPlanItemsById[item.plannedActivity.manualItemId];
      final outsideEventLines = manualItem != null && manualItem.isOutsideEvent
          ? TextWeekExportService.outsideEventDetailLines(manualItem)
          : const <String>[];
      final details = [
        'Duration: ${activity.duration}',
        if (category.isNotEmpty) 'Category: $category',
        ...outsideEventLines,
      ].join('\n');

      lines.addAll([
        'BEGIN:VEVENT',
        'UID:${_eventUid(calendarId, item.day.date, activity.id, item.plannedActivity.timeSlot)}',
        'DTSTAMP:$timestamp',
        'DTSTART:${_formatLocal(start)}',
        'DTEND:${_formatLocal(end)}',
        'SUMMARY:${_escapeText(activity.title)}',
        if (category.isNotEmpty) 'CATEGORIES:${_escapeText(category)}',
        'DESCRIPTION:${_escapeText(details)}',
        'END:VEVENT',
      ]);
    }

    lines.add('END:VCALENDAR');
    return '${lines.map(_foldLine).join('\r\n')}\r\n';
  }

  static String _eventUid(
    String calendarId,
    DateTime date,
    String activityId,
    String timeSlot,
  ) {
    final raw = [
      'life-shuffle',
      calendarId,
      _formatDate(date),
      activityId,
      timeSlot,
    ].join('-');
    final safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9@._-]+'), '-');
    return '$safe@life-shuffle.local';
  }

  static DateTime _dateTimeFor(DateTime date, String timeSlot) {
    final minutes = _timeMinutes(timeSlot);
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  static int _timeMinutes(String timeSlot) {
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])\s*$',
    ).firstMatch(timeSlot);
    if (match == null) return 9 * 60;

    var hour = int.tryParse(match.group(1) ?? '') ?? 9;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final meridiem = (match.group(3) ?? 'AM').toUpperCase();

    if (hour == 12) hour = 0;
    if (meridiem == 'PM') hour += 12;
    return (hour * 60) + minute.clamp(0, 59);
  }

  static String _formatLocal(DateTime dateTime) {
    return '${_formatDate(dateTime)}T'
        '${_two(dateTime.hour)}${_two(dateTime.minute)}${_two(dateTime.second)}';
  }

  static String _formatUtc(DateTime dateTime) {
    final utc = dateTime.toUtc();
    return '${_formatLocal(utc)}Z';
  }

  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${_two(date.month)}'
        '${_two(date.day)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _escapeText(String value) {
    return value
        .replaceAll('\\', r'\\')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\n')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
  }

  static String _foldLine(String line) {
    const maxLength = 75;
    if (line.length <= maxLength) return line;

    final buffer = StringBuffer();
    var remaining = line;
    var first = true;
    while (remaining.length > maxLength) {
      final take = first ? maxLength : maxLength - 1;
      buffer
        ..write(remaining.substring(0, take))
        ..write('\r\n ');
      remaining = remaining.substring(take);
      first = false;
    }
    buffer.write(remaining);
    return buffer.toString();
  }
}

class _IcsPlannedItem {
  const _IcsPlannedItem({
    required this.day,
    required this.plannedActivity,
  });

  final DayPlan day;
  final PlannedActivity plannedActivity;
}
