import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/source_list_snapshot.dart';
import 'package:life_shuffle/models/user_event_source.dart';
import 'package:life_shuffle/services/persistence_service.dart';
import 'package:life_shuffle/services/planner_service.dart';
import 'package:life_shuffle/screens/settings_screen.dart';
import 'package:life_shuffle/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const source = UserEventSource(
    id: 'library',
    displayName: 'Library events',
    url: 'https://example.com/events',
    kind: UserEventSourceKind.rssAtom,
    lastFetchedAtMillis: 123,
    lastError: 'Old warning',
    lastSuccessAtMillis: 100,
    lastEventCount: 4,
  );

  test('snapshot round-trip keeps configuration and drops fetch health', () {
    final snapshot = SourceListSnapshot.capture(
      createdAtMillis: 1000,
      sources: const [source],
    );
    final restored = SourceListSnapshot.fromMap(snapshot.toMap());

    expect(restored.id, 'source_snapshot_1000');
    expect(restored.createdAtMillis, 1000);
    expect(restored.sources.single.displayName, 'Library events');
    expect(restored.sources.single.lastFetchedAtMillis, isNull);
    expect(restored.sources.single.lastError, isNull);
    expect(restored.sources.single.lastEventCount, isNull);
  });

  test('SavedState serializes source lists for Firestore sync', () {
    final snapshot = SourceListSnapshot.capture(
      createdAtMillis: 1000,
      sources: const [source],
    );
    final state = SavedState(
      activities: const [],
      seed: 0,
      updatedAtMillis: 1000,
      enabledMap: const {},
      checkinMap: const {},
      lockedMap: const {},
      outsideEventSources: const [source],
      outsideEventSourceSnapshots: [snapshot],
    );

    final restored = SavedState.fromMap(state.toMap());

    expect(restored.outsideEventSources, hasLength(1));
    expect(restored.outsideEventSourceSnapshots, hasLength(1));
    expect(
      restored.outsideEventSourceSnapshots!.single.sources.single.url,
      source.url,
    );
  });

  test('saving keeps the newest 10 lists and removes the oldest', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final state = AppState(activities: PlannerService.defaultActivities);
    state.addOutsideEventSource(
      displayName: source.displayName,
      url: source.url,
      kind: source.kind,
    );

    for (var millis = 1000; millis <= 1010; millis++) {
      state.saveCurrentOutsideEventSources(nowMillis: millis);
    }

    expect(state.outsideEventSourceSnapshots, hasLength(10));
    expect(state.outsideEventSourceSnapshots.first.createdAtMillis, 1010);
    expect(state.outsideEventSourceSnapshots.last.createdAtMillis, 1001);
  });

  test('restoring replaces current sources and clears old health', () async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final state = AppState(activities: PlannerService.defaultActivities);
    state.addOutsideEventSource(
      displayName: source.displayName,
      url: source.url,
      kind: source.kind,
    );
    final snapshot = state.saveCurrentOutsideEventSources(nowMillis: 1000)!;
    state.deleteOutsideEventSource(state.outsideEventSources.single.id);
    state.addOutsideEventSource(
      displayName: 'Replacement',
      url: 'https://replacement.example/events',
      kind: UserEventSourceKind.webPage,
    );

    expect(state.restoreOutsideEventSourceSnapshot(snapshot.id), isTrue);
    expect(state.outsideEventSources, hasLength(1));
    expect(state.outsideEventSources.single.displayName, 'Library events');
    expect(state.outsideEventSources.single.lastFetchedAtMillis, isNull);
  });

  testWidgets('Settings saves, previews, and restores a source list',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await PersistenceService.init();
    final state = AppState(activities: PlannerService.defaultActivities);
    state.addOutsideEventSource(
      displayName: source.displayName,
      url: source.url,
      kind: source.kind,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppStateScope(
          state: state,
          child: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );

    final saveButton = find.byKey(
      const ValueKey('settings-save-outside-source-list'),
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(state.outsideEventSourceSnapshots, hasLength(1));

    final history = find.byKey(
      const ValueKey('settings-source-snapshot-history'),
    );
    await tester.ensureVisible(history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('1 of 10 saved'), findsOneWidget);

    final snapshotRow = find.byKey(
      ValueKey(
          'source-snapshot-${state.outsideEventSourceSnapshots.single.id}'),
    );
    await tester.tap(snapshotRow);
    await tester.pumpAndSettle();
    expect(find.text('Saved source list'), findsOneWidget);
    expect(find.textContaining(source.url), findsWidgets);

    state.deleteOutsideEventSource(state.outsideEventSources.single.id);
    state.addOutsideEventSource(
      displayName: 'Replacement',
      url: 'https://replacement.example/events',
      kind: UserEventSourceKind.webPage,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('restore-source-snapshot')));
    await tester.pumpAndSettle();
    expect(find.text('Restore this source list?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Restore'));
    await tester.pumpAndSettle();

    expect(state.outsideEventSources.single.displayName, 'Library events');
  });
}
