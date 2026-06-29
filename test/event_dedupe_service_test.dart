import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/models/event_suggestion.dart';
import 'package:life_shuffle/services/event_dedupe_service.dart';

void main() {
  group('EventDedupeService', () {
    test('merges events that share the same ticket URL', () {
      final start = DateTime(2026, 7, 3, 19);
      final a = _event(
        id: 'web-1',
        title: 'Garden Concert',
        start: start,
        sourceName: 'Venue page',
        sourceType: OutsideEventSourceType.webPage,
        ticketUrl: 'https://tickets.example.com/garden-concert',
        venueName: null,
        confidence: 0.6,
      );
      final b = _event(
        id: 'tm-1',
        title: 'Garden Concert Live',
        start: start.add(const Duration(minutes: 5)),
        sourceName: 'Ticketmaster',
        sourceType: OutsideEventSourceType.ticketmaster,
        ticketUrl: 'https://tickets.example.com/garden-concert',
        venueName: 'Victoria Park',
        confidence: 0.95,
      );

      final merged = EventDedupeService.mergeSimilar([a, b]);

      expect(merged, hasLength(1));
      expect(merged.single.id, 'web-1');
      expect(merged.single.venueName, 'Victoria Park');
      expect(merged.single.confidence, 0.95);
      expect(merged.single.mergedSources.single['sourceName'], 'Ticketmaster');
      expect(merged.single.displaySourceSummary, 'Venue page + Ticketmaster');
      expect(merged.single.missingFields, isNot(contains('venue')));
    });

    test('merges events with similar titles, close times, and matching venue',
        () {
      final a = _event(
        id: 'one',
        title: 'Waterfront Night Market',
        start: DateTime(2026, 7, 5, 18, 0),
        sourceName: 'Source A',
        sourceType: OutsideEventSourceType.webPage,
        venueName: 'Salt Yard',
      );
      final b = _event(
        id: 'two',
        title: 'Waterfront Night Market - Tickets',
        start: DateTime(2026, 7, 5, 18, 20),
        sourceName: 'Source B',
        sourceType: OutsideEventSourceType.rssAtom,
        venueName: 'Salt Yard',
      );

      final merged = EventDedupeService.mergeSimilar([a, b]);

      expect(merged, hasLength(1));
      expect(merged.single.displaySourceSummary, 'Source A + Source B');
    });

    test('does not merge unrelated events on the same day', () {
      final a = _event(
        id: 'one',
        title: 'Library film night',
        start: DateTime(2026, 7, 5, 18, 0),
        sourceName: 'Source A',
        sourceType: OutsideEventSourceType.webPage,
        venueName: 'Central Library',
      );
      final b = _event(
        id: 'two',
        title: 'Songwriter showcase',
        start: DateTime(2026, 7, 5, 19, 0),
        sourceName: 'Source B',
        sourceType: OutsideEventSourceType.rssAtom,
        venueName: 'The Carleton',
      );

      final merged = EventDedupeService.mergeSimilar([a, b]);

      expect(merged, hasLength(2));
    });

    test('does not merge unrelated events scraped from the same listing page',
        () {
      // Webpage sources stamp every event they scrape with the listing
      // page's own URL as sourceUrl, so two genuinely different events from
      // the same source landing on the same calendar day must not collapse
      // into one just because sourceUrl matches.
      final a = _event(
        id: 'one',
        title: 'Drop-in Storytime',
        start: DateTime(2026, 7, 5, 10, 0),
        sourceName: 'Halifax Libraries',
        sourceType: OutsideEventSourceType.webPage,
        venueName: 'Central Library',
        sharedSourceUrl: 'https://halifax.bibliocommons.com/v2/events',
      );
      final b = _event(
        id: 'two',
        title: 'Tech Help Drop-in',
        start: DateTime(2026, 7, 5, 14, 0),
        sourceName: 'Halifax Libraries',
        sourceType: OutsideEventSourceType.webPage,
        venueName: 'Spring Garden Road Library',
        sharedSourceUrl: 'https://halifax.bibliocommons.com/v2/events',
      );

      final merged = EventDedupeService.mergeSimilar([a, b]);

      expect(merged, hasLength(2));
    });

    test('does not merge similar titles far apart in time', () {
      final a = _event(
        id: 'one',
        title: 'Songwriter night',
        start: DateTime(2026, 7, 5, 18, 0),
        sourceName: 'Source A',
        sourceType: OutsideEventSourceType.webPage,
      );
      final b = _event(
        id: 'two',
        title: 'Songwriter night',
        start: DateTime(2026, 7, 6, 18, 0),
        sourceName: 'Source B',
        sourceType: OutsideEventSourceType.rssAtom,
      );

      final merged = EventDedupeService.mergeSimilar([a, b]);

      expect(merged, hasLength(2));
    });
  });
}

EventSuggestion _event({
  required String id,
  required String title,
  required DateTime start,
  required String sourceName,
  required OutsideEventSourceType sourceType,
  String? venueName,
  String? ticketUrl,
  double? confidence,
  String? sharedSourceUrl,
}) {
  return EventSuggestion(
    id: id,
    title: title,
    startDateTime: start,
    venueName: venueName,
    sourceName: sourceName,
    sourceType: sourceType,
    sourceUrl: sharedSourceUrl ?? 'https://example.com/$id',
    ticketUrl: ticketUrl,
    confidence: confidence,
    missingFields: venueName == null ? const ['venue'] : const [],
    dedupeKey: eventDedupeKey(title: title, start: start, venueName: venueName),
  );
}
