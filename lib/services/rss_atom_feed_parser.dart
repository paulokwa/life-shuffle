import 'package:xml/xml.dart';

import '../models/event_suggestion.dart';
import 'curated_rss_feed_registry.dart';
import 'outside_event_source_adapter.dart';

class ParsedRssAtomFeed {
  const ParsedRssAtomFeed({
    required this.suggestions,
    required this.warnings,
  });

  final List<EventSuggestion> suggestions;
  final List<OutsideEventSourceWarning> warnings;
}

class RssAtomFeedParser {
  const RssAtomFeedParser();

  ParsedRssAtomFeed parse({
    required String xmlText,
    required CuratedRssFeedSource source,
    required OutsideEventQuery query,
  }) {
    final document = XmlDocument.parse(xmlText);
    final items = _feedItems(document);
    final suggestions = <EventSuggestion>[];
    var skipped = 0;

    for (final item in items) {
      final parsed = _parseItem(item, source, query);
      if (parsed == null) {
        skipped++;
        continue;
      }
      if (query.contains(parsed.startDateTime)) {
        suggestions.add(parsed);
      }
    }

    return ParsedRssAtomFeed(
      suggestions: suggestions,
      warnings: [
        if (items.isEmpty)
          OutsideEventSourceWarning(
            sourceId: source.id,
            sourceName: source.displayName,
            message: 'Feed loaded but did not contain any RSS/Atom entries.',
          ),
        if (skipped > 0)
          OutsideEventSourceWarning(
            sourceId: source.id,
            sourceName: source.displayName,
            message: '$skipped feed entr${skipped == 1 ? 'y was' : 'ies were'} '
                'missing enough title/date data to show.',
          ),
      ],
    );
  }

  List<XmlElement> _feedItems(XmlDocument document) {
    final rssItems = document.findAllElements('item').toList();
    if (rssItems.isNotEmpty) return rssItems;
    return document.findAllElements('entry').toList();
  }

  EventSuggestion? _parseItem(
    XmlElement item,
    CuratedRssFeedSource source,
    OutsideEventQuery query,
  ) {
    final title = _text(item, 'title');
    if (title == null || title.isEmpty) return null;

    final description = _text(item, 'description') ??
        _text(item, 'summary') ??
        _text(item, 'content') ??
        _text(item, 'encoded');
    final link = _link(item);
    final dateText = [
      _text(item, 'start_date'),
      _text(item, 'startdate'),
      _text(item, 'dtstart'),
      _text(item, 'event_date'),
      _text(item, 'date'),
      _text(item, 'pubDate'),
      _text(item, 'published'),
      _text(item, 'updated'),
    ].whereType<String>().firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => '',
        );
    final textDate = _parseTextDate(
      [title, description ?? ''].join(' '),
      query.start.year,
    );
    final feedDate = _parseFeedDate(dateText);
    final start = textDate ?? feedDate;
    if (start == null) return null;

    final venueName = _text(item, 'venue') ??
        _text(item, 'location') ??
        source.defaultVenueName;
    final address = _text(item, 'address');
    final priceLabel = source.defaultPriceLabel;
    final idSeed = _text(item, 'guid') ?? link ?? '${source.id}-$title-$start';
    final missingFields = <String>[
      if (textDate == null) 'event date',
      if (venueName == null || venueName.trim().isEmpty) 'venue',
      if (address == null || address.trim().isEmpty) 'address',
      if (priceLabel == null || priceLabel.trim().isEmpty) 'price',
    ];

    return EventSuggestion(
      id: '${source.id}-${_stableId(idSeed)}',
      title: title,
      cleanedTitle: _cleanTitle(title),
      description: description,
      startDateTime: start,
      venueName: venueName,
      address: address,
      city: query.city.trim().isEmpty ? source.defaultCity : query.city,
      sourceName: source.displayName,
      sourceType: OutsideEventSourceType.rssAtom,
      sourceUrl: link ?? source.url,
      priceLabel: priceLabel,
      tags: source.defaultTags,
      missingFields: missingFields,
      raw: {
        'feedSourceId': source.id,
        'feedUrl': source.url,
        if (dateText.isNotEmpty) 'dateText': dateText,
      },
      dedupeKey: eventDedupeKey(
        title: title,
        start: start,
        venueName: venueName,
      ),
    );
  }

  String? _text(XmlElement item, String localName) {
    for (final element in item.descendants.whereType<XmlElement>()) {
      if (element.name.local.toLowerCase() == localName.toLowerCase()) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  String? _link(XmlElement item) {
    final linkText = _text(item, 'link');
    if (linkText != null && linkText.isNotEmpty) return linkText;
    for (final element in item.findElements('link')) {
      final href = element.getAttribute('href')?.trim();
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
  }

  DateTime? _parseFeedDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final iso = DateTime.tryParse(trimmed);
    if (iso != null) return iso.toLocal();

    final match = RegExp(
      r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
      r'(\d{1,2}):(\d{2})(?::(\d{2}))?',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match == null) return null;
    final month = _shortMonth(match.group(2)!);
    if (month == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      month,
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.tryParse(match.group(6) ?? '0') ?? 0,
    );
  }

  DateTime? _parseTextDate(String value, int defaultYear) {
    final match = RegExp(
      '\\b($_monthNamesPattern)\\s+(\\d{1,2})(?:st|nd|rd|th)?'
      '(?:,?\\s+(\\d{4}))?'
      '(?:\\s+(?:at\\s+)?(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm))?',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    final month = _month(match.group(1)!);
    if (month == null) return null;
    final year = int.tryParse(match.group(3) ?? '') ?? defaultYear;
    var hour = int.tryParse(match.group(4) ?? '12') ?? 12;
    final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
    final period = match.group(6)?.toLowerCase();
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    return DateTime(year, month, int.parse(match.group(2)!), hour, minute);
  }

  String _cleanTitle(String value) {
    return value
        .replaceAll(
          RegExp(
            '\\s+($_monthNamesPattern)\\s+\\d{1,2}(?:st|nd|rd|th)?'
            '(?:,?\\s+\\d{4})?'
            '(?:\\s+(?:at\\s+)?\\d{1,2}(?::\\d{2})?\\s*(?:am|pm))?.*\$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int? _shortMonth(String value) {
    return _month(value.substring(0, value.length.clamp(0, 3).toInt()));
  }

  int? _month(String value) {
    return _months[value.toLowerCase().substring(0, 3)];
  }

  String _stableId(String value) {
    final normalized = value.trim().toLowerCase();
    final hash = normalized.codeUnits.fold<int>(
      0,
      (previous, code) => (previous * 31 + code) & 0x7fffffff,
    );
    return hash.toRadixString(16);
  }
}

const _monthNamesPattern =
    'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|'
    'jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|'
    'dec(?:ember)?';

const _months = <String, int>{
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};
