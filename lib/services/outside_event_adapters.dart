import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/event_suggestion.dart';
import 'curated_rss_feed_registry.dart';
import 'outside_event_source_adapter.dart';
import 'rss_atom_feed_parser.dart';

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
  CuratedRssOutsideEventAdapter({
    http.Client? client,
    List<CuratedRssFeedSource> sources = curatedRssFeedSources,
    RssAtomFeedParser parser = const RssAtomFeedParser(),
  })  : _client = client ?? http.Client(),
        _sources = sources,
        _parser = parser;

  final http.Client _client;
  final List<CuratedRssFeedSource> _sources;
  final RssAtomFeedParser _parser;

  @override
  OutsideEventSourceConfig get config => const OutsideEventSourceConfig(
        id: 'curated-rss',
        displayName: 'Curated RSS/Atom',
        type: OutsideEventSourceType.rssAtom,
        enabled: true,
        needsApiKey: false,
        configured: true,
        description: 'Hardcoded trusted Halifax/Nova Scotia RSS/Atom feeds '
            'loaded through the Netlify RSS proxy when available.',
        helpText: 'User-supplied feed URLs are intentionally not supported.',
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    final suggestions = <EventSuggestion>[];
    final warnings = <OutsideEventSourceWarning>[];

    for (final source in _sources) {
      final xmlText = await _loadFeedXml(source, warnings);
      if (xmlText == null) continue;
      try {
        final parsed = _parser.parse(
          xmlText: xmlText,
          source: source,
          query: query,
        );
        suggestions.addAll(parsed.suggestions);
        warnings.addAll(parsed.warnings);
      } on XmlParserException {
        warnings.add(
          OutsideEventSourceWarning(
            sourceId: source.id,
            sourceName: source.displayName,
            message: 'Feed returned malformed XML and was skipped.',
          ),
        );
      } catch (_) {
        warnings.add(
          OutsideEventSourceWarning(
            sourceId: source.id,
            sourceName: source.displayName,
            message: 'Feed could not be parsed and was skipped.',
          ),
        );
      }
    }

    return OutsideEventSourceResult(
      source: config,
      suggestions: suggestions,
      warnings: warnings,
    );
  }

  Future<String?> _loadFeedXml(
    CuratedRssFeedSource source,
    List<OutsideEventSourceWarning> warnings,
  ) async {
    final proxyUri = Uri(
      path: '/.netlify/functions/outside-events-rss',
      queryParameters: {'source': source.id},
    );
    final proxied = await _tryLoadUri(proxyUri);
    if (proxied != null) return proxied;

    final direct = await _tryLoadUri(Uri.parse(source.url));
    if (direct != null) return direct;

    warnings.add(
      OutsideEventSourceWarning(
        sourceId: source.id,
        sourceName: source.displayName,
        message: 'Feed could not load from the Netlify proxy or direct URL.',
      ),
    );
    return null;
  }

  Future<String?> _tryLoadUri(Uri uri) async {
    try {
      final response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/rss+xml, application/atom+xml, text/xml',
        },
      );
      if (response.statusCode != 200) return null;
      final body = response.body.trimLeft();
      if (!body.startsWith('<')) return null;
      return response.body;
    } catch (_) {
      return null;
    }
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
          description: 'Ticketmaster Discovery API adapter seam. Live calls '
              'should run through a backend function so the API key is not '
              'exposed in Flutter web.',
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
            'should be committed to the repo. For Flutter web, prefer a '
            'Netlify Function/server environment variable so credentials are '
            'not shipped to the browser.',
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
          message: '$displayName has configuration, but this prototype still '
              'needs a backend fetcher and response normalizer before it can '
              'return live suggestions.',
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
