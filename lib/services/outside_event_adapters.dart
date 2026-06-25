import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/event_suggestion.dart';
import '../models/user_event_source.dart';
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
        helpText: 'Curated feeds are a fallback; user-added sources are '
            'managed in Settings.',
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

    warnings.add(
      OutsideEventSourceWarning(
        sourceId: source.id,
        sourceName: source.displayName,
        message: 'Feed could not load from the Netlify proxy.',
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

class UserRssAtomOutsideEventAdapter implements OutsideEventSourceAdapter {
  UserRssAtomOutsideEventAdapter({
    required UserEventSource source,
    http.Client? client,
    RssAtomFeedParser parser = const RssAtomFeedParser(),
  })  : _source = source,
        _client = client ?? http.Client(),
        _parser = parser;

  final UserEventSource _source;
  final http.Client _client;
  final RssAtomFeedParser _parser;

  @override
  OutsideEventSourceConfig get config => OutsideEventSourceConfig(
        id: _source.id,
        displayName: _source.displayName,
        type: OutsideEventSourceType.rssAtom,
        enabled: _source.enabled,
        needsApiKey: false,
        configured: _source.url.trim().isNotEmpty,
        description: _source.url,
        helpText: _source.lastError,
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    if (!config.canFetch) return OutsideEventSourceResult(source: config);
    final proxyUri = Uri(
      path: '/.netlify/functions/outside-events-rss',
      queryParameters: {'url': _source.url},
    );
    try {
      final response = await _client.get(
        proxyUri,
        headers: const {
          'Accept': 'application/rss+xml, application/atom+xml, text/xml',
        },
      );
      if (response.statusCode != 200) {
        return OutsideEventSourceResult(
          source: config,
          warnings: [
            OutsideEventSourceWarning(
              sourceId: _source.id,
              sourceName: _source.displayName,
              message: _rssErrorMessage(response.statusCode),
            ),
          ],
        );
      }
      final parsed = _parser.parse(
        xmlText: response.body,
        source: CuratedRssFeedSource(
          id: _source.id,
          displayName: _source.displayName,
          url: _source.url,
          defaultCity: query.city,
        ),
        query: query,
      );
      return OutsideEventSourceResult(
        source: config,
        suggestions: parsed.suggestions,
        warnings: parsed.warnings,
      );
    } on XmlParserException {
      return OutsideEventSourceResult(
        source: config,
        warnings: [
          OutsideEventSourceWarning(
            sourceId: _source.id,
            sourceName: _source.displayName,
            message: 'Feed returned malformed XML and was skipped.',
          ),
        ],
      );
    } catch (_) {
      return OutsideEventSourceResult(
        source: config,
        warnings: [
          OutsideEventSourceWarning(
            sourceId: _source.id,
            sourceName: _source.displayName,
            message: 'Feed could not load. Other sources can still refresh.',
          ),
        ],
      );
    }
  }

  String _rssErrorMessage(int statusCode) {
    return switch (statusCode) {
      400 => 'Feed URL is not allowed. Use a public http or https URL.',
      405 => 'Feed proxy only supports GET requests.',
      413 => 'Feed response was too large to process.',
      415 => 'URL did not look like RSS/Atom XML.',
      _ => 'Feed could not load through the source proxy.',
    };
  }
}

class WebPageEventSourceAdapter implements OutsideEventSourceAdapter {
  WebPageEventSourceAdapter({
    required UserEventSource source,
    http.Client? client,
  })  : _source = source,
        _client = client ?? http.Client();

  final UserEventSource _source;
  final http.Client _client;

  @override
  OutsideEventSourceConfig get config => OutsideEventSourceConfig(
        id: _source.id,
        displayName: _source.displayName,
        type: OutsideEventSourceType.webPage,
        enabled: _source.enabled,
        needsApiKey: false,
        configured: _source.url.trim().isNotEmpty,
        description: _source.url,
        helpText: _source.lastError,
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    if (!config.canFetch) return OutsideEventSourceResult(source: config);
    final uri = Uri(
      path: '/.netlify/functions/outside-events-webpage',
      queryParameters: {
        'url': _source.url,
        'sourceId': _source.id,
        'sourceName': _source.displayName,
        'city': query.city,
        'start': query.start.toIso8601String(),
        'end': query.end.toIso8601String(),
      },
    );
    try {
      final response = await _client.get(
        uri,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        return OutsideEventSourceResult(
          source: config,
          warnings: [
            OutsideEventSourceWarning(
              sourceId: _source.id,
              sourceName: _source.displayName,
              message: _webErrorMessage(response.statusCode),
            ),
          ],
        );
      }
      final decoded = _decodeJson(response.body);
      final eventMaps = decoded['events'];
      final suggestions = eventMaps is Iterable
          ? eventMaps
              .whereType<Map>()
              .map((map) => EventSuggestion.fromMap(
                    Map<String, dynamic>.from(map),
                  ))
              .where((event) => query.contains(event.startDateTime))
              .toList()
          : const <EventSuggestion>[];
      final warnings = <OutsideEventSourceWarning>[
        for (final warning in _readStringList(decoded['warnings']))
          OutsideEventSourceWarning(
            sourceId: _source.id,
            sourceName: _source.displayName,
            message: warning,
          ),
      ];
      return OutsideEventSourceResult(
        source: config,
        suggestions: suggestions,
        warnings: warnings,
      );
    } catch (_) {
      return OutsideEventSourceResult(
        source: config,
        warnings: [
          OutsideEventSourceWarning(
            sourceId: _source.id,
            sourceName: _source.displayName,
            message:
                'Web page could not load. Other sources can still refresh.',
          ),
        ],
      );
    }
  }

  Map<String, dynamic> _decodeJson(String body) {
    final decoded = jsonDecode(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
  }

  List<String> _readStringList(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _webErrorMessage(int statusCode) {
    return switch (statusCode) {
      400 => 'Web page URL is not allowed. Use a public http or https URL.',
      405 => 'Web page fetcher only supports GET requests.',
      413 => 'Web page was too large to process.',
      _ => 'Web page could not load through the source proxy.',
    };
  }
}

class TicketmasterOutsideEventAdapter extends _UnconfiguredApiAdapter {
  TicketmasterOutsideEventAdapter()
      : super(
          sourceId: 'ticketmaster',
          displayName: 'Ticketmaster',
          type: OutsideEventSourceType.ticketmaster,
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
          envName: 'BANDSINTOWN_APP_ID',
          description: 'Bandsintown artist/events adapter seam.',
        );
}

class _UnconfiguredApiAdapter implements OutsideEventSourceAdapter {
  const _UnconfiguredApiAdapter({
    required this.sourceId,
    required this.displayName,
    required this.type,
    required this.envName,
    required this.description,
  });

  final String sourceId;
  final String displayName;
  final OutsideEventSourceType type;
  final String envName;
  final String description;

  @override
  OutsideEventSourceConfig get config => OutsideEventSourceConfig(
        id: sourceId,
        displayName: displayName,
        type: type,
        enabled: true,
        needsApiKey: true,
        configured: false,
        description: description,
        helpText: 'Future live support should read $envName inside a Netlify '
            'Function. Do not pass this key to Flutter or commit it.',
      );

  @override
  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query) async {
    return OutsideEventSourceResult(
      source: config,
      warnings: [
        OutsideEventSourceWarning(
          sourceId: sourceId,
          sourceName: displayName,
          message: '$displayName is a backend adapter seam for later. Set '
              '$envName only in server-side Netlify configuration when a live '
              'fetcher exists.',
        ),
      ],
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
