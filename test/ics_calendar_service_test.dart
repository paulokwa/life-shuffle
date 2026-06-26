import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/day_plan.dart';
import 'package:life_shuffle/models/manual_plan_item.dart';
import 'package:life_shuffle/models/mock_data.dart';
import 'package:life_shuffle/services/ics_calendar_service.dart';

void main() {
  test('generates a valid calendar envelope and VEVENT count', () {
    final feed = IcsCalendarService.generate(
      calendarId: 'cal-1',
      calendarTitle: 'Kwame and Laura',
      plan: _samplePlan(),
      generatedAt: DateTime.utc(2026, 6, 18, 12, 34, 56),
    );

    expect(feed.startsWith('BEGIN:VCALENDAR\r\n'), isTrue);
    expect(feed.endsWith('END:VCALENDAR\r\n'), isTrue);
    expect(feed, contains('VERSION:2.0\r\n'));
    expect(feed, contains('PRODID:-//Life Shuffle//Life Shuffle Calendar//EN'));
    expect(feed, contains('CALSCALE:GREGORIAN\r\n'));
    expect(feed, contains('METHOD:PUBLISH\r\n'));
    expect(feed, contains('X-WR-CALNAME:Kwame and Laura\r\n'));
    expect(RegExp('BEGIN:VEVENT').allMatches(feed), hasLength(2));
  });

  test('writes stable event UIDs', () {
    final first = IcsCalendarService.generate(
      calendarId: 'cal-1',
      calendarTitle: 'Kwame and Laura',
      plan: _samplePlan(),
      generatedAt: DateTime.utc(2026, 6, 18, 12),
    );
    final second = IcsCalendarService.generate(
      calendarId: 'cal-1',
      calendarTitle: 'Kwame and Laura',
      plan: _samplePlan(),
      generatedAt: DateTime.utc(2026, 6, 19, 12),
    );

    expect(_uidLines(first), _uidLines(second));
    expect(
      first,
      contains(
        'UID:life-shuffle-cal-1-20260618-walk-1-6-30-PM@life-shuffle.local',
      ),
    );
  });

  test('escapes ICS text for titles, category, and description', () {
    final feed = IcsCalendarService.generate(
      calendarId: 'cal-1',
      calendarTitle: r'Kwame, Laura; and \ Life',
      plan: _samplePlan(),
      generatedAt: DateTime.utc(2026, 6, 18, 12),
    );

    expect(feed, contains(r'X-WR-CALNAME:Kwame\, Laura\; and \\ Life'));
    expect(feed, contains(r'SUMMARY:Walk\, waterfront\; then \\ home\nsoon'));
    expect(feed, contains(r'CATEGORIES:Outside\, water\; calm'));
    expect(
      feed,
      contains(
        r'DESCRIPTION:Duration: 45 min\nCategory: Outside\, water\; calm',
      ),
    );
  });

  test('converts plan dates, time slots, and durations into event times', () {
    final feed = IcsCalendarService.generate(
      calendarId: 'cal-1',
      calendarTitle: 'Kwame and Laura',
      plan: _samplePlan(),
      generatedAt: DateTime.utc(2026, 6, 18, 12, 34, 56),
    );

    expect(feed, contains('DTSTAMP:20260618T123456Z\r\n'));
    expect(feed, contains('DTSTART:20260618T183000\r\n'));
    expect(feed, contains('DTEND:20260618T191500\r\n'));
    expect(feed, contains('DTSTART:20260619T110000\r\n'));
    expect(feed, contains('DTEND:20260619T123000\r\n'));
  });

  test('empty plan produces a valid calendar with no events', () {
    final feed = IcsCalendarService.generate(
      calendarId: 'empty',
      calendarTitle: 'Empty plan',
      plan: const [],
      generatedAt: DateTime.utc(2026, 6, 18, 12),
    );

    expect(feed, contains('BEGIN:VCALENDAR\r\n'));
    expect(feed, contains('X-WR-CALNAME:Empty plan\r\n'));
    expect(feed, contains('END:VCALENDAR\r\n'));
    expect(feed, isNot(contains('BEGIN:VEVENT')));
  });

  test('includes outside event metadata in the description when supplied', () {
    final manualItem = ManualPlanItem(
      id: 'outside-1',
      dateKey: '2026-06-18',
      title: 'Garden concert',
      timeSlot: '6:30 PM',
      category: 'Outside',
      durationMinutes: 45,
      outsideEventId: 'evt-1',
      outsideEventSourceName: 'Venue page',
      outsideEventVenueName: 'Victoria Park',
    );
    final plan = [
      DayPlan(
        date: DateTime(2026, 6, 18),
        activities: [
          PlannedActivity(
            activity: Activity(
              id: 'manual_outside-1',
              title: 'Garden concert',
              category: 'Outside',
              durationMinutes: 45,
            ),
            timeSlot: '6:30 PM',
            manualItemId: 'outside-1',
          ),
        ],
      ),
    ];

    final feed = IcsCalendarService.generate(
      calendarId: 'cal-1',
      calendarTitle: 'Kwame and Laura',
      plan: plan,
      generatedAt: DateTime.utc(2026, 6, 18, 12),
      manualPlanItemsById: {'outside-1': manualItem},
    );

    final unfolded = feed.replaceAll('\r\n ', '');
    expect(unfolded, contains(r'Venue: Victoria Park'));
    expect(unfolded, contains(r'Source: Venue page'));
  });
}

List<DayPlan> _samplePlan() {
  return [
    DayPlan(
      date: DateTime(2026, 6, 18),
      activities: [
        PlannedActivity(
          activity: Activity(
            id: 'walk-1',
            title: 'Walk, waterfront; then \\ home\nsoon',
            category: 'Outside, water; calm',
            durationMinutes: 45,
          ),
          timeSlot: '6:30 PM',
          status: CheckStatus.none,
        ),
      ],
    ),
    DayPlan(
      date: DateTime(2026, 6, 19),
      activities: [
        PlannedActivity(
          activity: Activity(
            id: 'cafe-1',
            title: 'Cafe reading',
            category: 'Creative',
            durationMinutes: 90,
          ),
          timeSlot: '11:00 AM',
          status: CheckStatus.done,
        ),
      ],
    ),
  ];
}

List<String> _uidLines(String feed) {
  return feed.split('\r\n').where((line) => line.startsWith('UID:')).toList();
}
