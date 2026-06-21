import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/day_plan.dart';
import 'package:life_shuffle/models/export_print_options.dart';
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

  test('default options keep existing useful output unchanged', () {
    const defaults = ExportPrintOptions();
    expect(defaults.showTime, isTrue);
    expect(defaults.showDuration, isTrue);
    expect(defaults.showCategory, isTrue);
    expect(defaults.showCheckInStatus, isTrue);
    expect(defaults.showLockedStatus, isTrue);
    expect(defaults.showEnabledDimensions, isTrue);
  });

  test('hides duration, category, check-in, and locked status when disabled',
      () {
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
      options: const ExportPrintOptions(
        showDuration: false,
        showCategory: false,
        showCheckInStatus: false,
        showLockedStatus: false,
      ),
    );

    expect(export, contains('- 8:00 PM, Cook together'));
    expect(export, isNot(contains('(')));
    expect(export, isNot(contains('Category:')));
    expect(export, isNot(contains('Check-in:')));
    expect(export, isNot(contains('Locked:')));
  });

  test('hides time when showTime is disabled', () {
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
            ),
          ],
        ),
      ],
      options: const ExportPrintOptions(showTime: false),
    );

    expect(export, contains('- Cook together (1 hr 30 min)'));
    expect(export, isNot(contains('8:00 PM')));
  });

  test('includes enabled planning dimensions when requested', () {
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
                difficulty: 3,
                energy: 'medium',
                social: 'together',
              ),
              timeSlot: '8:00 PM',
            ),
          ],
        ),
      ],
      difficultyEnabled: true,
      energyEnabled: true,
      socialEnabled: false,
    );

    expect(export, contains('Difficulty 3/5'));
    expect(export, contains('Energy: Medium'));
    expect(export, isNot(contains('Social:')));
  });

  test('excludes planning dimensions when their settings are disabled', () {
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
            ),
          ],
        ),
      ],
    );

    expect(export, isNot(contains('Difficulty')));
    expect(export, isNot(contains('Energy:')));
    expect(export, isNot(contains('Social:')));
  });

  test('excludes planning dimensions when showEnabledDimensions is off', () {
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
                difficulty: 4,
              ),
              timeSlot: '8:00 PM',
            ),
          ],
        ),
      ],
      options: const ExportPrintOptions(showEnabledDimensions: false),
      difficultyEnabled: true,
    );

    expect(export, isNot(contains('Difficulty')));
  });

  test('dimensionLabels only returns enabled dimensions', () {
    final activity = Activity(
      id: 'walk',
      title: 'Walk',
      category: 'Outside',
      durationMinutes: 30,
      difficulty: 2,
      energy: 'low',
      social: 'solo',
    );

    expect(
      TextWeekExportService.dimensionLabels(
        activity,
        difficultyEnabled: true,
        energyEnabled: false,
        socialEnabled: true,
      ),
      ['Difficulty 2/5', 'Social: Solo'],
    );
    expect(
      TextWeekExportService.dimensionLabels(
        activity,
        difficultyEnabled: false,
        energyEnabled: false,
        socialEnabled: false,
      ),
      isEmpty,
    );
  });
}
