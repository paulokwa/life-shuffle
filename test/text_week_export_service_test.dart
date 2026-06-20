import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/day_plan.dart';
import 'package:life_shuffle/models/mock_data.dart';
import 'package:life_shuffle/services/text_week_export_service.dart';

void main() {
  test('exports a normal week deterministically', () {
    final export = TextWeekExportService.generate(
      calendarTitle: 'Kwame and Laura',
      plan: [
        DayPlan(
          date: DateTime(2026, 6, 15),
          activities: [
            PlannedActivity(
              activity: Activity(
                id: 'walk',
                title: 'Walk waterfront',
                category: 'Outside',
                durationMinutes: 45,
              ),
              timeSlot: '6:30 PM',
            ),
            PlannedActivity(
              activity: Activity(
                id: 'read',
                title: 'Cafe reading',
                category: 'Creative',
                durationMinutes: 60,
              ),
              timeSlot: '11:00 AM',
            ),
          ],
        ),
      ],
    );

    expect(
      export,
      [
        'Kwame and Laura week',
        'Jun 15-Jun 15, 2026',
        '',
        'Monday, Jun 15',
        '- 11:00 AM, Cafe reading (1 hr)',
        '  Category: Creative',
        '  Check-in: Unchecked',
        '  Locked: No',
        '- 6:30 PM, Walk waterfront (45 min)',
        '  Category: Outside',
        '  Check-in: Unchecked',
        '  Locked: No',
      ].join('\n'),
    );
  });

  test('exports an empty plan', () {
    final export = TextWeekExportService.generate(
      calendarTitle: 'Solo getting out',
      plan: [
        DayPlan(date: DateTime(2026, 6, 15), activities: []),
        DayPlan(date: DateTime(2026, 6, 16), activities: []),
      ],
    );

    expect(
      export,
      [
        'Solo getting out week',
        'Jun 15-Jun 16, 2026',
        '',
        'No planned activities this week.',
      ].join('\n'),
    );
  });

  test('exports check-in and locked status output', () {
    final export = TextWeekExportService.generate(
      calendarTitle: 'Kwame and Laura',
      plan: [
        DayPlan(
          date: DateTime(2026, 6, 17),
          activities: [
            PlannedActivity(
              activity: Activity(
                id: 'cook',
                title: 'Cook together',
                category: 'Food',
                durationMinutes: 90,
              ),
              timeSlot: '8:00 PM',
              status: CheckStatus.partly,
              locked: true,
            ),
          ],
        ),
      ],
    );

    expect(export, contains('  Check-in: Partly done'));
    expect(export, contains('  Locked: Yes'));
  });

  test('excludes private notes by default', () {
    final export = TextWeekExportService.generate(
      calendarTitle: 'Kwame and Laura',
      plan: [
        DayPlan(
          date: DateTime(2026, 6, 18),
          activities: [
            PlannedActivity(
              activity: Activity(
                id: 'admin',
                title: 'Life admin',
                category: 'Chores / life admin',
                durationMinutes: 30,
              ),
              timeSlot: '9:00 AM',
            ),
          ],
        ),
      ],
      privateNotesByActivityId: const {
        'admin': 'Sensitive detail that should stay private',
      },
    );

    expect(export, contains('Life admin'));
    expect(export, isNot(contains('Sensitive detail')));
    expect(export, isNot(contains('Notes:')));
  });
}
