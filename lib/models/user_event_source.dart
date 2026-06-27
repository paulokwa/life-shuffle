import 'event_suggestion.dart';

enum UserEventSourceKind {
  autoDetect,
  rssAtom,
  webPage,
}

/// Coarse health signal for a [UserEventSource], derived from its last
/// refresh attempt rather than stored directly, so it can never drift out
/// of sync with [UserEventSource.lastAttemptedAtMillis]/`lastError`.
enum SourceHealthStatus {
  /// Never attempted yet (added but no refresh has run since).
  unknown,

  /// Last attempt succeeded with no warning.
  healthy,

  /// Last attempt produced a warning but still found events.
  warning,

  /// Last attempt produced a warning and found no events.
  failed,
}

extension SourceHealthStatusLabel on SourceHealthStatus {
  String get label => switch (this) {
        SourceHealthStatus.unknown => 'Not checked yet',
        SourceHealthStatus.healthy => 'Healthy',
        SourceHealthStatus.warning => 'Warning',
        SourceHealthStatus.failed => 'Failed',
      };
}

extension UserEventSourceKindLabel on UserEventSourceKind {
  String get label => switch (this) {
        UserEventSourceKind.autoDetect => 'Auto-detect',
        UserEventSourceKind.rssAtom => 'RSS/Atom',
        UserEventSourceKind.webPage => 'Web page',
      };

  OutsideEventSourceType get sourceType => switch (this) {
        UserEventSourceKind.autoDetect => OutsideEventSourceType.webPage,
        UserEventSourceKind.rssAtom => OutsideEventSourceType.rssAtom,
        UserEventSourceKind.webPage => OutsideEventSourceType.webPage,
      };

  static UserEventSourceKind fromStorage(String? value) {
    return UserEventSourceKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => UserEventSourceKind.autoDetect,
    );
  }
}

class UserEventSource {
  const UserEventSource({
    required this.id,
    required this.displayName,
    required this.url,
    required this.kind,
    this.enabled = true,
    this.lastFetchedAtMillis,
    this.lastError,
    this.lastSuccessAtMillis,
    this.lastEventCount,
    this.lastErrorCategory,
    this.lastErrorHttpStatusCode,
  });

  final String id;
  final String displayName;
  final String url;
  final UserEventSourceKind kind;
  final bool enabled;

  /// Millis of the last refresh that actually attempted this source (i.e.
  /// the source was enabled when a refresh ran). Null means never attempted.
  final int? lastFetchedAtMillis;
  final String? lastError;

  /// Millis of the last attempt that completed without a warning. Null
  /// means the source has never succeeded.
  final int? lastSuccessAtMillis;

  /// Number of events this source returned on its last attempt (before
  /// cross-source dedupe), so Settings can show "events found" even when
  /// the source also reported a warning.
  final int? lastEventCount;

  /// `OutsideEventFailureCategory.name` for the most recent [lastError],
  /// e.g. `"timeout"` or `"responseTooLarge"`. Stored as a plain string
  /// (rather than the enum itself) so this model file - synced through
  /// [SavedState] - doesn't need to import the services-layer adapter file
  /// that defines the enum. See Settings diagnostics for where this is
  /// mapped back to a label.
  final String? lastErrorCategory;

  /// HTTP status returned by the fetcher proxy or upstream source for
  /// [lastError], when known.
  final int? lastErrorHttpStatusCode;

  OutsideEventSourceType get sourceType => kind.sourceType;

  /// Coarse health derived from the fields above. See [SourceHealthStatus].
  SourceHealthStatus get healthStatus {
    if (lastFetchedAtMillis == null) return SourceHealthStatus.unknown;
    final hasWarning = lastError?.trim().isNotEmpty == true;
    if (!hasWarning) return SourceHealthStatus.healthy;
    return (lastEventCount ?? 0) > 0
        ? SourceHealthStatus.warning
        : SourceHealthStatus.failed;
  }

