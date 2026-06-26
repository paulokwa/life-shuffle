import '../models/event_suggestion.dart';

class OutsideEventQuery {
  const OutsideEventQuery({
    required this.start,
    required this.end,
    this.city = 'Halifax',
    this.tags = const [],
    this.includeMock = true,
  });

  final DateTime start;
  final DateTime end;
  final String city;
  final List<String> tags;
  final bool includeMock;

  bool contains(DateTime value) =>
      !value.isBefore(start) && !value.isAfter(end);
}

class OutsideEventSourceConfig {
  const OutsideEventSourceConfig({
    required this.id,
    required this.displayName,
    required this.type,
    required this.enabled,
    required this.needsApiKey,
    required this.configured,
    required this.description,
    this.helpText,
  });

  final String id;
  final String displayName;
  final OutsideEventSourceType type;
  final bool enabled;
  final bool needsApiKey;
  final bool configured;
  final String description;
  final String? helpText;

  bool get canFetch => enabled && (!needsApiKey || configured);
}

class OutsideEventSourceWarning {
  const OutsideEventSourceWarning({
    required this.sourceId,
    required this.sourceName,
    required this.message,
  });

  final String sourceId;
  final String sourceName;
  final String message;
}

class OutsideEventSourceResult {
  const OutsideEventSourceResult({
    required this.source,
    this.suggestions = const [],
    this.warnings = const [],
    this.attempted = true,
  });

  final OutsideEventSourceConfig source;
  final List<EventSuggestion> suggestions;
  final List<OutsideEventSourceWarning> warnings;

  /// Whether [OutsideEventSourceAdapter.fetch] actually ran for this source.
  /// False when the source was skipped (e.g. disabled), so callers tracking
  /// per-source health (see `AppState.refreshOutsideEventSources`) can leave
  /// stale health data alone instead of treating "skipped" as "failed".
  final bool attempted;
}

abstract class OutsideEventSourceAdapter {
  OutsideEventSourceConfig get config;

  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query);
}
