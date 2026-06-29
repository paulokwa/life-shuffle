import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/event_suggestion.dart';
import 'package:life_shuffle/screens/outside_events_screen.dart';
import 'package:life_shuffle/services/persistence_service.dart';
import 'package:life_shuffle/services/planner_service.dart';
import 'package:life_shuffle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> buildStateWithEvents({int count = 18}) async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    PersistenceService.saveCachedOutsideEvents(
      null,
      List.generate(
        count,
        (index) => EventSuggestion(
          id: 'event-$index',
          title: 'Outside event $index',
          summary: 'A sourced event for testing long-list navigation.',
          startDateTime: DateTime(2026, 7, 1, 18).add(
            Duration(hours: index),
          ),
          sourceName: 'Ticketmaster',
          sourceType: OutsideEventSourceType.ticketmaster,
          sourceId: 'ticketmaster',
          tags: const ['music', 'free'],
          dedupeKey: 'event-$index',
        ),
      ),
    );
    PersistenceService.saveCachedOutsideEventsFetchedAtMillis(null, 1000);
    return AppState(activities: PlannerService.defaultActivities);
  }

  testWidgets('source and tag facets start collapsed and remain accessible',
      (tester) async {
    final state = await buildStateWithEvents(count: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const OutsideEventsScreen(),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('outside-events-sources-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('outside-events-tags-filter')),
      findsOneWidget,
    );
    expect(find.text('music'), findsNothing);
    expect(find.textContaining('Ticketmaster ('), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('outside-events-sources-filter')),
    );
    await tester.pump();
    expect(find.textContaining('Ticketmaster ('), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('outside-events-tags-filter')),
    );
    await tester.pump();
    expect(find.text('music'), findsOneWidget);
    await tester.tap(find.text('music'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('outside-events-tags-filter')),
    );
    await tester.pump();
    expect(find.text('music'), findsNothing);
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
  });

  testWidgets('top bar stays pinned and long lists offer fast return to top',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await buildStateWithEvents();
    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const OutsideEventsScreen(),
        ),
      ),
    );

    final backButton = find.byKey(const ValueKey('outside-events-back'));
    final initialBackPosition = tester.getTopLeft(backButton);
    final scrollView = find.byType(SingleChildScrollView);
    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.thumbVisibility, isTrue);

    await tester.drag(scrollView, const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(backButton), initialBackPosition);
    expect(
      find.byKey(const ValueKey('outside-events-back-to-top')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('outside-events-back-to-top')),
    );
    await tester.pumpAndSettle();
    final controller =
        tester.widget<SingleChildScrollView>(scrollView).controller!;
    expect(controller.offset, 0);
  });
}
