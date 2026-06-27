import 'activity.dart';
import 'day_plan.dart';
import 'manual_plan_item.dart';

enum OutsideEventSourceType {
  rssAtom,
  webPage,
  ticketmaster,
  eventbrite,
  bandsintown,
  mock,
  ai,
}

extension OutsideEventSourceTypeLabel on OutsideEventSourceType {
  String get label => switch (this) {
        OutsideEventSourceType.rssAtom => 'RSS/Atom',
        OutsideEventSourceType.webPage => 'Web page',
        OutsideEventSourceType.ticketmaster => 'Ticketmaster',
        OutsideEventSourceType.eventbrite => 'Eventbrite',
        OutsideEventSourceType.bandsintown => 'Bandsintown',
        OutsideEventSourceType.mock => 'Sample',
        OutsideEventSourceType.ai => 'AI organizer',
      };

  String get storageName => name;

  static OutsideEventSourceType fromStorage(String? value) {
    return OutsideEventSourceType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => OutsideEventSourceType.mock,
    );
  }
}

class EventSuggestion {
  const EventSuggestion({
    required this.id,
    required this.title,
    required this.startDateTime,
    required this.sourceName,
    required this.sourceType,
    required this.dedupeKey,
    this.cleanedTitle,
    this.description,
    this.summary,
    this.endDateTime,
    this.durationMinutes,
    this.venueName,
    this.address,
    this.city,
    this.sourceUrl,
    this.ticketUrl,
    this.priceLabel,
    this.isFree,
    this.tags = const [],
    this.imageUrl,
    this.confidence,
    this.missingFields = const [],
    this.raw = const {},
    this.sourceId,
  });

  final String id;
  final String title;
  final String? cleanedTitle;
  final String? description;
  final String? summary;
  final DateTime startDateTime;
  final DateTime? endDateTime;
  final int? durationMinutes;
  final String? venueName;
  final String? address;
  final String? city;
  final String sourceName;
  final OutsideEventSourceType sourceType;

  /// The exact [OutsideEventSourceConfig.id] that produced this event, e.g.
  /// a specific user-added source's id rather than its (possibly shared)
  /// [sourceType]. Several user sources can share a [sourceType] (RSS/Atom
  /// or web page), so this is what Outside Events' source filter pills
  /// match on. Null for events built before this field existed (old cached
  /// data) or fixtures that don't set it; [contributingSourceIds] falls back
  /// to [sourceType] in that case.
  final String? sourceId;
  final String? sourceUrl;
  final String? ticketUrl;
  final String? priceLabel;
  final bool? isFree;
  final List<String> tags;
  final String? imageUrl;
  final double? confidence;
  final List<String> missingFields;
  final Map<String, Object?> raw;
  final String dedupeKey;

  String get displayTitle {
    final cleaned = cleanedTitle?.trim();
    return cleaned == null || cleaned.isEmpty ? title.trim() : cleaned;
  }

  String get displaySummary {
    final value = summary?.trim();
    if (value != null && value.isNotEmpty) return value;
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return 'Details are limited. Open the source before you go.';
  }

  String get displayLocation {
    final parts = [
      if (venueName?.trim().isNotEmpty == true) venueName!.trim(),
      if (city?.trim().isNotEmpty == true) city!.trim(),
    ];
    return parts.isEmpty ? 'Location unknown' : parts.join(' / ');
  }

  String get displayPrice {
    if (priceLabel?.trim().isNotEmpty == true) return priceLabel!.trim();
    if (isFree == true) return 'Free';
    return 'Price unknown';
  }

  String get category {
    final lowerTags = tags.map((tag) => tag.toLowerCase()).toSet();
    if (lowerTags.any((tag) => tag.contains('music'))) return 'Creative';
    if (lowerTags.any((tag) => tag.contains('food'))) return 'Food';
    if (lowerTags.any((tag) => tag.contains('outdoor'))) return 'Outside';
    if (lowerTags.any((tag) => tag.contains('market'))) return 'Outside';
    if (lowerTags.any((tag) => tag.contains('community'))) return 'Social';
    if (lowerTags.any((tag) => tag.contains('family'))) return 'Social';
    return 'Outside';
  }