  UserEventSource copyWith({
    String? displayName,
    String? url,
    UserEventSourceKind? kind,
    bool? enabled,
    int? lastFetchedAtMillis,
    String? lastError,
    bool clearLastError = false,
    int? lastSuccessAtMillis,
    int? lastEventCount,
    String? lastErrorCategory,
    bool clearLastErrorCategory = false,
    int? lastErrorHttpStatusCode,
    bool clearLastErrorHttpStatusCode = false,
  }) {
    return UserEventSource(
      id: id,
      displayName: displayName ?? this.displayName,
      url: url ?? this.url,
      kind: kind ?? this.kind,
      enabled: enabled ?? this.enabled,
      lastFetchedAtMillis: lastFetchedAtMillis ?? this.lastFetchedAtMillis,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      lastSuccessAtMillis: lastSuccessAtMillis ?? this.lastSuccessAtMillis,
      lastEventCount: lastEventCount ?? this.lastEventCount,
      lastErrorCategory: clearLastErrorCategory
          ? null
          : lastErrorCategory ?? this.lastErrorCategory,
      lastErrorHttpStatusCode: clearLastErrorHttpStatusCode
          ? null
          : lastErrorHttpStatusCode ?? this.lastErrorHttpStatusCode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'url': url,
      'kind': kind.name,
      'enabled': enabled,
      'lastFetchedAtMillis': lastFetchedAtMillis,
      'lastError': lastError,
      'lastSuccessAtMillis': lastSuccessAtMillis,
      'lastEventCount': lastEventCount,
      'lastErrorCategory': lastErrorCategory,
      'lastErrorHttpStatusCode': lastErrorHttpStatusCode,
    };
  }

  /// Just the fields a person could usefully share or re-import: display
  /// name, URL, kind, and enabled status. Deliberately excludes [id]
  /// (calendar-local) and every health/diagnostic field (`lastError`,
  /// `lastEventCount`, etc. - device-local fetch history, not part of the
  /// source's definition) so exporting never leaks more than the source
  /// definition itself. See Settings' source list export/import.
  Map<String, dynamic> toExportMap() {
    return {
      'displayName': displayName,
      'url': url,
      'kind': kind.name,
      'enabled': enabled,
    };
  }

  /// Parses one entry from an exported source-list JSON paste (see
  /// [toExportMap]). The returned source's [id] is a placeholder - callers
  /// that persist an import (see `AppState.importOutsideEventSources`)
  /// replace it with a freshly generated one. Throws [FormatException] if
  /// `url` is missing or blank, since a source with no URL can never fetch.
  factory UserEventSource.fromExportMap(Map<String, dynamic> map) {
    final url = _readString(map['url'], fallback: '');
    if (url.isEmpty) {
      throw const FormatException('Missing or empty "url" field.');
    }
    return UserEventSource(
      id: 'import-placeholder',
      displayName: _readString(map['displayName'], fallback: url),
      url: url,
      kind: UserEventSourceKindLabel.fromStorage(map['kind'] as String?),
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
    );
  }

  factory UserEventSource.fromMap(Map<String, dynamic> map) {
    return UserEventSource(
      id: _readString(map['id'],
          fallback: 'src-${DateTime.now().microsecondsSinceEpoch}'),
      displayName: _readString(map['displayName'], fallback: 'Event source'),
      url: _readString(map['url'], fallback: ''),
      kind: UserEventSourceKindLabel.fromStorage(map['kind'] as String?),
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
      lastFetchedAtMillis: _readInt(map['lastFetchedAtMillis']),
      lastError: _readNullableString(map['lastError']),
      lastSuccessAtMillis: _readInt(map['lastSuccessAtMillis']),
      lastEventCount: _readInt(map['lastEventCount']),
      lastErrorCategory: _readNullableString(map['lastErrorCategory']),
      lastErrorHttpStatusCode: _readInt(map['lastErrorHttpStatusCode']),
    );
  }
}

String _readString(Object? value, {required String fallback}) {
  if (value is! String) return fallback;
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

String? _readNullableString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _readInt(Object? value) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  return null;
}
