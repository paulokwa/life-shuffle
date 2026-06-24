import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/event_suggestion.dart';
import 'package:life_shuffle/services/outside_event_discovery_service.dart';
import 'package:life_shuffle/services/outside_event_organizer_service.dart';
import 'package:life_shuffle/services/outside_event_source_adapter.dart';
import 'package:life_shuffle/services/persistence_service.dart';

void main() {
  group('EventSuggestion', () {
    test('converts to fixed manual plan item with source metadata', () {
      final start = DateTime(2026, 7, 2, 18, 30);
      final event = EventSuggestion(
        id: 'evt-1',
        title: 'Waterfront Night Market',
        cleanedTitle: 'Waterfront Night Market',
        summary: 'Food and local makers on the waterfront.',
        startDateTime: start,
        durationMinutes: 120,
        venueName: 'Salt Yard',
        address: 'Halifax Waterfront',
        city: 'Halifax',
        sourceName: 'Sample source',
        sourceType: OutsideEventSourceType.mock,
        sourceUrl: 'https://example.com/event',
        ticketUrl: 'https://example.com/tickets',
        priceLabel: 'Free entry',
        tags: const ['market', 'food'],
        dedupeKey: eventDedupeKey(
          title: 'Waterfront Night Market',
          start: start,
          venueName: 'Salt Yard',
        ),
      );

      final item = event.toManualPlanItem(id: 'outside-fixed');

      expect(item.id, 'outside-fixed');
      expect(item.dateKey, '2026-07-02');
      expect(item.timeSlot, '6:30 PM');
      expect(item.category, 'Food');
      expect(item.isOutsideEvent, isTrue);
      expect(item.outsideEventId, 'evt-1');
      expect(item.outsideEventSourceName, 'Sample source');
      expect(item.outsideEventTicketUrl, 'https://example.com/tickets');
      expect(item.outsideEventVenueName, 'Salt Yard');
    });
  });

  group('OutsideEventOrganizerService', () {
    test('cleans HTML, summarizes, infers tags, and marks missing fields', () {
      const organizer = OutsideEventOrganizerService();
      final event = EventSuggestion(
        id: 'rss-1',
        title: '<b>Public Gardens evening walk</b> - tickets',
        description: '<p>A guided outdoor walk &amp; local history.</p>',
        startDateTime: DateTime(2026, 7, 3, 17, 30),
        sourceName: 'RSS',
        sourceType: OutsideEventSourceType.rssAtom,
        dedupeKey: 'rss-1',
      );

      final organized = organizer.organize(event);

      expect(organized.displayTitle, 'Public Gardens evening walk');
      expect(
          organized.displaySummary, 'A guided outdoor walk & local history.');
      expect(organized.tags, contains('outdoors'));
      expect(
          organized.missingFields, containsAll(['address', 'price', 'venue']));
      expect(organized.confidence, 0.78);
    });
  });

  group('OutsideEventDiscoveryService', () {
    test('combines source results, dedupes, sorts, and keeps warnings',
        () async {
      final start = DateTime(2026, 7, 1);
      final event = _event(
        id: 'one',
        title: 'Same event',
        start: start.add(const Duration(days: 1, hours: 10)),
      );
      final duplicate = _event(
        id: 'two',
        title: 'Same event',
        start: start.add(const Duration(days: 1, hours: 10)),
      );
      final later = _event(
        id: 'later',
        title: 'Later event',
        start: start.add(const Duration(days: 2, hours: 10)),
      );
      final service = OutsideEventDiscoveryService(
        adapters: [
          _FixedAdapter(
            id: 'a',
            displayName: 'A',
            events: [later, event],
          ),
          _FixedAdapter(
            id: 'b',
            displayName: 'B',
            events: [duplicate],
            warning: 'B is partial',
          ),
        ],
      );

      final result = await service.discover(
        OutsideEventQuery(
          start: start,
          end: start.add(const Duration(days: 7)),
        ),
      );

      expect(result.events.map((e) => e.id), ['one', 'later']);
      expect(result.warnings.single.message, 'B is partial');
    });
  });

  group('SavedState', () {
    test('round-trips outside event metadata on manual plan items', () {
      final event = _event(
        id: 'persisted',
        title: 'Persisted event',
        start: DateTime(2026, 7, 5, 19),
      );
      final item = event.toManualPlanItem(id: 'outside-persisted');
      final saved = SavedState(
        activities: const <Activity>[],
        seed: 0,
        updatedAtMillis: 1,
        enabledMap: const {},
        checkinMap: const {},
        lockedMap: const {},
        manualPlanItems: {item.id: item},
      );

      final restored = SavedState.fromMap(saved.toMap());
      final restoredItem = restored.manualPlanItems[item.id]!;

      expect(restoredItem.isOutsideEvent, isTrue);
      expect(restoredItem.outsideEventId, 'persisted');
      expect(restoredItem.outsideEventSourceUrl, event.sourceUrl);
      expect(restoredItem.outsideEventSummary, event.displaySummary);
    });
  });
}

EventSuggestion _event({
  required String id,
  required String title,
  required DateTime start,
}) {
  return EventSuggestion(
    id: id,
    title: title,
    startDateTime: start,
    venueName: 'Venue',
    sourceName: 'Fixture',
    sourceType: OutsideEventSourceType.mock,
    sourceUrl: 'https://example.com/$id',
    summary: 'Fixture summary',
    tags: const ['community'],
    dedupeKey: eventDedupeKey(
      title: title,
      start: start,
      venueName: 'Venue',
    ),
  );
}

class _FixedAdapter implements OutsideEventSourceAdapter {
  const _FixedAdapter({
    required this.id,
    required this.displayName,
    required this.events,
    this.warning,
  });

  final String id;
  final String displayName;
  final List<EventSuggestion> events;
  final String? warning;

  @override
  OutsideEventSourceConfig get config => OutsideEventSourceConfig(
        id: id,
        displayName: displayName,
        type: OutsideEventSourceType.mock,
        enabled: true,
        needsApiKey: false,
        configured: true,
        description: displayName,
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    return OutsideEventSourceResult(
      source: config,
      suggestions: events,
      warnings: [
        if (warning != null)
          OutsideEventSourceWarning(
            sourceId: id,
            sourceName: displayName,
            message: warning!,
          ),
      ],
    );
  }
}
