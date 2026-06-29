import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/export_print_options.dart';
import '../models/manual_plan_item.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/range_type.dart';
import 'planner_service.dart';

class TextWeekExportService {
  const TextWeekExportService._();

  static String generate({
    required String calendarTitle,
    required List<DayPlan> plan,
    RangeType rangeType = RangeType.week,
    ExportPrintOptions options = const ExportPrintOptions(),
    bool difficultyEnabled = false,
    bool energyEnabled = false,
    bool socialEnabled = false,
    Map<String, String> privateNotesByActivityId = const {},
    bool includePrivateNotes = false,
    Map<String, ManualPlanItem> manualPlanItemsById = const {},
  }) {
    final sortedPlan = List<DayPlan>.from(plan)
      ..sort((a, b) => a.date.compareTo(b.date));
    final plannedDays =
        sortedPlan.where((day) => day.activities.isNotEmpty).toList();
    final buffer = StringBuffer()
      ..writeln('$calendarTitle ${_horizonLabel(rangeType)}')
      ..writeln(weekRangeLabel(sortedPlan))
      ..writeln();

    if (plannedDays.isEmpty) {
      buffer.writeln(_emptyMessage(rangeType));
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
        final headParts = [
          if (options.showTime) planned.timeSlot,
          planned.title,
        ];
        var headline = '- ${headParts.join(', ')}';
        if (options.showDuration) {
          headline += ' (${planned.activity.duration})';
        }
        buffer.writeln(headline);
        if (options.showCategory) {
          buffer.writeln('  Category: ${planned.category}');
        }
        if (options.showCheckInStatus) {
          buffer.writeln('  Check-in: ${_checkStatusLabel(planned.status)}');
        }
        if (options.showLockedStatus) {
          buffer.writeln('  Locked: ${planned.locked ? "Yes" : "No"}');
        }
        if (options.showEnabledDimensions) {
          final dims = dimensionLabels(
            difficulty: planned.difficulty,
            energy: planned.energy,
            social: planned.social,
            difficultyEnabled: difficultyEnabled,
            energyEnabled: energyEnabled,
            socialEnabled: socialEnabled,
          );
          if (dims.isNotEmpty) buffer.writeln('  ${dims.join(', ')}');
        }

        final note = privateNotesByActivityId[planned.activity.id]?.trim();
        if (includePrivateNotes && note != null && note.isNotEmpty) {
          buffer.writeln('  Notes: $note');
        }

        if (options.showOutsideEventDetails) {
          final manualItem = manualPlanItemsById[planned.manualItemId];
          if (manualItem != null && manualItem.isOutsideEvent) {
            for (final line in outsideEventDetailLines(manualItem)) {
              buffer.writeln('  $line');
            }
          }
        }
      }
      if (dayIndex != plannedDays.length - 1) buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  /// Plain-text lines describing an outside event's sourced metadata -
  /// venue/address/price, source, tickets, and confidence - for whichever
  /// surface is rendering [item] (text export, print, ICS description).
  /// Returns nothing the source didn't actually provide.
  static List<String> outsideEventDetailLines(ManualPlanItem item) {
    final lines = <String>[];
    final details = [
      if (item.outsideEventVenueName?.trim().isNotEmpty == true)
        item.outsideEventVenueName!.trim(),
      if (item.outsideEventAddress?.trim().isNotEmpty == true)
        item.outsideEventAddress!.trim(),
      if (item.outsideEventPriceLabel?.trim().isNotEmpty == true)
        item.outsideEventPriceLabel!.trim(),
    ];
    if (details.isNotEmpty) lines.add('Venue: ${details.join(' / ')}');
    if (item.outsideEventSourceName?.trim().isNotEmpty == true) {
      lines.add('Source: ${item.outsideEventSourceName!.trim()}');
    }
    if (item.outsideEventSourceUrl?.trim().isNotEmpty == true) {
      lines.add('Link: ${item.outsideEventSourceUrl!.trim()}');
    }
    final ticketUrl = item.outsideEventTicketUrl?.trim();
    if (ticketUrl?.isNotEmpty == true &&
        ticketUrl != item.outsideEventSourceUrl?.trim()) {
      lines.add('Tickets: $ticketUrl');
    }
    if (item.outsideEventConfidence != null) {
      lines.add(
        'Confidence: ${(item.outsideEventConfidence! * 100).round()}%',
      );
    }
    if (item.outsideEventUncertainFields.isNotEmpty) {
      lines.add('Uncertain: ${item.outsideEventUncertainFields.join(', ')}');
    }
    return lines;
  }

  /// Compact labels for enabled planning dimensions, e.g. `Difficulty 3/5`.
  /// Only includes a dimension when its Settings > Activity defaults toggle
  /// is on; also used by the print preview so both surfaces describe
  /// dimensions identically. Callers pass [PlannedActivity.difficulty]/
  /// `.energy`/`.social` (not the source [Activity]'s) so an occurrence
  /// override - see `AppState.editPlannedOccurrence` - is reflected here
  /// too.
  static List<String> dimensionLabels({
    required int difficulty,
    required String energy,
    required String social,
    required bool difficultyEnabled,
    required bool energyEnabled,
    required bool socialEnabled,
  }) {
    return [
      if (difficultyEnabled) 'Difficulty $difficulty/5',
      if (energyEnabled) 'Energy: ${Activity.optionLabel(energy)}',
      if (socialEnabled) 'Social: ${Activity.optionLabel(social)}',
    ];
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

  /// Word following the calendar title in the export header, e.g.
  /// `Kwame and Laura week` / `... 2 weeks` / `... month`.
  static String _horizonLabel(RangeType type) => switch (type) {
        RangeType.week => 'week',
        RangeType.twoWeek => '2 weeks',
        RangeType.month => 'month',
      };

  static String _emptyMessage(RangeType type) => switch (type) {
        RangeType.week => 'No planned activities this week.',
        RangeType.twoWeek => 'No planned activities in this 2-week range.',
        RangeType.month =>
          'No planned activities in the generated month range.',
      };

  static String _checkStatusLabel(CheckStatus status) {
    return switch (status) {
      CheckStatus.done => 'Done',
      CheckStatus.partly => 'Partly done',
      CheckStatus.skipped => 'Skipped',
      CheckStatus.none => 'Unchecked',
    };
  }
}
