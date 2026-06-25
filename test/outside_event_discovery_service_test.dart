import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/event_suggestion.dart';
import 'package:life_shuffle/services/curated_rss_feed_registry.dart';
import 'package:life_shuffle/services/outside_event_adapters.dart';
import 'package:life_shuffle/services/outside_event_discovery_service.dart';
import 'package:life_shuffle/services/outside_event_organizer_service.dart';
import 'package:life_shuffle/services/outside_event_source_adapter.dart';
import 'package:life_shuffle/services/persistence_service.dart';
import 'package:life_shuffle/services/rss_atom_feed_parser.dart';

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

  group('RssAtomFeedParser', () {
    test('parses RSS entries into event suggestions', () {
      const parser = RssAtomFeedParser();
      final result = parser.parse(
        xmlText: '''
<rss version="2.0">
  <channel>
    <item>
      <title>Waterfront concert June 28, 2026 at 7:30pm</title>
      <link>https://example.com/waterfront-concert</link>
      <description>Music outside by the harbour.</description>
      <pubDate>Wed, 24 Jun 2026 18:52:19 +0000</pubDate>
    </item>
  </channel>
</rss>
''',
        source: const CuratedRssFeedSource(
          id: 'fixture-rss',
          displayName: 'Fixture RSS',
          url: 'https://example.com/feed.xml',
          defaultCity: 'Halifax',
          defaultTags: ['music'],
        ),
        query: OutsideEventQuery(
          start: DateTime(2026, 6, 25),
          end: DateTime(2026, 6, 30),
        ),
      );

      expect(result.warnings, isEmpty);
      expect(result.suggestions.single.displayTitle, 'Waterfront concert');
      expect(result.suggestions.single.startDateTime,
          DateTime(2026, 6, 28, 19, 30));
      expect(result.suggestions.single.tags, contains('music'));
      expect(result.suggestions.single.missingFields,
          containsAll(['address', 'price', 'venue']));
    });

    test('handles empty feeds with a warning', () {
      const parser = RssAtomFeedParser();
      final result = parser.parse(
        xmlText: '<rss version="2.0"><channel></channel></rss>',
        source: const CuratedRssFeedSource(
          id: 'empty',
          displayName: 'Empty',
          url: 'https://example.com/feed.xml',
          defaultCity: 'Halifax',
        ),
        query: OutsideEventQuery(
          start: DateTime(2026, 6, 25),
          end: DateTime(2026, 6, 30),
        ),
      );

      expect(result.suggestions, isEmpty);
      expect(result.warnings.single.message,
          'Feed loaded but did not contain any RSS/Atom entries.');
    });
  });

  group('CuratedRssOutsideEventAdapter', () {
    test('loads live feed XML through the proxy source id first', () async {
      final requested = <Uri>[];
      final adapter = CuratedRssOutsideEventAdapter(
        sources: const [
          CuratedRssFeedSource(
            id: 'fixture',
            displayName: 'Fixture feed',
            url: 'https://example.com/feed.xml',
            defaultCity: 'Halifax',
            defaultTags: ['community'],
          ),
        ],
        client: MockClient((request) async {
          requested.add(request.url);
          expect(request.url.path, '/.netlify/functions/outside-events-rss');
          expect(request.url.queryParameters['source'], 'fixture');
          return http.Response('''
<rss version="2.0">
  <channel>
    <item>
      <title>Library night July 2, 2026 at 6:00pm</title>
      <link>https://example.com/library-night</link>
      <description>A community event.</description>
    </item>
  </channel>
</rss>
''', 200);
        }),
      );

      final result = await adapter.fetch(
        OutsideEventQuery(
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 7),
        ),
      );

      expect(requested, hasLength(1));
      expect(result.suggestions.single.displayTitle, 'Library night');
      expect(result.suggestions.single.sourceName, 'Fixture feed');
    });

    test('keeps other sources working when one feed is malformed', () async {
      final adapter = CuratedRssOutsideEventAdapter(
        sources: const [
          CuratedRssFeedSource(
            id: 'bad',
            displayName: 'Bad feed',
            url: 'https://example.com/bad.xml',
            defaultCity: 'Halifax',
          ),
          CuratedRssFeedSource(
            id: 'good',
            displayName: 'Good feed',
            url: 'https://example.com/good.xml',
            defaultCity: 'Halifax',
          ),
        ],
        client: MockClient((request) async {
          if (request.url.queryParameters['source'] == 'bad') {
            return http.Response('<rss><channel><item>', 200);
          }
          return http.Response('''
<rss version="2.0">
  <channel>
    <item>
      <title>Good event July 4, 2026</title>
      <link>https://example.com/good-event</link>
    </item>
  </channel>
</rss>
''', 200);
        }),
      );

      final result = await adapter.fetch(
        OutsideEventQuery(
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 7),
        ),
      );

      expect(result.suggestions.single.displayTitle, 'Good event');
      expect(
        result.warnings.map((warning) => warning.message),
        contains('Feed could not be parsed and was skipped.'),
      );
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
