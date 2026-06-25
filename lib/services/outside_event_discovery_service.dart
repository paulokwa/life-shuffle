import '../models/event_suggestion.dart';
import 'outside_event_adapters.dart';
import 'outside_event_organizer_service.dart';
import 'outside_event_source_adapter.dart';

class OutsideEventDiscoveryResult {
  const OutsideEventDiscoveryResult({
    required this.events,
    required this.sources,
    required this.warnings,
    required this.aiStatusMessage,
  });

  final List<EventSuggestion> events;
  final List<OutsideEventSourceConfig> sources;
  final List<OutsideEventSourceWarning> warnings;
  final String aiStatusMessage;
}

class OutsideEventDiscoveryService {
  OutsideEventDiscoveryService({
    List<OutsideEventSourceAdapter>? adapters,
    OutsideEventOrganizerService? organizer,
  })  : _adapters = adapters ?? defaultAdapters,
        _organizer = organizer ?? const OutsideEventOrganizerService();

  static List<OutsideEventSourceAdapter> get defaultAdapters => [
        const MockOutsideEventAdapter(),
        CuratedRssOutsideEventAdapter(),
        TicketmasterOutsideEventAdapter(),
        EventbriteOutsideEventAdapter(),
        BandsintownOutsideEventAdapter(),
      ];

  final List<OutsideEventSourceAdapter> _adapters;
  final OutsideEventOrganizerService _organizer;

  List<OutsideEventSourceConfig> get sources =>
      _adapters.map((adapter) => adapter.config).toList();

  Future<OutsideEventDiscoveryResult> discover(OutsideEventQuery query) async {
    final results = <OutsideEventSourceResult>[];
    for (final adapter in _adapters) {
      final config = adapter.config;
      if (!config.enabled) {
        results.add(OutsideEventSourceResult(source: config));
        continue;
      }
      try {
        results.add(await adapter.fetch(query));
      } catch (_) {
        results.add(
          OutsideEventSourceResult(
            source: config,
            warnings: [
              OutsideEventSourceWarning(
                sourceId: config.id,
                sourceName: config.displayName,
                message: '${config.displayName} could not load. Showing other '
                    'sources that did work.',
              ),
            ],
          ),
        );
      }
    }

    final deduped = <String, EventSuggestion>{};
    for (final result in results) {
      for (final event in result.suggestions) {
        final organized = _organizer.organize(event);
        deduped.putIfAbsent(organized.dedupeKey, () => organized);
      }
    }

    final events = deduped.values.toList()
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
    );
  }
}