  int get plannedDurationMinutes {
    final explicit = durationMinutes;
    if (explicit != null && explicit > 0) {
      return explicit.clamp(15, 720).toInt();
    }
    final end = endDateTime;
    if (end != null && end.isAfter(startDateTime)) {
      return end.difference(startDateTime).inMinutes.clamp(15, 720).toInt();
    }
    return 90;
  }

  EventSuggestion copyWith({
    String? cleanedTitle,
    String? description,
    String? summary,
    List<String>? tags,
    List<String>? missingFields,
    double? confidence,
    String? priceLabel,
    bool? isFree,
    String? venueName,
    String? address,
    String? city,
    String? sourceUrl,
    String? ticketUrl,
    Map<String, Object?>? raw,
    String? sourceId,
  }) {
    return EventSuggestion(
      id: id,
      title: title,
      cleanedTitle: cleanedTitle ?? this.cleanedTitle,
      description: description ?? this.description,
      summary: summary ?? this.summary,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      durationMinutes: durationMinutes,
      venueName: venueName ?? this.venueName,
      address: address ?? this.address,
      city: city ?? this.city,
      sourceName: sourceName,
      sourceType: sourceType,
      sourceId: sourceId ?? this.sourceId,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      ticketUrl: ticketUrl ?? this.ticketUrl,
      priceLabel: priceLabel ?? this.priceLabel,
      isFree: isFree ?? this.isFree,
      tags: tags ?? this.tags,
      imageUrl: imageUrl,
      confidence: confidence ?? this.confidence,
      missingFields: missingFields ?? this.missingFields,
      raw: raw ?? this.raw,
      dedupeKey: dedupeKey,
    );
  }

  /// Other sources that turned out to describe this same event, attached by
  /// [EventDedupeService] when it merges near-duplicates. Each entry has at
  /// least a `sourceName`, and a `sourceType`/`sourceUrl`/`sourceId` when
  /// known.
  List<Map<String, Object?>> get mergedSources {
    final value = raw['mergedSources'];
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((map) => Map<String, Object?>.from(map))
        .toList();
  }

  /// Every source id this event can be filtered by: its own [sourceId]
  /// (falling back to [sourceType] when unset) plus any contributed by
  /// [mergedSources], so an event merged from several sources matches a
  /// filter pill for *any* of them, not just whichever "won" the merge.
  Set<String> get contributingSourceIds => {
        sourceId ?? sourceType.storageName,
        for (final source in mergedSources)
          if (source['sourceId'] is String) source['sourceId'] as String,
      };

  /// `sourceName`, plus any [mergedSources] names, joined for display so a
  /// merged event credits every source that reported it (e.g. "Venue page +
  /// Ticketmaster") instead of only the first one found.
  String get displaySourceSummary {
    final names = <String>{
      sourceName,
      for (final source in mergedSources)
        if (source['sourceName'] is String) source['sourceName'] as String,
    };
    return names.join(' + ');
  }

  /// How this event was produced, e.g. `ai-openai-webpage` or
  /// `deterministic-webpage-fallback`. Null for sources that don't tag it
  /// (RSS/Atom, mock, ticketing APIs).
  String? get extractionMode => raw['extractionMode'] as String?;

  /// Whether an AI provider (vs. deterministic regex extraction) organized
  /// this event from its source webpage.
  bool get isAiOrganized => extractionMode?.startsWith('ai-') == true;

