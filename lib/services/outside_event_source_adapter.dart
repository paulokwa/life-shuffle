import '../models/event_suggestion.dart';

class OutsideEventQuery {
  const OutsideEventQuery({
    required this.start,
    required this.end,
    this.city = 'Halifax',
    this.tags = const [],
    this.includeMock = false,
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

/// Coarse, developer-facing classification of why a source's fetch
/// produced a warning, shown in Settings diagnostics so a failure can be
/// triaged without reading server logs. Best-effort: adapters only set this
/// when the cause is reasonably certain from the HTTP status/exception they
/// observed; [unknown] covers everything else.
enum OutsideEventFailureCategory {
  /// The source URL itself was rejected before any fetch (private/local
  /// address, unsupported scheme, etc).
  blockedUrl,

  /// The request timed out waiting for a response.
  timeout,

  /// The client-side request to our own Netlify proxy failed outright
  /// (network error, proxy unreachable, blocked cross-origin response).
  corsOrProxy,

  /// The upstream response exceeded the size limit the fetcher enforces.
  responseTooLarge,

  /// The fetch succeeded but found no events in range.
  noEventsFound,

  /// The response could not be parsed as the expected format (XML/JSON).
  parserFailure,

  /// The AI organizer was configured but failed or returned unusable JSON.
  aiFailure,

  /// The AI organizer is not configured server-side, so a deterministic
  /// fallback was used instead.
  aiNotConfigured,

  /// The upstream source returned a non-2xx status (403/404/5xx, etc).
  upstreamError,

  /// Cause not determined.
  unknown,
}

class OutsideEventSourceWarning {
  const OutsideEventSourceWarning({
    required this.sourceId,
    required this.sourceName,
    required this.message,
    this.httpStatusCode,
    this.category = OutsideEventFailureCategory.unknown,
  });

  final String sourceId;
  final String sourceName;
  final String message;

  /// HTTP status returned by the fetcher proxy or upstream source, when
  /// known. Null when the failure happened before/without an HTTP response
  /// (e.g. a blocked URL or a client-side network exception).
  final int? httpStatusCode;
  final OutsideEventFailureCategory category;
}

class OutsideEventSourceResult {
  const OutsideEventSourceResult({
    required this.source,
    this.suggestions = const [],
    this.warnings = const [],
    this.attempted = true,
    this.aiConfigured,
  });

  final OutsideEventSourceConfig source;
  final List<EventSuggestion> suggestions;
  final List<OutsideEventSourceWarning> warnings;

  /// Whether [OutsideEventSourceAdapter.fetch] actually ran for this source.
  /// False when the source was skipped (e.g. disabled), so callers tracking
  /// per-source health (see `AppState.refreshOutsideEventSources`) can leave
  /// stale health data alone instead of treating "skipped" as "failed".
  final bool attempted;

  /// Whether the server-side AI organizer was configured for this fetch.
  /// Only [WebPageEventSourceAdapter] reports this (the only source kind
  /// that can use it); null for every other adapter. Since AI configuration
  /// is a single server-side setting, this is the same for every webpage
  /// source in a given deploy - see `AppState.lastWebpageAiConfigured`.
  final bool? aiConfigured;
}

abstract class OutsideEventSourceAdapter {
  OutsideEventSourceConfig get config;

  Future<OutsideEventSourceResult> fetch(OutsideEventQuery query);
}
