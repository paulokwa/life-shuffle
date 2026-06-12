import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/main.dart';
import 'package:life_shuffle/state/app_state.dart';
import 'package:life_shuffle/services/planner_service.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    final appState = AppState(activities: PlannerService.defaultActivities);
    await tester.pumpWidget(LifeShuffleApp(appState: appState));
    expect(find.byType(LifeShuffleApp), findsOneWidget);
  });
}
