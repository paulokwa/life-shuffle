import '../models/event_suggestion.dart';

class OutsideEventOrganizerService {
  const OutsideEventOrganizerService();

  static const bool aiConfigured = bool.fromEnvironment(
    'OUTSIDE_EVENTS_AI_ORGANIZER',
  );

  EventSuggestion organize(EventSuggestion event) {
    final cleanedTitle = _cleanTitle(event.cleanedTitle ?? event.title);
    final cleanDescription = _stripHtml(event.description ?? '');
    final summary = _summary(event.summary, cleanDescription);
    final tags = _inferTags(
      [cleanedTitle, cleanDescription, ...event.tags].join(' '),
      existing: event.tags,
    );
    final missing = <String>{
      ...event.missingFields,
      if (event.venueName == null || event.venueName!.trim().isEmpty) 'venue',
      if (event.priceLabel == null && event.isFree == null) 'price',
      if (event.address == null || event.address!.trim().isEmpty) 'address',
    }.toList()..sort();

    return event.copyWith(
      cleanedTitle: cleanedTitle,
      description: cleanDescription.isEmpty
          ? event.description
          : cleanDescription,
      summary: summary,
      tags: tags,
      missingFields: missing,
      confidence: event.confidence ?? 0.78,
      priceLabel: event.priceLabel,
      isFree: event.isFree,
    );
  }

  String get aiStatusMessage {
    if (aiConfigured) {
      return 'AI organizer seam is enabled, but live calls should route '
          'through a backend function before production use.';
    }
    return 'Using deterministic cleanup. AI can later summarize, classify, '
        'dedupe, extract, and rank without becoming the source of truth.';
  }

  static String _stripHtml(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;|&#160;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _cleanTitle(String value) {
    final stripped = _stripHtml(value);
    return stripped
        .replaceAll(
          RegExp(r'\s*[-|]\s*(event|tickets?|halifax)$', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _summary(String? existing, String description) {
    final cleanedExisting = _stripHtml(existing ?? '');
    if (cleanedExisting.isNotEmpty) return _limit(cleanedExisting, 150);
    if (description.isEmpty) {
      return 'Details are limited. Open the source before you go.';
    }
    return _limit(description, 150);
  }

  static List<String> _inferTags(
    String text, {
    required List<String> existing,
  }) {
    final lower = text.toLowerCase();
    final tags = <String>{
      ...existing.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
    };
    void addIf(RegExp pattern, String tag) {
      if (pattern.hasMatch(lower)) tags.add(tag);
    }

    addIf(RegExp(r'\bmusic|song|concert|band|acoustic|dj\b'), 'music');
    addIf(RegExp(r'\bmarket|maker|vendor|craft\b'), 'market');
    addIf(RegExp(r'\bwalk|garden|park|trail|outdoor|waterfront\b'), 'outdoors');
    addIf(
      RegExp(r'\bart|film|gallery|museum|culture|ceramic\b'),
      'arts/culture',
    );
    addIf(RegExp(r'\bcommunity|neighbourhood|library\b'), 'community');
    addIf(RegExp(r'\bfree|no cost|pay what you can\b'), 'free/low-cost');
    addIf(RegExp(r'\bfood|dinner|coffee|cafe|vendor\b'), 'food');
    addIf(RegExp(r'\bfamily|kids|couple|date night\b'), 'couple-friendly');
    final sorted = tags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static String _limit(String value, int max) {
    if (value.length <= max) return value;
    final clipped = value.substring(0, max).trimRight();
    final lastSpace = clipped.lastIndexOf(' ');
    if (lastSpace > 80) return '${clipped.substring(0, lastSpace)}...';
    return '$clipped...';
  }
}
