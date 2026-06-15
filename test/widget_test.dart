import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/main.dart';
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
  });
}
