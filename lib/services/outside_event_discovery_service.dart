import '../models/event_suggestion.dart';
import 'event_dedupe_service.dart';
import 'outside_event_adapters.dart';
import 'outside_event_organizer_service.dart';
import 'outside_event_source_adapter.dart';

class OutsideEventDiscoveryResult {
  const OutsideEventDiscoveryResult({
    required this.events,
    required this.sources,
    required this.warnings,
    required this.aiStatusMessage,
    this.attemptedSourceIds = const {},
    this.sourceEventCounts = const {},
    this.webpageAiConfigured,
  });

  final List<EventSuggestion> events;
  final List<OutsideEventSourceConfig> sources;
  final List<OutsideEventSourceWarning> warnings;
  final String aiStatusMessage;

  /// Source ids whose adapter actually ran (vs. being skipped because it
  /// was disabled). Used to drive per-source health in Settings.
  final Set<String> attemptedSourceIds;

  /// Raw (pre-dedupe) suggestion count per source id, i.e. "events found"
  /// for source health, distinct from the final deduped [events] list.
  final Map<String, int> sourceEventCounts;

  /// Whether the server-side AI organizer was configured, from the most
  /// recent attempted webpage source that reported it. Null when no webpage
  /// source was attempted this refresh (AI configuration is a single
  /// server-side setting, so any one webpage fetch reflects all of them).
  final bool? webpageAiConfigured;
}

/// Tally shown to the user after a manual outside-events refresh (Settings
/// "Fetch latest events" / Outside events "Refresh"): how many sources were
/// checked, how many succeeded/failed, and how many events were found.
class OutsideEventRefreshSummary {
  const OutsideEventRefreshSummary({
    required this.sourcesChecked,
    required this.sourcesSucceeded,
    required this.sourcesFailed,
    required this.eventsFound,
  });

  final int sourcesChecked;
  final int sourcesSucceeded;
  final int sourcesFailed;
  final int eventsFound;
}

class OutsideEventDiscoveryService {
  OutsideEventDiscoveryService({
    List<OutsideEventSourceAdapter>? adapters,
    OutsideEventOrganizerService? organizer,
  })  : _adapters = adapters ?? defaultAdapters,
        _organizer = organizer ?? const OutsideEventOrganizerService();

  static List<OutsideEventSourceAdapter> get defaultAdapters => [
        CuratedRssOutsideEventAdapter(),
        TicketmasterOutsideEventAdapter(),
        EventbriteOutsideEventAdapter(),
        BandsintownOutsideEventAdapter(),
      ];

  final List<OutsideEventSourceAdapter> _adapters;
  final OutsideEventOrganizerService _organizer;

  List<OutsideEventSourceConfig> get sources =>
      _adapters.map((adapter) => adapter.config).toList();

  Future<OutsideEventDiscoveryResult> discover(
    OutsideEventQuery query, {
    void Function(OutsideEventSourceConfig config)? onSourceStart,
    void Function(OutsideEventSourceResult result)? onSourceResult,
  }) async {
    final results = <OutsideEventSourceResult>[];
    for (final adapter in _adapters) {
      final config = adapter.config;
      if (!config.enabled) {
        final skipped =
            OutsideEventSourceResult(source: config, attempted: false);
        results.add(skipped);
        onSourceResult?.call(skipped);
        continue;
      }
      onSourceStart?.call(config);
      OutsideEventSourceResult result;
      try {
        result = await adapter.fetch(query);
      } catch (_) {
        result = OutsideEventSourceResult(
          source: config,
          warnings: [
            OutsideEventSourceWarning(
              sourceId: config.id,
              sourceName: config.displayName,
              message: '${config.displayName} could not load. Showing other '
                  'sources that did work.',
              category: OutsideEventFailureCategory.corsOrProxy,
            ),
          ],
        );
      }
      results.add(result);
      onSourceResult?.call(result);
    }

    final deduped = <String, EventSuggestion>{};
    for (final result in results) {
      for (final event in result.suggestions) {
        final organized = _organizer.organize(event);
        deduped.putIfAbsent(organized.dedupeKey, () => organized);
      }
    }

    final events = EventDedupeService.mergeSimilar(deduped.values.toList())
      ..sort((a, b) {
        final byDate = a.startDateTime.compareTo(b.startDateTime);
        if (byDate != 0) return byDate;
        return a.displayTitle.compareTo(b.displayTitle);
      });

    return OutsideEventDiscoveryResult(
      events: events,
      sources: results.map((result) => result.source).toList(),
      warnings: results.expand((result) => result.warnings).toList(),
      aiStatusMessage: _organizer.aiStatusMessage,
      attemptedSourceIds: {
        for (final result in results)
          if (result.attempted) result.source.id,
      },
      sourceEventCounts: {
        for (final result in results)
          result.source.id: result.suggestions.length,
      },
      webpageAiConfigured: _lastNonNull(
        results.map((result) => result.aiConfigured),
      ),
    );
  }

  static bool? _lastNonNull(Iterable<bool?> values) {
    bool? found;
    for (final value in values) {
      if (value != null) found = value;
    }
    return found;
  }
}
