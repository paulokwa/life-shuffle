import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/main.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/mock_data.dart';
import 'package:life_shuffle/screens/calendar_name_screen.dart';
import 'package:life_shuffle/screens/display_name_screen.dart';
import 'package:life_shuffle/screens/settings_screen.dart';
import 'package:life_shuffle/state/app_state.dart';
import 'package:life_shuffle/services/persistence_service.dart';
import 'package:life_shuffle/services/planner_service.dart';
import 'package:life_shuffle/services/starter_activity_library.dart';
import 'package:life_shuffle/widgets/life_shuffle_header.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final appState = AppState(activities: PlannerService.defaultActivities);
    await tester.pumpWidget(LifeShuffleApp(appState: appState));
    expect(find.byType(LifeShuffleApp), findsOneWidget);
  });

  testWidgets('Display name confirmation uses provided default name',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DisplayNameScreen(
          initialName: 'Kwame Google',
          onConfirm: (_) => true,
        ),
      ),
    );

    expect(find.text('Confirm your name'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Kwame Google'), findsOneWidget);
  });

  testWidgets('Display name confirmation allows editing a non-empty name',
      (WidgetTester tester) async {
    String? savedName;
    await tester.pumpWidget(
      MaterialApp(
        home: DisplayNameScreen(
          initialName: 'Kwame Google',
          onConfirm: (displayName) {
            savedName = displayName.trim();
            return savedName!.isNotEmpty;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '  Kwame O  ');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(savedName, 'Kwame O');
  });

  test('AppState confirms, validates, and persists display name', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);

    expect(appState.displayNameConfirmed, isFalse);
    expect(appState.confirmDisplayName('   '), isFalse);
    expect(appState.displayNameConfirmed, isFalse);

    expect(appState.confirmDisplayName('  Kwame   O  '), isTrue);
    expect(appState.displayName, 'Kwame O');
    expect(appState.displayNameConfirmed, isTrue);

    final saved = PersistenceService.load(PlannerService.defaultActivities);
    expect(saved.displayName, 'Kwame O');
    expect(saved.displayNameConfirmed, isTrue);
  });

  testWidgets('Calendar name prompt uses provided default name',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarNameScreen(
          initialName: 'Kwame and Laura',
          onConfirm: (_) => true,
        ),
      ),
    );

    expect(find.text('Name your first calendar'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Kwame and Laura'), findsOneWidget);
  });

  testWidgets('Calendar name prompt allows editing a non-empty name',
      (WidgetTester tester) async {
    String? savedName;
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarNameScreen(
          initialName: 'Kwame and Laura',
          onConfirm: (calendarName) {
            savedName = calendarName.trim();
            return savedName!.isNotEmpty;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '  Weekend ideas  ');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(savedName, 'Weekend ideas');
  });

  test('AppState confirms, validates, and persists calendar name', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);

    expect(appState.calendarNameConfirmed, isFalse);
    expect(appState.confirmCalendarTitle('   '), isFalse);
    expect(appState.calendarNameConfirmed, isFalse);

    expect(appState.confirmCalendarTitle('  Weekend   ideas  '), isTrue);
    expect(appState.calendarTitle, 'Weekend ideas');
    expect(appState.calendarNameConfirmed, isTrue);

    final saved = PersistenceService.load(PlannerService.defaultActivities);
    expect(saved.calendarTitle, 'Weekend ideas');
    expect(saved.calendarNameConfirmed, isTrue);
  });

  testWidgets('Settings displays confirmed display name',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);
    appState.confirmDisplayName('Laura');

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: appState,
          child: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    expect(find.text('Laura'), findsOneWidget);
    expect(find.text('Local-only mode'), findsNothing);
  });

  testWidgets('Settings displays confirmed calendar name',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);
    appState.confirmDisplayName('Kwame');
    appState.confirmCalendarTitle('Weekend ideas');

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: appState,
          child: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    expect(find.text('Weekend ideas'), findsWidgets);
    expect(find.text('Kwame and Laura'), findsNothing);
  });

  testWidgets('Header displays confirmed calendar name',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);
    appState.confirmDisplayName('Laura');
    appState.confirmCalendarTitle('Solo getting out');

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: appState,
          child: const Scaffold(body: LifeShuffleHeader()),
        ),
      ),
    );

    expect(find.text('Solo getting out'), findsOneWidget);
  });

  testWidgets('Local-only app confirms display name before onboarding',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);

    await tester.pumpWidget(LifeShuffleApp(appState: appState));
    expect(find.text('Confirm your name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kwame');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(appState.displayName, 'Kwame');
    expect(find.text('Name your first calendar'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Weekend ideas');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(appState.calendarTitle, 'Weekend ideas');
    expect(find.text('Your calm\nplanning partner'), findsOneWidget);
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

    // seed: 4 is required, not arbitrary. PlannerService.generate() shuffles
    // its 7-day activity-count template with the same seeded Random used for
    // the pool, so a day's target slot count (not just weekday eligibility)
    // depends on the seed. seed: 1 happens to shuffle Monday's slot to 0,
    // which makes this Monday-only activity correctly schedule nowhere (the
    // planner's intentional "leave blocked slots empty" behavior) but leaves
    // the assertions below untested. seed: 4 reliably gives Monday a
    // non-zero slot so the allowed-weekday/max-per-week rules are exercised.
    final plan = PlannerService.generate(
      weekStart: weekStart,
      pool: [activity],
      seed: 4,
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

  test('Planner diagnostics reports blocked activity slots', () {
    final weekStart = DateTime(2026, 6, 15); // Monday
    final activity = Activity(
      id: 'strict-1',
      title: 'Strict walk',
      category: 'Outside',
      durationMinutes: 30,
      maxPerWeek: 1,
      allowedWeekdays: Activity.allWeekdays,
    );

    final result = PlannerService.generateWithDiagnostics(
      weekStart: weekStart,
      pool: [activity],
      seed: 3,
      planStyle: PlanStyle.balanced,
    );

    expect(result.enabledActivityCount, 1);
    expect(result.targetActivityCount, 5);
    expect(result.scheduledActivityCount, 1);
    expect(result.unfilledActivityCount, 4);
    expect(result.hasBlockedActivitySlots, isTrue);
  });

  test('AppState exposes planner conflict message with simple fixes', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(
      activities: [
        Activity(
          id: 'strict-2',
          title: 'Strict walk',
          category: 'Outside',
          durationMinutes: 30,
          maxPerWeek: 1,
          allowedWeekdays: Activity.allWeekdays,
        ),
      ],
    );

    appState.regenerate();

    final message = appState.plannerConflictMessage;
    expect(message, isNotNull);
    expect(message, contains('lighter than expected'));
    expect(message, contains('relaxing weekdays'));
    expect(message, contains('increasing max per week'));
    expect(message, contains('turning off no-consecutive-days'));
    expect(message, contains('choosing a lighter plan style'));
  });

  test('AppState adds starter activities once and persists their rules',
      () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: const []);
    final starter = StarterActivityLibrary.groups
        .firstWhere((group) => group.category == 'Outside')
        .activities
        .firstWhere((activity) => activity.title == 'Walk waterfront');

    expect(appState.addStarterActivity(starter), isTrue);
    expect(appState.addStarterActivity(starter), isFalse);
    expect(appState.activities, hasLength(1));
    expect(appState.activities.single.title, starter.title);
    expect(appState.activities.single.category, starter.category);
    expect(appState.activities.single.durationMinutes, starter.durationMinutes);
    expect(appState.activities.single.preferredTime, starter.preferredTime);
    expect(appState.activities.single.maxPerWeek, starter.maxPerWeek);
    expect(appState.activities.single.allowedWeekdays, starter.allowedWeekdays);
    expect(
      appState.activities.single.noConsecutiveDays,
      starter.noConsecutiveDays,
    );

    appState.regenerate();
    expect(
      appState.weekPlan.expand((day) => day.activities),
      anyElement((planned) => planned.activity.title == starter.title),
    );

    final saved = PersistenceService.load(const []);
    expect(saved.activities, hasLength(1));
    expect(saved.activities.single.title, starter.title);
    expect(saved.activities.single.maxPerWeek, starter.maxPerWeek);
  });

  test('Regenerate stores previous plan and undo restores it', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);
    final firstPlanned = appState.weekPlan
        .expand((day) => day.activities)
        .firstWhere((planned) => planned.activity.id.isNotEmpty);

    appState.toggleLock(firstPlanned);
    firstPlanned.status = CheckStatus.done;
    appState.notifyCheckIn(firstPlanned);

    final beforeRegenerate = _planSignature(appState);
    expect(appState.canUndoLastRegeneration, isFalse);

    appState.regenerate();

    expect(appState.canUndoLastRegeneration, isTrue);

    appState.undoLastRegeneration();

    expect(_planSignature(appState), beforeRegenerate);
    expect(appState.canUndoLastRegeneration, isFalse);

    final saved = PersistenceService.load(PlannerService.defaultActivities);
    expect(saved.seed, 0);
    expect(saved.lockedMap[firstPlanned.activity.id], isTrue);
    expect(saved.checkinMap[firstPlanned.activity.id], CheckStatus.done.index);
  });

  test('Undo is unavailable after it is used', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);
    final original = _planSignature(appState);

    appState.regenerate();
    expect(appState.canUndoLastRegeneration, isTrue);

    appState.undoLastRegeneration();
    expect(appState.canUndoLastRegeneration, isFalse);

    appState.undoLastRegeneration();
    expect(_planSignature(appState), original);
    expect(appState.canUndoLastRegeneration, isFalse);
  });

  test('Locked items remain protected during regeneration', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final appState = AppState(activities: PlannerService.defaultActivities);
    final lockedDayIndex = appState.weekPlan.indexWhere(
      (day) => day.activities.isNotEmpty,
    );
    final lockedItem = appState.weekPlan[lockedDayIndex].activities.first;
    final lockedId = lockedItem.activity.id;
    final lockedTime = lockedItem.timeSlot;

    appState.toggleLock(lockedItem);
    appState.regenerate();

    final regeneratedLockedItem = appState.weekPlan[lockedDayIndex].activities
        .firstWhere((planned) => planned.activity.id == lockedId);

    expect(regeneratedLockedItem.timeSlot, lockedTime);
    expect(regeneratedLockedItem.locked, isTrue);
    expect(appState.canUndoLastRegeneration, isTrue);
  });
}

List<String> _planSignature(AppState appState) {
  final result = <String>[];
  for (var dayIndex = 0; dayIndex < appState.weekPlan.length; dayIndex++) {
    final day = appState.weekPlan[dayIndex];
    for (final planned in day.activities) {
      result.add(
        '$dayIndex:${planned.activity.id}:${planned.timeSlot}:'
        '${planned.status.name}:${planned.locked}',
      );
    }
  }
  return result;
}
