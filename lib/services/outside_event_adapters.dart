import '../models/event_suggestion.dart';
import 'outside_event_source_adapter.dart';

class MockOutsideEventAdapter implements OutsideEventSourceAdapter {
  const MockOutsideEventAdapter();

  @override
  OutsideEventSourceConfig get config => const OutsideEventSourceConfig(
        id: 'mock-sample',
        displayName: 'Sample events',
        type: OutsideEventSourceType.mock,
        enabled: true,
        needsApiKey: false,
        configured: true,
        description: 'Always-on sample data so the browser is testable.',
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    if (!query.includeMock) {
      return OutsideEventSourceResult(source: config);
    }
    final start = _dateOnly(query.start);
    final suggestions = [
      _event(
        id: 'mock-waterfront-market',
        title: 'Halifax Waterfront Makers Market',
        summary: 'A relaxed outdoor market with local food, prints, ceramics, '
            'and small gifts along the boardwalk.',
        start: start.add(const Duration(days: 1, hours: 11)),
        end: start.add(const Duration(days: 1, hours: 14)),
        venueName: 'Salt Yard',
        address: 'Halifax Waterfront',
        city: query.city,
        priceLabel: 'Free to browse',
        tags: const ['market', 'outdoors', 'free/low-cost', 'arts/culture'],
      ),
      _event(
        id: 'mock-library-film',
        title: 'Neighbourhood film night: comfort classics',
        summary: 'A low-key community screening with a short discussion after.',
        start: start.add(const Duration(days: 3, hours: 18, minutes: 30)),
        end: start.add(const Duration(days: 3, hours: 20, minutes: 30)),
        venueName: 'Central Library',
        address: '5440 Spring Garden Road',
        city: query.city,
        priceLabel: 'Free',
        isFree: true,
        tags: const ['community', 'arts/culture', 'free/low-cost'],
      ),
      _event(
        id: 'mock-small-show',
        title: 'Small room songwriter night',
        summary: 'Three local songwriters trading short sets in an easygoing '
            'listening-room format.',
        start: start.add(const Duration(days: 5, hours: 19)),
        end: start.add(const Duration(days: 5, hours: 21)),
        venueName: 'The Carleton',
        address: '1685 Argyle Street',
        city: query.city,
        priceLabel: 'Tickets from \$18',
        tags: const ['music', 'couple-friendly'],
      ),
    ].where((event) => query.contains(event.startDateTime)).toList();

    return OutsideEventSourceResult(source: config, suggestions: suggestions);
  }

  static EventSuggestion _event({
    required String id,
    required String title,
    required String summary,
    required DateTime start,
    required DateTime end,
    required String venueName,
    required String address,
    required String city,
    required String priceLabel,
    required List<String> tags,
    bool? isFree,
  }) {
    return EventSuggestion(
      id: id,
      title: title,
      cleanedTitle: title,
      summary: summary,
      startDateTime: start,
      endDateTime: end,
      venueName: venueName,
      address: address,
      city: city,
      sourceName: 'Sample events',
      sourceType: OutsideEventSourceType.mock,
      sourceUrl: 'https://example.com/life-shuffle/sample-events/$id',
      ticketUrl: 'https://example.com/life-shuffle/sample-events/$id/tickets',
      priceLabel: priceLabel,
      isFree: isFree,
      tags: tags,
      confidence: 1,
      dedupeKey: eventDedupeKey(
        title: title,
        start: start,
        venueName: venueName,
      ),
    );
  }
}

class CuratedRssOutsideEventAdapter implements OutsideEventSourceAdapter {
  const CuratedRssOutsideEventAdapter();

