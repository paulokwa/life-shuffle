import '../models/event_suggestion.dart';
import 'outside_event_source_adapter.dart';

class ParsedIcsFeed {
  const ParsedIcsFeed({
    required this.suggestions,
    required this.warnings,
  });

  final List<EventSuggestion> suggestions;
  final List<OutsideEventSourceWarning> warnings;
}

/// Parses an RFC 5545 (iCalendar) feed into [EventSuggestion]s. Deliberately
/// pragmatic rather than spec-complete: it reads each `VEVENT`'s own
/// `DTSTART`/`DTEND` as a single occurrence and does not expand `RRULE`
/// recurrence (so a weekly "Storytime" shows once, at its first/next
/// occurrence, not every week) - full recurrence expansion is a much bigger
/// feature for a format most sources here use for one-off public events.
/// `TZID` parameters are also ignored beyond a literal "Z" (UTC) suffix on
/// the value itself; a non-UTC `DTSTART;TZID=...:` value is read as a plain
/// local wall-clock time, which matches what the source's own site displays.
class IcsFeedParser {
  const IcsFeedParser();

  ParsedIcsFeed parse({
    required String icsText,
    required String sourceId,
    required String sourceName,
    required String sourceUrl,
    required OutsideEventQuery query,
  }) {
    final blocks = _veventBlocks(_unfoldLines(icsText));
    final suggestions = <EventSuggestion>[];
    var skipped = 0;

    for (final block in blocks) {
      final parsed = _parseVevent(
        block,
        sourceId: sourceId,
        sourceName: sourceName,
        sourceUrl: sourceUrl,
        query: query,
      );
      if (parsed == null) {
        skipped++;
        continue;
      }
      if (query.contains(parsed.startDateTime)) {
        suggestions.add(parsed);
      }
    }

    return ParsedIcsFeed(
      suggestions: suggestions,
      warnings: [
        if (blocks.isEmpty)
          OutsideEventSourceWarning(
            sourceId: sourceId,
            sourceName: sourceName,
            message: 'Feed loaded but did not contain any calendar events.',
          ),
        if (skipped > 0)
          OutsideEventSourceWarning(
            sourceId: sourceId,
            sourceName: sourceName,
            message: '$skipped calendar event${skipped == 1 ? '' : 's'} '
                'were missing enough title/date data to show.',
          ),
      ],
    );
  }

  /// RFC 5545 folds long lines by breaking them and indenting the
  /// continuation with a single leading space/tab; undo that before parsing
  /// `NAME:value` pairs line by line.
  List<String> _unfoldLines(String icsText) {
    final rawLines = icsText.split(RegExp(r'\r\n|\r|\n'));
    final lines = <String>[];
    for (final raw in rawLines) {
      if ((raw.startsWith(' ') || raw.startsWith('\t')) && lines.isNotEmpty) {
        lines[lines.length - 1] += raw.substring(1);
      } else if (raw.trim().isNotEmpty) {
        lines.add(raw);
      }
    }
    return lines;
  }

  List<Map<String, String>> _veventBlocks(List<String> lines) {
    final blocks = <Map<String, String>>[];
    Map<String, String>? current;
    for (final line in lines) {
      final upper = line.trim().toUpperCase();
      if (upper == 'BEGIN:VEVENT') {
        current = <String, String>{};
        continue;
      }
      if (upper == 'END:VEVENT') {
        if (current != null) blocks.add(current);
        current = null;
        continue;
      }
      if (current == null) continue;
      final colonIndex = line.indexOf(':');
      if (colonIndex < 0) continue;
      final name = line.substring(0, colonIndex).split(';').first.toUpperCase();
      current[name] = line.substring(colonIndex + 1);
    }
    return blocks;
  }

  EventSuggestion? _parseVevent(
    Map<String, String> props, {
    required String sourceId,
    required String sourceName,
    required String sourceUrl,
    required OutsideEventQuery query,
  }) {
    final rawTitle = props['SUMMARY'];
    if (rawTitle == null || rawTitle.trim().isEmpty) return null;
    final title = _unescapeText(rawTitle);

    final startRaw = props['DTSTART'];
    if (startRaw == null) return null;
    final start = _parseIcsDateTime(startRaw);
    if (start == null) return null;

    final endRaw = props['DTEND'];
    final end = endRaw == null ? null : _parseIcsDateTime(endRaw);

    final description =
        props['DESCRIPTION'] == null ? null : _unescapeText(props['DESCRIPTION']!);
    final location =
        props['LOCATION'] == null ? null : _unescapeText(props['LOCATION']!);
    final venueName = location?.split(',').first.trim();
    final url = props['URL']?.trim();
    final uid = props['UID'];
    final idSeed = (uid != null && uid.trim().isNotEmpty)
        ? uid.trim()
        : '$title|${start.toIso8601String()}';
    final tags = (props['CATEGORIES'] ?? '')
        .split(',')
        .map((tag) => tag.trim().toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toList();

    return EventSuggestion(
      id: '$sourceId-${_stableId(idSeed)}',
      title: title,
      cleanedTitle: title,
      description: description,
      startDateTime: start,
      endDateTime: (end != null && end.isAfter(start)) ? end : null,
      venueName: (venueName == null || venueName.isEmpty) ? null : venueName,
      address: location,
      city: query.city,
      sourceName: sourceName,
      sourceType: OutsideEventSourceType.icsCalendar,
      sourceUrl: (url == null || url.isEmpty) ? sourceUrl : url,
      tags: tags.isEmpty ? const ['community'] : tags,
      missingFields: [
        if (venueName == null || venueName.isEmpty) 'venue',
        if (location == null || location.isEmpty) 'address',
      ],
      raw: {
        'feedSourceId': sourceId,
        'feedUrl': sourceUrl,
        if (uid != null) 'uid': uid,
      },
      dedupeKey: eventDedupeKey(title: title, start: start, venueName: venueName),
    );
  }

  static final RegExp _dateOnlyPattern = RegExp(r'^(\d{4})(\d{2})(\d{2})$');
  static final RegExp _dateTimePattern =
      RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$');

  DateTime? _parseIcsDateTime(String rawValue) {
    final value = rawValue.trim();
    final dateOnly = _dateOnlyPattern.firstMatch(value);
    if (dateOnly != null) {
      return DateTime(
        int.parse(dateOnly.group(1)!),
        int.parse(dateOnly.group(2)!),
        int.parse(dateOnly.group(3)!),
      );
    }
    final dateTime = _dateTimePattern.firstMatch(value);
    if (dateTime == null) return null;
    final year = int.parse(dateTime.group(1)!);
    final month = int.parse(dateTime.group(2)!);
    final day = int.parse(dateTime.group(3)!);
    final hour = int.parse(dateTime.group(4)!);
    final minute = int.parse(dateTime.group(5)!);
    final second = int.parse(dateTime.group(6)!);
    if (dateTime.group(7) == 'Z') {
      return DateTime.utc(year, month, day, hour, minute, second).toLocal();
    }
    return DateTime(year, month, day, hour, minute, second);
  }

  String _unescapeText(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      if (char == r'\' && i + 1 < value.length) {
        final next = value[i + 1];
        if (next == 'n' || next == 'N') {
          buffer.write('\n');
          i++;
          continue;
        }
        if (next == ',' || next == ';' || next == r'\') {
          buffer.write(next);
          i++;
          continue;
        }
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  String _stableId(String value) {
    final normalized = value.trim().toLowerCase();
    final hash = normalized.codeUnits.fold<int>(
      0,
      (previous, code) => (previous * 31 + code) & 0x7fffffff,
    );
    return hash.toRadixString(16);
  }
}