  ManualPlanItem toManualPlanItem({String? id}) {
    return ManualPlanItem(
      id: id ?? 'outside_${DateTime.now().microsecondsSinceEpoch}',
      dateKey: DayPlan.dateKey(startDateTime),
      title: displayTitle,
      timeSlot: _formatTime(startDateTime),
      category: Activity.categories.contains(category) ? category : 'Outside',
      durationMinutes: plannedDurationMinutes,
      difficulty: 3,
      energy: 'medium',
      social: 'either',
      outsideEventId: this.id,
      outsideEventSourceName: displaySourceSummary,
      outsideEventSourceUrl: sourceUrl,
      outsideEventTicketUrl: ticketUrl,
      outsideEventPriceLabel: displayPrice,
      outsideEventVenueName: venueName,
      outsideEventAddress: address,
      outsideEventSummary: displaySummary,
      outsideEventSourceType: sourceType.storageName,
      outsideEventConfidence: confidence,
      outsideEventTags: tags,
      outsideEventUncertainFields: missingFields,
      outsideEventExtractionMode: extractionMode,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (cleanedTitle != null) 'cleanedTitle': cleanedTitle,
      if (description != null) 'description': description,
      if (summary != null) 'summary': summary,
      'startDateTimeMillis': startDateTime.millisecondsSinceEpoch,
      if (endDateTime != null)
        'endDateTimeMillis': endDateTime!.millisecondsSinceEpoch,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (venueName != null) 'venueName': venueName,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      'sourceName': sourceName,
      'sourceType': sourceType.storageName,
      if (sourceId != null) 'sourceId': sourceId,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (ticketUrl != null) 'ticketUrl': ticketUrl,
      if (priceLabel != null) 'priceLabel': priceLabel,
      if (isFree != null) 'isFree': isFree,
      'tags': tags,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (confidence != null) 'confidence': confidence,
      'missingFields': missingFields,
      'raw': raw,
      'dedupeKey': dedupeKey,
    };
  }

  factory EventSuggestion.fromMap(Map<String, dynamic> map) {
    final startMillis = _readInt(map['startDateTimeMillis']);
    final start = startMillis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(startMillis);
    final endMillis = _readInt(map['endDateTimeMillis']);
    return EventSuggestion(
      id: _readString(map['id'],
          fallback: 'event-${start.microsecondsSinceEpoch}'),
      title: _readString(map['title'], fallback: 'Untitled event'),
      cleanedTitle: _readNullableString(map['cleanedTitle']),
      description: _readNullableString(map['description']),
      summary: _readNullableString(map['summary']),
      startDateTime: start,
      endDateTime: endMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(endMillis),
      durationMinutes: _readInt(map['durationMinutes']),
      venueName: _readNullableString(map['venueName']),
      address: _readNullableString(map['address']),
      city: _readNullableString(map['city']),
      sourceName: _readString(map['sourceName'], fallback: 'Outside event'),
      sourceType: OutsideEventSourceTypeLabel.fromStorage(
        map['sourceType'] as String?,
      ),
      sourceId: _readNullableString(map['sourceId']),
      sourceUrl: _readNullableString(map['sourceUrl']),
      ticketUrl: _readNullableString(map['ticketUrl']),
      priceLabel: _readNullableString(map['priceLabel']),
      isFree: map['isFree'] is bool ? map['isFree'] as bool : null,
      tags: _readStringList(map['tags']),
      imageUrl: _readNullableString(map['imageUrl']),
      confidence: _readDouble(map['confidence']),
      missingFields: _readStringList(map['missingFields']),
      raw: map['raw'] is Map
          ? Map<String, Object?>.from(map['raw'] as Map)
          : const {},
      dedupeKey: _readString(
        map['dedupeKey'],
        fallback: eventDedupeKey(
          title: _readString(map['title'], fallback: 'Untitled event'),
          start: start,
          venueName: _readNullableString(map['venueName']),
        ),
      ),
    );
  }

  static String _formatTime(DateTime value) {
    final hour = value.hour;
    final minute = value.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
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
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

double? _readDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return null;
}

List<String> _readStringList(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String eventDedupeKey({
  required String title,
  required DateTime start,
  String? venueName,
}) {
  final normalizedTitle = title.trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        ' ',
      );
  final normalizedVenue = (venueName ?? '').trim().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]+'),
        ' ',
      );
  return [
    normalizedTitle.trim(),
    DayPlan.dateKey(start),
    start.hour.toString().padLeft(2, '0'),
    start.minute.toString().padLeft(2, '0'),
    normalizedVenue.trim(),
  ].join('|');
}