  @override
  OutsideEventSourceConfig get config => const OutsideEventSourceConfig(
        id: 'curated-rss',
        displayName: 'Curated RSS/Atom',
        type: OutsideEventSourceType.rssAtom,
        enabled: true,
        needsApiKey: false,
        configured: true,
        description: 'Hardcoded trusted local feeds. This spike uses '
            'RSS-style sample entries until real feed URLs are vetted.',
        helpText: 'User-supplied feed URLs are intentionally not supported.',
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    final start = _dateOnly(query.start);
    final suggestions = [
      EventSuggestion(
        id: 'rss-style-public-garden-walk',
        title: '<b>Public Gardens evening walk</b>',
        description: 'A guided seasonal stroll through the gardens with short '
            'stops for local history and plant notes.',
        startDateTime:
            start.add(const Duration(days: 2, hours: 17, minutes: 30)),
        endDateTime: start.add(const Duration(days: 2, hours: 18, minutes: 30)),
        venueName: 'Halifax Public Gardens',
        address: 'Spring Garden Road',
        city: query.city,
        sourceName: 'Curated RSS sample',
        sourceType: OutsideEventSourceType.rssAtom,
        sourceUrl: 'https://example.com/rss/public-garden-walk',
        priceLabel: null,
        tags: const ['outdoors', 'community'],
        missingFields: const ['price'],
        raw: const {'adapter': 'curated-rss-sample'},
        dedupeKey: eventDedupeKey(
          title: 'Public Gardens evening walk',
          start: start.add(
            const Duration(days: 2, hours: 17, minutes: 30),
          ),
          venueName: 'Halifax Public Gardens',
        ),
      ),
      EventSuggestion(
        id: 'rss-style-night-market',
        title: 'North End Night Market',
        description: 'Food vendors, small makers, and a short acoustic set.',
        startDateTime: start.add(const Duration(days: 6, hours: 18)),
        endDateTime: start.add(const Duration(days: 6, hours: 21)),
        venueName: 'Local Source Market',
        address: 'Windsor Street',
        city: query.city,
        sourceName: 'Curated RSS sample',
        sourceType: OutsideEventSourceType.rssAtom,
        sourceUrl: 'https://example.com/rss/night-market',
        priceLabel: 'Free entry',
        isFree: true,
        tags: const ['market', 'food', 'music', 'free/low-cost'],
        raw: const {'adapter': 'curated-rss-sample'},
        dedupeKey: eventDedupeKey(
          title: 'North End Night Market',
          start: start.add(const Duration(days: 6, hours: 18)),
          venueName: 'Local Source Market',
        ),
      ),
    ].where((event) => query.contains(event.startDateTime)).toList();

    return OutsideEventSourceResult(
      source: config,
      suggestions: suggestions,
      warnings: const [
        OutsideEventSourceWarning(
          sourceId: 'curated-rss',
          sourceName: 'Curated RSS/Atom',
          message: 'Using vetted sample entries until real Halifax feeds are '
              'chosen and checked for CORS/format reliability.',
        ),
      ],
    );
  }
}

class TicketmasterOutsideEventAdapter extends _UnconfiguredApiAdapter {
  TicketmasterOutsideEventAdapter()
      : super(
          sourceId: 'ticketmaster',
          displayName: 'Ticketmaster',
          type: OutsideEventSourceType.ticketmaster,
          configured:
              const String.fromEnvironment('TICKETMASTER_API_KEY').isNotEmpty,
          envName: 'TICKETMASTER_API_KEY',
          description: 'Ticketmaster Discovery API adapter seam.',
        );
}

class EventbriteOutsideEventAdapter extends _UnconfiguredApiAdapter {
  EventbriteOutsideEventAdapter()
      : super(
          sourceId: 'eventbrite',
          displayName: 'Eventbrite',
          type: OutsideEventSourceType.eventbrite,
          configured:
              const String.fromEnvironment('EVENTBRITE_API_TOKEN').isNotEmpty,
          envName: 'EVENTBRITE_API_TOKEN',
          description: 'Eventbrite adapter seam. Token/access shape still '
              'needs verification before live calls are enabled.',
        );
}

class BandsintownOutsideEventAdapter extends _UnconfiguredApiAdapter {
  BandsintownOutsideEventAdapter()
      : super(
          sourceId: 'bandsintown',
          displayName: 'Bandsintown',
          type: OutsideEventSourceType.bandsintown,
          configured:
              const String.fromEnvironment('BANDSINTOWN_APP_ID').isNotEmpty,
          envName: 'BANDSINTOWN_APP_ID',
          description: 'Bandsintown artist/events adapter seam.',
        );
}

class _UnconfiguredApiAdapter implements OutsideEventSourceAdapter {
  const _UnconfiguredApiAdapter({
    required this.sourceId,
    required this.displayName,
    required this.type,
    required this.configured,
    required this.envName,
    required this.description,
  });

  final String sourceId;
  final String displayName;
  final OutsideEventSourceType type;
  final bool configured;
  final String envName;
  final String description;

  @override
  OutsideEventSourceConfig get config => OutsideEventSourceConfig(
        id: sourceId,
        displayName: displayName,
        type: type,
        enabled: true,
        needsApiKey: true,
        configured: configured,
        description: description,
        helpText: 'Set $envName as a compile-time environment value. No key '
            'should be committed to the repo.',
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    if (!configured) {
      return OutsideEventSourceResult(
        source: config,
        warnings: [
          OutsideEventSourceWarning(
            sourceId: sourceId,
            sourceName: displayName,
            message: '$displayName is not configured. Set $envName outside '
                'the repo to enable this source.',
          ),
        ],
      );
    }
    return OutsideEventSourceResult(
      source: config,
      warnings: [
        OutsideEventSourceWarning(
          sourceId: sourceId,
          sourceName: displayName,
          message: '$displayName has configuration, but live normalization is '
              'left as a spike TODO so the prototype does not block on API '
              'contract/rate-limit details.',
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
