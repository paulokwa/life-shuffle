import '../models/event_suggestion.dart';

/// Merges near-duplicate [EventSuggestion]s that survived the discovery
/// service's exact dedupe pass - e.g. the same concert posted on a venue
/// webpage and pulled in again via Ticketmaster with slightly different
/// title punctuation or a start time a few minutes off. Exact duplicates
/// (identical [EventSuggestion.dedupeKey]) are handled earlier by
/// [OutsideEventDiscoveryService]; this pass only looks for *similar* ones.
class EventDedupeService {
  const EventDedupeService._();

  static const _titleSimilarityThreshold = 0.6;
  static const _venueSimilarityThreshold = 0.5;
  static const _maxMinutesApart = 90;

  /// Clusters [events] by similarity and merges each cluster into a single
  /// [EventSuggestion], preferring whichever non-empty field value it finds
  /// (richer wins) and unioning tags. Input order is preserved for the
  /// surviving representative of each cluster.
  static List<EventSuggestion> mergeSimilar(List<EventSuggestion> events) {
    final clusters = <EventSuggestion>[];
    for (final event in events) {
      var mergedIndex = -1;
      for (var i = 0; i < clusters.length; i++) {
        if (_isDuplicate(clusters[i], event)) {
          mergedIndex = i;
          break;
        }
      }
      if (mergedIndex == -1) {
        clusters.add(event);
      } else {
        clusters[mergedIndex] = _merge(clusters[mergedIndex], event);
      }
    }
    return clusters;
  }

  static bool _isDuplicate(EventSuggestion a, EventSuggestion b) {
    if (_sameNonEmptyUrl(a.ticketUrl, b.ticketUrl)) return true;
    if (_sameNonEmptyUrl(a.sourceUrl, b.sourceUrl) &&
        _sameDate(a.startDateTime, b.startDateTime)) {
      return true;
    }
    final minutesApart =
        a.startDateTime.difference(b.startDateTime).inMinutes.abs();
    if (minutesApart > _maxMinutesApart) return false;
    if (!_titlesSimilar(a.displayTitle, b.displayTitle)) return false;
    return _venuesCompatible(a.venueName, b.venueName);
  }

  static bool _sameNonEmptyUrl(String? a, String? b) {
    final normalizedA = _normalizeUrl(a);
    final normalizedB = _normalizeUrl(b);
    return normalizedA != null && normalizedA == normalizedB;
  }

  static String? _normalizeUrl(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase().replaceAll(RegExp(r'/+$'), '');
  }

  static bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _venuesCompatible(String? a, String? b) {
    final wordsA = _normalizeWords(a);
    final wordsB = _normalizeWords(b);
    if (wordsA.isEmpty || wordsB.isEmpty) return true;
    return _jaccard(wordsA, wordsB) >= _venueSimilarityThreshold;
  }

  static bool _titlesSimilar(String a, String b) {
    final wordsA = _normalizeWords(a);
    final wordsB = _normalizeWords(b);
    if (wordsA.isEmpty || wordsB.isEmpty) return false;
    return _jaccard(wordsA, wordsB) >= _titleSimilarityThreshold;
  }

  static Set<String> _normalizeWords(String? value) {
    final lower = (value ?? '').toLowerCase();
    final stripped = lower.replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
    return stripped
        .split(' ')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toSet();
  }

  static double _jaccard(Set<String> a, Set<String> b) {
    final union = a.union(b).length;
    if (union == 0) return 0;
    return a.intersection(b).length / union;
  }

  static EventSuggestion _merge(EventSuggestion base, EventSuggestion other) {
    final venueName = _preferNonEmpty(base.venueName, other.venueName);
    final address = _preferNonEmpty(base.address, other.address);
    final priceLabel = _preferNonEmpty(base.priceLabel, other.priceLabel);
    final isFree = base.isFree ?? other.isFree;

    final mergedSources = <Map<String, Object?>>[
      ...base.mergedSources,
      {
        'sourceName': other.sourceName,
        'sourceType': other.sourceType.storageName,
        if (other.sourceUrl != null) 'sourceUrl': other.sourceUrl,
        if (other.sourceId != null) 'sourceId': other.sourceId,
      },
    ];
    final extraMissing = <String>{
      ...base.missingFields,
      ...other.missingFields,
    }..removeWhere(
        (field) => const {'venue', 'address', 'price'}.contains(field));

    return base.copyWith(
      venueName: venueName,
      address: address,
      city: _preferNonEmpty(base.city, other.city),
      priceLabel: priceLabel,
      isFree: isFree,
      summary: _preferNonEmpty(base.summary, other.summary),
      sourceUrl: _preferNonEmpty(base.sourceUrl, other.sourceUrl),
      ticketUrl: _preferNonEmpty(base.ticketUrl, other.ticketUrl),
      tags: ({...base.tags, ...other.tags}.toList()..sort()),
      confidence: _maxConfidence(base.confidence, other.confidence),
      missingFields: _missingFieldsFor(
        venueName: venueName,
        address: address,
        priceLabel: priceLabel,
        isFree: isFree,
        extras: extraMissing,
      ),
      raw: {...base.raw, 'mergedSources': mergedSources},
    );
  }

  static List<String> _missingFieldsFor({
    required String? venueName,
    required String? address,
    required String? priceLabel,
    required bool? isFree,
    required Set<String> extras,
  }) {
    final missing = <String>{...extras};
    if (venueName == null || venueName.trim().isEmpty) missing.add('venue');
    if (address == null || address.trim().isEmpty) missing.add('address');
    if (priceLabel == null && isFree == null) missing.add('price');
    return missing.toList()..sort();
  }

  static String? _preferNonEmpty(String? a, String? b) {
    if (a != null && a.trim().isNotEmpty) return a;
    if (b != null && b.trim().isNotEmpty) return b;
    return null;
  }

  static double? _maxConfidence(double? a, double? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a >= b ? a : b;
  }
}
