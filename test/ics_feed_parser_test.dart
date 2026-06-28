import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/event_suggestion.dart';
import 'package:life_shuffle/services/ics_feed_parser.dart';
import 'package:life_shuffle/services/outside_event_source_adapter.dart';

void main() {
  const parser = IcsFeedParser();

  OutsideEventQuery queryFor(DateTime start, DateTime end) {
    return OutsideEventQuery(start: start, end: end, city: 'Halifax');
  }

  test('parses a VEVENT with UTC DTSTART/DTEND into an EventSuggestion', () {
    final icsText = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'BEGIN:VEVENT',
      'UID:abc-123\@example.com',
      'SUMMARY:Geekorium 2026',
      'DESCRIPTION:Cosplay\\, vendors\\, and fun.',
      'DTSTART:20260627T100000Z',
      'DTEND:20260628T170000Z',
      'LOCATION:Cole Harbour Place\\, 51 Forest Hills Pkwy\\, Dartmouth',
      'URL:https://halifaxevents.ca/event/geekorium-2026/',
      'CATEGORIES:Community,Family Friendly',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    final result = parser.parse(
      icsText: icsText,
      sourceId: 'src-1',
      sourceName: 'Halifax Events',
      sourceUrl: 'https://halifaxevents.ca/events/?ical=1',
      query: queryFor(
        DateTime(2026, 6, 1),
        DateTime(2026, 7, 31),
      ),
    );

    expect(result.warnings, isEmpty);
    expect(result.suggestions, hasLength(1));
    final event = result.suggestions.single;
    expect(event.title, 'Geekorium 2026');
    expect(event.description, 'Cosplay, vendors, and fun.');
    expect(event.venueName, 'Cole Harbour Place');
    expect(event.address, contains('Dartmouth'));
    expect(event.sourceType, OutsideEventSourceType.icsCalendar);
    expect(event.sourceUrl, 'https://halifaxevents.ca/event/geekorium-2026/');
    expect(event.tags, ['community', 'family friendly']);
    expect(event.startDateTime.isUtc, isFalse);
    expect(event.endDateTime, isNotNull);
  });

  test('reads a floating local DTSTART (no Z, no TZID) as plain wall-clock time', () {
    final icsText = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'SUMMARY:Drop-in Storytime',
      'DTSTART:20260615T100000',
      'DTEND:20260615T110000',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\n');

    final result = parser.parse(
      icsText: icsText,
      sourceId: 'src-1',
      sourceName: 'Library',
      sourceUrl: 'https://example.com/events.ics',
      query: queryFor(DateTime(2026, 6, 1), DateTime(2026, 6, 30)),
    );

    final event = result.suggestions.single;
    expect(event.startDateTime, DateTime(2026, 6, 15, 10, 0, 0));
  });

  test('unfolds RFC 5545 folded continuation lines before parsing', () {
    final icsText = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'SUMMARY:Long Event Na',
      ' me That Wraps',
      'DTSTART:20260701T120000Z',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    final result = parser.parse(
      icsText: icsText,
      sourceId: 'src-1',
      sourceName: 'Test',
      sourceUrl: 'https://example.com/events.ics',
      query: queryFor(DateTime(2026, 6, 1), DateTime(2026, 7, 31)),
    );

    expect(result.suggestions.single.title, 'Long Event Name That Wraps');
  });

  test('skips events with no SUMMARY or no DTSTART and reports a warning', () {
    final icsText = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'DTSTART:20260701T120000Z',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'SUMMARY:No date',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    final result = parser.parse(
      icsText: icsText,
      sourceId: 'src-1',
      sourceName: 'Test',
      sourceUrl: 'https://example.com/events.ics',
      query: queryFor(DateTime(2026, 6, 1), DateTime(2026, 7, 31)),
    );

    expect(result.suggestions, isEmpty);
    expect(
      result.warnings.single.message,
      contains('2 calendar events were missing'),
    );
  });

  test('reports a warning when the feed has no VEVENT blocks at all', () {
    final result = parser.parse(
      icsText: 'BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR',
      sourceId: 'src-1',
      sourceName: 'Test',
      sourceUrl: 'https://example.com/events.ics',
      query: queryFor(DateTime(2026, 6, 1), DateTime(2026, 7, 31)),
    );

    expect(result.suggestions, isEmpty);
    expect(
      result.warnings.single.message,
      contains('did not contain any calendar events'),
    );
  });

  test('excludes events outside the requested date range', () {
    final icsText = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'SUMMARY:Too early',
      'DTSTART:20250101T120000Z',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    final result = parser.parse(
      icsText: icsText,
      sourceId: 'src-1',
      sourceName: 'Test',
      sourceUrl: 'https://example.com/events.ics',
      query: queryFor(DateTime(2026, 6, 1), DateTime(2026, 7, 31)),
    );

    expect(result.suggestions, isEmpty);
  });

  test(
      'reports a distinct warning when every parsed event falls outside the '
      'planning range', () {
    final icsText = [
      'BEGIN:VCALENDAR',
      'BEGIN:VEVENT',
      'SUMMARY:Way out',
      'DTSTART:20260929T130000Z',
      'END:VEVENT',
      'BEGIN:VEVENT',
      'SUMMARY:Also way out',
      'DTSTART:20261027T223000Z',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    final result = parser.parse(
      icsText: icsText,
      sourceId: 'src-1',
      sourceName: 'Test',
      sourceUrl: 'https://example.com/events.ics',
      query: queryFor(DateTime(2026, 6, 28), DateTime(2026, 7, 28)),
    );

    expect(result.suggestions, isEmpty);
    expect(
      result.warnings.single.message,
      contains('2 calendar events were found, but outside your current '
          'planning range'),
    );
    expect(result.warnings.single.category,
        OutsideEventFailureCategory.noEventsFound);
  });
}
