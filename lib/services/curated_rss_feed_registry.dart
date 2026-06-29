class CuratedRssFeedSource {
  const CuratedRssFeedSource({
    required this.id,
    required this.displayName,
    required this.url,
    required this.defaultCity,
    this.defaultVenueName,
    this.defaultPriceLabel,
    this.defaultTags = const [],
  });

  final String id;
  final String displayName;
  final String url;
  final String defaultCity;
  final String? defaultVenueName;
  final String? defaultPriceLabel;
  final List<String> defaultTags;
}

const curatedRssFeedSources = <CuratedRssFeedSource>[
  CuratedRssFeedSource(
    id: 'discover-halifax-events',
    displayName: 'Discover Halifax events',
    url: 'https://discoverhalifaxns.com/events/feed/',
    defaultCity: 'Halifax',
    defaultTags: ['tourism', 'community', 'arts/culture'],
  ),
  CuratedRssFeedSource(
    id: 'the-coast-food-drink',
    displayName: 'The Coast food and drink',
    url: 'https://www.thecoast.ca/category/food-drink/feed/',
    defaultCity: 'Halifax',
    defaultTags: ['food', 'community'],
  ),
  CuratedRssFeedSource(
    id: 'halifax-municipal-news',
    displayName: 'Halifax municipal news',
    url: 'https://www.halifax.ca/news/rss-feed',
    defaultCity: 'Halifax',
    defaultVenueName: 'Halifax Regional Municipality',
    defaultTags: ['community', 'municipal'],
  ),
  CuratedRssFeedSource(
    id: 'feed-nova-scotia-events',
    displayName: 'Feed Nova Scotia events',
    url: 'https://feednovascotia.ca/events/feed/',
    defaultCity: 'Halifax',
    defaultTags: ['community', 'food', 'free/low-cost'],
  ),
];
