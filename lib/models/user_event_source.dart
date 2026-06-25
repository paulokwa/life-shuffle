import 'event_suggestion.dart';

enum UserEventSourceKind {
  autoDetect,
  rssAtom,
  webPage,
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
  });

  final String id;
  final String displayName;
  final String url;
  final UserEventSourceKind kind;
  final bool enabled;
  final int? lastFetchedAtMillis;
  final String? lastError;

  OutsideEventSourceType get sourceType => kind.sourceType;

  UserEventSource copyWith({
    String? displayName,
    String? url,
    UserEventSourceKind? kind,
    bool? enabled,
    int? lastFetchedAtMillis,
    String? lastError,
    bool clearLastError = false,
  }) {
    return UserEventSource(
      id: id,
      displayName: displayName ?? this.displayName,
      url: url ?? this.url,
      kind: kind ?? this.kind,
      enabled: enabled ?? this.enabled,
      lastFetchedAtMillis: lastFetchedAtMillis ?? this.lastFetchedAtMillis,
      lastError: clearLastError ? null : lastError ?? this.lastError,
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
    };
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
