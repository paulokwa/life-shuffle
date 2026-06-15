import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/main.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/state/app_state.dart';
import 'package:life_shuffle/services/persistence_service.dart';
import 'package:life_shuffle/services/planner_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final appState = AppState(activities: PlannerService.defaultActivities);
    await tester.pumpWidget(LifeShuffleApp(appState: appState));
    expect(find.byType(LifeShuffleApp), findsOneWidget);
  });

  test('AppState adds, edits, disables, regenerates, and persists activities',
      () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: const []);

    appState.addActivity(
      title: 'Sunrise walk',
      category: 'Outside',
      durationMinutes: 30,
      preferredTime: 'morning',
      maxPerWeek: 1,
      allowedWeekdays: Activity.allWeekdays,
      noConsecutiveDays: false,
      enabled: true,
    );

    expect(appState.activities, hasLength(1));
    expect(appState.activities.single.title, 'Sunrise walk');

    appState.regenerate();
    expect(
      appState.weekPlan.expand((day) => day.activities),
      anyElement((planned) => planned.activity.title == 'Sunrise walk'),
    );

    final id = appState.activities.single.id;
    appState.updateActivity(
      id,
      title: 'Edited walk',
      category: 'Health / movement',
      durationMinutes: 45,
      preferredTime: 'afternoon',
      maxPerWeek: 1,
      allowedWeekdays: [1, 3, 5],
      noConsecutiveDays: true,
      enabled: false,
    );

    expect(appState.activities.single.title, 'Edited walk');
    expect(appState.activities.single.enabled, isFalse);

    appState.regenerate();
    expect(
      appState.weekPlan.expand((day) => day.activities),
      isNot(anyElement((planned) => planned.activity.id == id)),
    );

    final saved = PersistenceService.load(const []);
    expect(saved.activities.single.title, 'Edited walk');
    expect(saved.activities.single.enabled, isFalse);
    expect(saved.activities.single.durationMinutes, 45);
    expect(saved.activities.single.allowedWeekdays, [1, 3, 5]);
    expect(saved.activities.single.noConsecutiveDays, isTrue);
  });

  test('Planner respects max per week and allowed weekdays', () {
    final weekStart = DateTime(2026, 6, 15); // Monday
    final activity = Activity(
      id: 'rule-1',
      title: 'Monday only',
      category: 'Creative',
      durationMinutes: 30,
      maxPerWeek: 2,
      allowedWeekdays: [1],
    );

    final plan = PlannerService.generate(
      weekStart: weekStart,
      pool: [activity],
      seed: 1,
    );
    final planned = plan.expand((day) => day.activities).toList();

    expect(planned.length, lessThanOrEqualTo(2));
    expect(planned, isNotEmpty);
    expect(
      planned.every(
          (plannedActivity) => plannedActivity.activity.id == activity.id),
      isTrue,
    );
    expect(
      plan
          .where((day) => day.activities.isNotEmpty)
          .every((day) => day.date.weekday == DateTime.monday),
      isTrue,
    );
  });

  test('Planner avoids consecutive days when another placement is possible',
      () {
    final weekStart = DateTime(2026, 6, 15); // Monday
    final activity = Activity(
      id: 'rule-2',
      title: 'Stretch',
      category: 'Rest',
      durationMinutes: 20,
      maxPerWeek: 3,
      noConsecutiveDays: true,
    );

    final plan = PlannerService.generate(
      weekStart: weekStart,
      pool: [activity],
      seed: 4,
    );
    final days = <int>[];
    for (var i = 0; i < plan.length; i++) {
      if (plan[i]
          .activities
          .any((planned) => planned.activity.id == activity.id)) {
        days.add(i);
      }
    }

    expect(days.length, lessThanOrEqualTo(3));
    for (var i = 1; i < days.length; i++) {
      expect(days[i] - days[i - 1], greaterThan(1));
    }
  });
}
