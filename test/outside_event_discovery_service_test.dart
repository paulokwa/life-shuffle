import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_shuffle/models/activity.dart';
import 'package:life_shuffle/models/event_suggestion.dart';
import 'package:life_shuffle/models/manual_plan_item.dart';
import 'package:life_shuffle/models/user_event_source.dart';
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
      expect(item.outsideEventSourceType, 'mock');
      expect(item.outsideEventTags, ['market', 'food']);
    });

    test(
        'preserves confidence, extraction mode, and uncertain fields on the manual item',
        () {
      final start = DateTime(2026, 7, 3, 19);
      final event = EventSuggestion(
        id: 'evt-ai',
        title: 'AI-organized event',
        startDateTime: start,
        sourceName: 'Venue page',
        sourceType: OutsideEventSourceType.webPage,
        confidence: 0.74,
        missingFields: const ['address', 'price'],
        raw: const {'extractionMode': 'ai-openai-webpage'},
        dedupeKey: eventDedupeKey(title: 'AI-organized event', start: start),
      );

      final item = event.toManualPlanItem(id: 'outside-ai');
      final restored = ManualPlanItem.fromMap(item.toMap());

      expect(item.outsideEventConfidence, 0.74);
      expect(item.outsideEventUncertainFields, ['address', 'price']);
      expect(item.outsideEventExtractionMode, 'ai-openai-webpage');
      expect(restored.outsideEventConfidence, 0.74);
      expect(restored.outsideEventUncertainFields, ['address', 'price']);
      expect(restored.outsideEventExtractionMode, 'ai-openai-webpage');
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
    test('default discovery excludes mock sources', () {
      expect(
        OutsideEventDiscoveryService.defaultAdapters
            .map((adapter) => adapter.config.type),
        isNot(contains(OutsideEventSourceType.mock)),
      );
      expect(
        OutsideEventQuery(
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 7),
        ).includeMock,
        isFalse,
      );
    });

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

    test('tracks which sources were attempted and how many events each found',
        () async {
      final start = DateTime(2026, 7, 1);
      final service = OutsideEventDiscoveryService(
        adapters: [
          _FixedAdapter(
            id: 'enabled-source',
            displayName: 'Enabled',
            events: [
              _event(
                id: 'one',
                title: 'Event one',
                start: start.add(const Duration(days: 1, hours: 10)),
              ),
              _event(
                id: 'two',
                title: 'Event two',
                start: start.add(const Duration(days: 2, hours: 10)),
              ),
            ],
          ),
          const _FixedAdapter(
            id: 'disabled-source',
            displayName: 'Disabled',
            events: [],
            enabled: false,
          ),
        ],
      );

      final result = await service.discover(
        OutsideEventQuery(
            start: start, end: start.add(const Duration(days: 7))),
      );

      expect(result.attemptedSourceIds, contains('enabled-source'));
      expect(result.attemptedSourceIds, isNot(contains('disabled-source')));
      expect(result.sourceEventCounts['enabled-source'], 2);
      expect(result.sourceEventCounts['disabled-source'], 0);
    });

    test('reports per-source start/result progress for attempted sources only',
        () async {
      final start = DateTime(2026, 7, 1);
      final service = OutsideEventDiscoveryService(
        adapters: [
          _FixedAdapter(id: 'a', displayName: 'A', events: const []),
          const _FixedAdapter(
            id: 'disabled',
            displayName: 'Disabled',
            events: [],
            enabled: false,
          ),
          _FixedAdapter(id: 'b', displayName: 'B', events: const []),
        ],
      );
      final started = <String>[];
      final finished = <String>[];

      await service.discover(
        OutsideEventQuery(
            start: start, end: start.add(const Duration(days: 7))),
        onSourceStart: (config) => started.add(config.id),
        onSourceResult: (result) => finished.add(result.source.id),
      );

      expect(started, ['a', 'b']);
      expect(finished, ['a', 'disabled', 'b']);
    });

    test('webpageAiConfigured reflects the most recent webpage source result',
        () async {
      final start = DateTime(2026, 7, 1);
      final service = OutsideEventDiscoveryService(
        adapters: [
          _FixedAdapter(id: 'rss', displayName: 'RSS', events: const []),
          _FixedAdapter(
            id: 'web',
            displayName: 'Web',
            events: const [],
            aiConfigured: true,
          ),
        ],
      );

      final result = await service.discover(
        OutsideEventQuery(
            start: start, end: start.add(const Duration(days: 7))),
      );

      expect(result.webpageAiConfigured, isTrue);
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

    test(
        'reports a distinct warning when every entry falls outside the '
        'planning range', () {
      const parser = RssAtomFeedParser();
      final result = parser.parse(
        xmlText: '''
<rss version="2.0">
  <channel>
    <item>
      <title>16th Annual Dalhousie Mawio'mi</title>
      <link>https://events.dal.ca/event/5865</link>
      <pubDate>Tue, 29 Sep 2026 13:00:00 +0000</pubDate>
    </item>
    <item>
      <title>DAC Presents: JB Smoove Live</title>
      <link>https://events.dal.ca/event/5910</link>
      <pubDate>Tue, 27 Oct 2026 22:30:00 +0000</pubDate>
    </item>
  </channel>
</rss>
''',
        source: const CuratedRssFeedSource(
          id: 'dal',
          displayName: 'Dalhousie Events',
          url: 'https://events.dal.ca/feed.xml',
          defaultCity: 'Halifax',
        ),
        query: OutsideEventQuery(
          start: DateTime(2026, 6, 28),
          end: DateTime(2026, 7, 28),
        ),
      );

      expect(result.suggestions, isEmpty);
      expect(
        result.warnings.single.message,
        contains(
            '2 feed entries were found, but outside your current planning '
            'range'),
      );
      expect(result.warnings.single.category,
          OutsideEventFailureCategory.noEventsFound);
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

  group('User-managed event source adapters', () {
    test('loads user RSS URLs through the Netlify proxy url parameter',
        () async {
      final adapter = UserRssAtomOutsideEventAdapter(
        source: const UserEventSource(
          id: 'user-rss',
          displayName: 'User feed',
          url: 'https://example.com/events/feed.xml',
          kind: UserEventSourceKind.rssAtom,
        ),
        client: MockClient((request) async {
          expect(request.url.path, '/.netlify/functions/outside-events-rss');
          expect(request.url.queryParameters['url'],
              'https://example.com/events/feed.xml');
          return http.Response('''
<rss version="2.0">
  <channel>
    <item>
      <title>User feed event July 2, 2026 at 7:00pm</title>
      <link>https://example.com/user-event</link>
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

      expect(
          result.suggestions.single.sourceType, OutsideEventSourceType.rssAtom);
      expect(result.suggestions.single.sourceName, 'User feed');
    });

    test('loads webpage URLs through the webpage Netlify function', () async {
      final adapter = WebPageEventSourceAdapter(
        source: const UserEventSource(
          id: 'user-web',
          displayName: 'Venue page',
          url: 'https://example.com/events',
          kind: UserEventSourceKind.webPage,
        ),
        client: MockClient((request) async {
          expect(
              request.url.path, '/.netlify/functions/outside-events-webpage');
          expect(
              request.url.queryParameters['url'], 'https://example.com/events');
          return http.Response(
            '''
{
  "warnings": ["AI organizer not configured. Used deterministic webpage extraction; review dates and details before adding."],
  "events": [
    {
      "id": "web-1",
      "title": "Garden concert",
      "cleanedTitle": "Garden concert",
      "summary": "Free outdoor music.",
      "startDateTimeMillis": 1783116000000,
      "sourceName": "Venue page",
      "sourceType": "webPage",
      "sourceUrl": "https://example.com/events",
      "tags": ["music"],
      "missingFields": ["venue", "address", "price"],
      "dedupeKey": "garden concert|2026-07-03|19|00|"
    }
  ]
}
''',
            200,
          );
        }),
      );

      final result = await adapter.fetch(
        OutsideEventQuery(
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 7, 23, 59),
        ),
      );

      expect(
          result.suggestions.single.sourceType, OutsideEventSourceType.webPage);
      expect(result.suggestions.single.sourceName, 'Venue page');
      expect(result.warnings.single.message, contains('AI organizer'));
    });

    test('loads user ICS URLs through the Netlify proxy url parameter',
        () async {
      final adapter = UserIcsOutsideEventAdapter(
        source: const UserEventSource(
          id: 'user-ics',
          displayName: 'Halifax Events',
          url: 'https://halifaxevents.ca/events/?ical=1',
          kind: UserEventSourceKind.icsCalendar,
        ),
        client: MockClient((request) async {
          expect(request.url.path, '/.netlify/functions/outside-events-ics');
          expect(request.url.queryParameters['url'],
              'https://halifaxevents.ca/events/?ical=1');
          return http.Response(
            [
              'BEGIN:VCALENDAR',
              'BEGIN:VEVENT',
              'SUMMARY:Geekorium 2026',
              'DTSTART:20260627T100000Z',
              'END:VEVENT',
              'END:VCALENDAR',
            ].join('\r\n'),
            200,
          );
        }),
      );

      final result = await adapter.fetch(
        OutsideEventQuery(
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 7, 31),
        ),
      );

      expect(result.suggestions.single.sourceType,
          OutsideEventSourceType.icsCalendar);
      expect(result.suggestions.single.sourceName, 'Halifax Events');
      expect(result.suggestions.single.title, 'Geekorium 2026');
    });
  });

  group('TicketmasterOutsideEventAdapter', () {
    test(
        'reports unconfigured state from the backend as a warning, not suggestions',
        () async {
      final adapter = TicketmasterOutsideEventAdapter(
        client: MockClient((request) async {
          expect(request.url.path,
              '/.netlify/functions/outside-events-ticketmaster');
          return http.Response(
            '{"configured": false, "events": [], "warnings": ["Ticketmaster is not configured."]}',
            200,
          );
        }),
      );

      final result = await adapter.fetch(
        OutsideEventQuery(
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 7, 23, 59),
        ),
      );

      expect(result.suggestions, isEmpty);
      expect(result.warnings.single.message, contains('not configured'));
    });

    test('maps live Ticketmaster events into EventSuggestions', () async {
      final adapter = TicketmasterOutsideEventAdapter(
        client: MockClient((request) async {
          expect(request.url.queryParameters['city'], 'Halifax');
          return http.Response(
            '''
{
  "configured": true,
  "events": [
    {
      "id": "tm-1",
      "title": "Garden concert",
      "cleanedTitle": "Garden concert",
      "startDateTimeMillis": 1783116000000,
      "sourceName": "Ticketmaster",
      "sourceType": "ticketmaster",
      "sourceUrl": "https://ticketmaster.example/tm-1",
      "ticketUrl": "https://ticketmaster.example/tm-1",
      "venueName": "Scotiabank Centre",
      "tags": ["music"],
      "confidence": 0.95,
      "missingFields": [],
      "dedupeKey": "garden concert|2026-07-03|19|00|scotiabank centre"
    }
  ],
  "warnings": []
}
''',
            200,
          );
        }),
      );

      final result = await adapter.fetch(
        OutsideEventQuery(
          start: DateTime(2026, 7),
          end: DateTime(2026, 7, 7, 23, 59),
          city: 'Halifax',
        ),
      );

      expect(result.suggestions.single.sourceType,
          OutsideEventSourceType.ticketmaster);
      expect(result.suggestions.single.venueName, 'Scotiabank Centre');
      expect(result.suggestions.single.confidence, 0.95);
    });
  });

  group('UserEventSource health', () {
    test('reports unknown before any attempt', () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.rssAtom,
      );

      expect(source.healthStatus, SourceHealthStatus.unknown);
    });

    test('reports healthy after a clean attempt', () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.rssAtom,
        lastFetchedAtMillis: 100,
        lastEventCount: 3,
      );

      expect(source.healthStatus, SourceHealthStatus.healthy);
    });

    test('reports warning when a warning still found events', () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.rssAtom,
        lastFetchedAtMillis: 100,
        lastEventCount: 2,
        lastError: 'Some entries were skipped.',
      );

      expect(source.healthStatus, SourceHealthStatus.warning);
    });

    test('reports failed when a warning found no events', () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.rssAtom,
        lastFetchedAtMillis: 100,
        lastEventCount: 0,
        lastError: 'Feed could not load.',
      );

      expect(source.healthStatus, SourceHealthStatus.failed);
    });

    test(
        'reports noEventsInRange (not failed) when events were found but '
        'all outside the planning range', () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.rssAtom,
        lastFetchedAtMillis: 100,
        lastEventCount: 0,
        lastError: '2 feed entries were found, but outside your current '
            'planning range.',
        lastErrorCategory: 'noEventsFound',
      );

      expect(source.healthStatus, SourceHealthStatus.noEventsInRange);
    });

    test('round-trips health fields through toMap/fromMap', () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.rssAtom,
        lastFetchedAtMillis: 100,
        lastSuccessAtMillis: 90,
        lastEventCount: 4,
      );

      final restored = UserEventSource.fromMap(source.toMap());

      expect(restored.lastFetchedAtMillis, 100);
      expect(restored.lastSuccessAtMillis, 90);
      expect(restored.lastEventCount, 4);
    });

    test(
        'round-trips diagnostic category and HTTP status through toMap/fromMap',
        () {
      const source = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.webPage,
        lastFetchedAtMillis: 100,
        lastError: 'Web page could not load through the source proxy.',
        lastErrorCategory: 'upstreamError',
        lastErrorHttpStatusCode: 503,
      );

      final restored = UserEventSource.fromMap(source.toMap());

      expect(restored.lastErrorCategory, 'upstreamError');
      expect(restored.lastErrorHttpStatusCode, 503);
    });

    test('copyWith clears diagnostic category and HTTP status on success', () {
      const failed = UserEventSource(
        id: 'src',
        displayName: 'Source',
        url: 'https://example.com/feed.xml',
        kind: UserEventSourceKind.webPage,
        lastFetchedAtMillis: 100,
        lastError: 'Web page could not load.',
        lastErrorCategory: 'corsOrProxy',
        lastErrorHttpStatusCode: 502,
      );

      final healthy = failed.copyWith(
        lastFetchedAtMillis: 200,
        clearLastError: true,
        clearLastErrorCategory: true,
        clearLastErrorHttpStatusCode: true,
      );

      expect(healthy.lastError, isNull);
      expect(healthy.lastErrorCategory, isNull);
      expect(healthy.lastErrorHttpStatusCode, isNull);
      expect(healthy.healthStatus, SourceHealthStatus.healthy);
    });
  });

  group('EventSuggestion extraction metadata', () {
    test('exposes extractionMode and isAiOrganized from raw', () {
      final aiEvent = _event(
        id: 'ai-1',
        title: 'AI event',
        start: DateTime(2026, 7, 5, 19),
      ).copyWith(raw: const {'extractionMode': 'ai-openai-webpage'});
      final deterministicEvent = _event(
        id: 'det-1',
        title: 'Deterministic event',
        start: DateTime(2026, 7, 5, 19),
      ).copyWith(
        raw: const {'extractionMode': 'deterministic-webpage-fallback'},
      );
      final plainEvent = _event(
        id: 'plain-1',
        title: 'Plain event',
        start: DateTime(2026, 7, 5, 19),
      );

      expect(aiEvent.isAiOrganized, isTrue);
      expect(deterministicEvent.isAiOrganized, isFalse);
      expect(plainEvent.extractionMode, isNull);
      expect(plainEvent.isAiOrganized, isFalse);
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
    this.enabled = true,
    this.aiConfigured,
  });

  final String id;
  final String displayName;
  final List<EventSuggestion> events;
  final String? warning;
  final bool enabled;
  final bool? aiConfigured;

  @override
  OutsideEventSourceConfig get config => OutsideEventSourceConfig(
        id: id,
        displayName: displayName,
        type: OutsideEventSourceType.mock,
        enabled: enabled,
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
      aiConfigured: aiConfigured,
    );
  }
}
