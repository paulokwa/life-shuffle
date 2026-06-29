import 'user_event_source.dart';

/// A dated, restorable copy of the user's outside-event source configuration.
///
/// Health data is deliberately omitted when a snapshot is created. It
/// describes a fetch attempt, not the source configuration being backed up.
class SourceListSnapshot {
  const SourceListSnapshot({
    required this.id,
    required this.createdAtMillis,
    required this.sources,
  });

  final String id;
  final int createdAtMillis;
  final List<UserEventSource> sources;

  factory SourceListSnapshot.capture({
    required int createdAtMillis,
    required List<UserEventSource> sources,
  }) {
    return SourceListSnapshot(
      id: 'source_snapshot_$createdAtMillis',
      createdAtMillis: createdAtMillis,
      sources: sources.map(_configurationOnlyCopy).toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'createdAtMillis': createdAtMillis,
        'sources': sources.map((source) => source.toMap()).toList(),
      };

  factory SourceListSnapshot.fromMap(Map<String, dynamic> map) {
    final createdAtMillis = _readPositiveInt(map['createdAtMillis']);
    final sourcesValue = map['sources'];
    final sources = sourcesValue is Iterable
        ? sourcesValue
            .whereType<Map>()
            .map((value) => UserEventSource.fromMap(
                  Map<String, dynamic>.from(value),
                ))
            .where((source) => source.url.trim().isNotEmpty)
            .map(_configurationOnlyCopy)
            .toList(growable: false)
        : const <UserEventSource>[];
    final storedId = map['id'];
    return SourceListSnapshot(
      id: storedId is String && storedId.trim().isNotEmpty
          ? storedId.trim()
          : 'source_snapshot_$createdAtMillis',
      createdAtMillis: createdAtMillis,
      sources: sources,
    );
  }

  static UserEventSource _configurationOnlyCopy(UserEventSource source) {
    return UserEventSource(
      id: source.id,
      displayName: source.displayName,
      url: source.url,
      kind: source.kind,
      enabled: source.enabled,
    );
  }

  static int _readPositiveInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return 1;
  }
}
