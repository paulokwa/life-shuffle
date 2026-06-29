'use strict';

const crypto = require('node:crypto');
const dns = require('node:dns/promises');
const net = require('node:net');

const MAX_BYTES = 1024 * 1024;
const TIMEOUT_MS = 10000;
const AI_TIMEOUT_MS = 20000;
const AI_CHUNK_SIZE = 6000;
const AI_MAX_CHUNKS = 4;
const DEFAULT_OPENAI_MODEL = 'gpt-4o-mini';
const DEFAULT_GEMINI_MODEL = 'gemini-1.5-flash';

function jsonResponse(statusCode, payload, extraHeaders) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', ...(extraHeaders || {}) },
    body: JSON.stringify(payload),
  };
}

function methodNotAllowedResponse() {
  return jsonResponse(405, { error: 'method_not_allowed' }, { Allow: 'GET' });
}

function badRequestResponse(error) {
  return jsonResponse(400, { error: error || 'invalid_request' });
}

function upstreamErrorResponse(error) {
  return jsonResponse(502, { error: error || 'page_unavailable' });
}

function readParam(query, name, fallback) {
  const value = query && query[name];
  if (typeof value !== 'string') return fallback || null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? fallback || null : trimmed;
}

function isPrivateIp(address) {
  if (!address) return true;
  if (address === '::1' || address.startsWith('fe80:')) return true;
  if (address.startsWith('fc') || address.startsWith('fd')) return true;
  if (net.isIPv4(address)) {
    const parts = address.split('.').map((part) => Number.parseInt(part, 10));
    const [a, b] = parts;
    return (
      a === 10 ||
      a === 127 ||
      (a === 169 && b === 254) ||
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      a === 0
    );
  }
  return false;
}

async function assertPublicUrl(rawUrl, lookupImpl = dns.lookup) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch (_) {
    throw new Error('invalid_url');
  }
  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('invalid_protocol');
  }
  const host = parsed.hostname.toLowerCase();
  if (
    host === 'localhost' ||
    host.endsWith('.localhost') ||
    host.endsWith('.local')
  ) {
    throw new Error('private_url');
  }
  if (net.isIP(host) && isPrivateIp(host)) throw new Error('private_url');
  const records = await lookupImpl(host, { all: true });
  if (!Array.isArray(records) || records.length === 0) {
    throw new Error('dns_failed');
  }
  if (records.some((record) => isPrivateIp(record.address))) {
    throw new Error('private_url');
  }
  return parsed;
}

async function readLimitedText(response) {
  const headers = response.headers;
  const declared =
    headers && typeof headers.get === 'function'
      ? Number.parseInt(headers.get('content-length') || '0', 10)
      : 0;
  if (declared > MAX_BYTES) throw new Error('response_too_large');
  if (!response.body || typeof response.body.getReader !== 'function') {
    const text = await response.text();
    if (Buffer.byteLength(text, 'utf8') > MAX_BYTES) {
      throw new Error('response_too_large');
    }
    return text;
  }
  const reader = response.body.getReader();
  const chunks = [];
  let received = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    received += value.byteLength;
    if (received > MAX_BYTES) throw new Error('response_too_large');
    chunks.push(Buffer.from(value));
  }
  return Buffer.concat(chunks).toString('utf8');
}

async function fetchText(url, fetchImpl, headers) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: { 'User-Agent': 'LifeShuffleOutsideEvents/1.0', ...headers },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Page returned ${response.status}`);
    return await readLimitedText(response);
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchPage(url, fetchImpl) {
  return fetchText(url, fetchImpl, {
    Accept: 'text/html, application/xhtml+xml, text/plain;q=0.9, */*;q=0.5',
  });
}

// ---- Same-domain pagination -----------------------------------------------
//
// Some listing pages spread events across several pages with an obvious
// "next page" link (e.g. `?page=2`). This follows that link generically -
// no site-specific code - by diffing each candidate link's query string
// against the current page's URL: if exactly one parameter differs and that
// difference is a numeric +1, it is treated as the next page. Same-origin
// and same-path only; capped at MAX_ADDITIONAL_PAGES and an overall time
// budget so a single user-initiated fetch can't run away.

const MAX_ADDITIONAL_PAGES = 4;
const PAGINATION_DEADLINE_MS = 15000;

function diffSearchParams(a, b) {
  const keys = new Set([...a.searchParams.keys(), ...b.searchParams.keys()]);
  let changedKey = null;
  for (const key of keys) {
    if (a.searchParams.get(key) !== b.searchParams.get(key)) {
      if (changedKey !== null) return null;
      changedKey = key;
    }
  }
  if (changedKey === null) return null;
  const aNum = Number.parseInt(a.searchParams.get(changedKey), 10);
  const bNum = Number.parseInt(b.searchParams.get(changedKey), 10);
  if (!Number.isFinite(bNum)) return null;
  const aVal = Number.isFinite(aNum) ? aNum : 1;
  return bNum - aVal;
}

function findNextPageUrl(html, currentPageUrl) {
  let current;
  try {
    current = new URL(currentPageUrl);
  } catch (_) {
    return null;
  }
  const anchorPattern = /<a\s[^>]*href=["']([^"']+)["']/gi;
  let match;
  while ((match = anchorPattern.exec(html))) {
    let candidate;
    try {
      candidate = new URL(match[1].replace(/&amp;/g, '&'), currentPageUrl);
    } catch (_) {
      continue;
    }
    if (candidate.origin !== current.origin) continue;
    if (candidate.pathname !== current.pathname) continue;
    if (diffSearchParams(current, candidate) === 1) return candidate.href;
  }
  return null;
}

async function fetchPaginatedPages({
  firstUrl,
  firstHtml,
  fetchImpl,
  maxAdditionalPages = MAX_ADDITIONAL_PAGES,
  deadlineMs = PAGINATION_DEADLINE_MS,
}) {
  const startedAt = Date.now();
  const pages = [{ url: firstUrl, html: firstHtml }];
  const visited = new Set([firstUrl]);
  let currentUrl = firstUrl;
  let currentHtml = firstHtml;
  while (pages.length <= maxAdditionalPages) {
    if (Date.now() - startedAt > deadlineMs) break;
    const nextUrl = findNextPageUrl(currentHtml, currentUrl);
    if (!nextUrl || visited.has(nextUrl)) break;
    visited.add(nextUrl);
    let nextHtml;
    try {
      nextHtml = await fetchPage(nextUrl, fetchImpl);
    } catch (_) {
      break;
    }
    pages.push({ url: nextUrl, html: nextHtml });
    currentUrl = nextUrl;
    currentHtml = nextHtml;
  }
  return pages;
}

// ---- Known-source resolvers ----------------------------------------------
//
// Some sites (e.g. JS-heavy event calendars) return unusable static HTML, but
// expose the same data through an underlying web API. A resolver lets a known
// source bypass the generic page fetch and pull that data directly, without
// the main handler needing to know about any specific site.

const NSCC_EVENT_PATH_PATTERN = /nscc\.ca\/alumni\/get-involved\/events\/eventdetails\.aspx/i;
const NSCC_EVENT_ID_PATTERN = /eventid=(\d+)/i;

const nsccResolver = {
  id: 'nscc',
  matches(url) {
    return NSCC_EVENT_PATH_PATTERN.test(url) && NSCC_EVENT_ID_PATTERN.test(url);
  },
  async fetchContent(url, { fetchImpl }) {
    const eventId = NSCC_EVENT_ID_PATTERN.exec(url)[1];
    const apiUrl = `https://webapi.nscc.ca/nsccapi/api/events/event/${eventId}`;
    const text = await fetchText(apiUrl, fetchImpl, { Accept: 'application/json' });
    return { text, contentType: 'json' };
  },
};

// BiblioCommons (e.g. halifax.bibliocommons.com) serves its /v2/events page
// as a client-rendered SPA - the static HTML has no usable per-event data,
// only a generic Library schema.org block. The SPA itself is backed by a
// public JSON API (confirmed via curl: gateway.bibliocommons.com/v2/libraries/
// {librarySlug}/events, where librarySlug is the page's own subdomain) that
// returns normalized event/location entities. Paginate a few pages of that
// API directly and reshape into the flat {title, startDate, ...} item shape
// the generic JSON extractor already understands, instead of scraping HTML.
const BIBLIOCOMMONS_HOST_PATTERN = /^([a-z0-9-]+)\.bibliocommons\.com$/i;
const BIBLIOCOMMONS_EVENTS_PATH_PATTERN = /^\/v2\/events\/?$/i;
const BIBLIOCOMMONS_MAX_PAGES = 3;
const BIBLIOCOMMONS_PAGE_LIMIT = 50;
const BIBLIOCOMMONS_MIN_EVENTS = 30;

const bibliocommonsResolver = {
  id: 'bibliocommons',
  matches(url) {
    let parsed;
    try {
      parsed = new URL(url);
    } catch (_) {
      return false;
    }
    return (
      BIBLIOCOMMONS_HOST_PATTERN.test(parsed.hostname) &&
      BIBLIOCOMMONS_EVENTS_PATH_PATTERN.test(parsed.pathname)
    );
  },
  async fetchContent(url, { fetchImpl }) {
    const librarySlug = BIBLIOCOMMONS_HOST_PATTERN.exec(new URL(url).hostname)[1];
    const items = [];
    for (let page = 1; page <= BIBLIOCOMMONS_MAX_PAGES; page += 1) {
      const apiUrl =
        `https://gateway.bibliocommons.com/v2/libraries/${librarySlug}/events` +
        `?limit=${BIBLIOCOMMONS_PAGE_LIMIT}&page=${page}`;
      let parsed;
      try {
        const text = await fetchText(apiUrl, fetchImpl, { Accept: 'application/json' });
        parsed = JSON.parse(text);
      } catch (_) {
        break;
      }
      const ids = (parsed.events && parsed.events.items) || [];
      const eventEntities = (parsed.entities && parsed.entities.events) || {};
      const locations = (parsed.entities && parsed.entities.locations) || {};
      for (const id of ids) {
        const definition = eventEntities[id] && eventEntities[id].definition;
        if (!definition || !definition.title || !definition.start) continue;
        const location = locations[definition.branchLocationId];
        items.push({
          title: definition.title,
          startDate: definition.start,
          endDate: definition.end,
          summary: definition.description,
          venueName: location ? location.name : undefined,
        });
      }
      if (ids.length < BIBLIOCOMMONS_PAGE_LIMIT || items.length >= BIBLIOCOMMONS_MIN_EVENTS) {
        break;
      }
    }
    return { text: JSON.stringify({ events: items }), contentType: 'json' };
  },
};

const SOURCE_RESOLVERS = [nsccResolver, bibliocommonsResolver];

function findSourceResolver(url) {
  return SOURCE_RESOLVERS.find((resolver) => resolver.matches(url)) || null;
}

function decodeHtmlEntities(text) {
  return text
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>');
}

function cleanHtml(rawHtml) {
  const stripped = rawHtml
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
    .replace(/<svg[\s\S]*?<\/svg>/gi, ' ')
    .replace(/<nav[\s\S]*?<\/nav>/gi, ' ')
    .replace(/<header[\s\S]*?<\/header>/gi, ' ')
    .replace(/<footer[\s\S]*?<\/footer>/gi, ' ')
    .replace(/<iframe[\s\S]*?<\/iframe>/gi, ' ')
    .replace(/<form[\s\S]*?<\/form>/gi, ' ')
    .replace(/<\/(p|div|li|article|section|h[1-6]|tr)>/gi, '\n')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' ');
  return decodeHtmlEntities(stripped)
    .replace(/[ \t]+/g, ' ')
    .replace(/\n\s+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
    .slice(0, 120000);
}

function parseDateTime(text, defaultYear) {
  const monthPattern =
    'jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|jun(?:e)?|' +
    'jul(?:y)?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|' +
    'dec(?:ember)?';
  const match = new RegExp(
    `\\b(${monthPattern})\\s+(\\d{1,2})(?:st|nd|rd|th)?` +
      `(?:,?\\s+(\\d{4}))?` +
      `(?:\\s+(?:at\\s+)?(\\d{1,2})(?::(\\d{2}))?\\s*(am|pm))?`,
    'i',
  ).exec(text);
  if (!match) return null;
  const months = {
    jan: 0,
    feb: 1,
    mar: 2,
    apr: 3,
    may: 4,
    jun: 5,
    jul: 6,
    aug: 7,
    sep: 8,
    oct: 9,
    nov: 10,
    dec: 11,
  };
  const month = months[match[1].slice(0, 3).toLowerCase()];
  const day = Number.parseInt(match[2], 10);
  const year = Number.parseInt(match[3] || `${defaultYear}`, 10);
  let hour = Number.parseInt(match[4] || '12', 10);
  const minute = Number.parseInt(match[5] || '0', 10);
  const period = (match[6] || '').toLowerCase();
  if (period === 'pm' && hour < 12) hour += 12;
  if (period === 'am' && hour === 12) hour = 0;
  return new Date(year, month, day, hour, minute, 0);
}

function eventDedupeKey(title, start, venueName) {
  const normalizedTitle = title.trim().toLowerCase().replace(/[^a-z0-9]+/g, ' ');
  const normalizedVenue = (venueName || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ');
  return [
    normalizedTitle.trim(),
    start.toISOString().slice(0, 10),
    `${start.getHours()}`.padStart(2, '0'),
    `${start.getMinutes()}`.padStart(2, '0'),
    normalizedVenue.trim(),
  ].join('|');
}

function stableId(seed) {
  return crypto.createHash('sha1').update(seed).digest('hex').slice(0, 16);
}

function inferTags(text) {
  const lower = text.toLowerCase();
  const tags = [];
  if (/music|concert|song|band|dj|choir/.test(lower)) tags.push('music');
  if (/market|vendor|maker|craft/.test(lower)) tags.push('market');
  if (/food|dinner|brunch|beer|wine|restaurant/.test(lower)) tags.push('food');
  if (/walk|outdoor|park|garden|trail/.test(lower)) tags.push('outdoors');
  if (/library|community|meetup|workshop|class/.test(lower)) {
    tags.push('community');
  }
  if (/film|art|gallery|theatre|theater|poetry/.test(lower)) {
    tags.push('arts/culture');
  }
  return [...new Set(tags.length === 0 ? ['community'] : tags)];
}

function titleFromSnippet(snippet) {
  const firstLine = snippet
    .split(/\n|\.| - | \| /)
    .map((line) => line.trim())
    .find((line) => line.length >= 4);
  if (!firstLine) return 'Possible event';
  return firstLine
    .replace(/\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?.*$/i, '')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 90) || 'Possible event';
}

// ---- Foundation CMS listing-card extraction -------------------------------
//
// Some event-listing pages (e.g. community.thecoast.ca's event search, built
// on the "Foundation" CMS) only show a title and link per event card, with
// the date living on each event's own detail page. But confirmed via curl
// that most cards on that same listing *do* carry a dedicated date line
// (`fdn-teaser-subheadline`, e.g. "Sat., June 27, 6-9:30 p.m.") right on the
// card - only a minority (ongoing promos, vague multi-week festivals,
// bare weekly-recurring blurbs with no concrete next date like "Thursdays,
// 8 p.m.") omit it and would genuinely need a second-level crawl into their
// detail page, which isn't built. So: parse the date when the card has one,
// and skip (with a warning, not silently) the cards that don't.
const FOUNDATION_LISTING_SOURCES = [
  {
    id: 'thecoast-community-events',
    matches(url) {
      return /community\.thecoast\.ca\/.+\/EventSearch/i.test(url);
    },
  },
];

function findFoundationListingSource(url) {
  return FOUNDATION_LISTING_SOURCES.find((source) => source.matches(url)) || null;
}

const FOUNDATION_CARD_MARKER_PATTERN = /fdn-event-search-text-block/gi;

// Cards aren't individually delimited by a unique wrapper tag, only by this
// repeated class name, so slice the page into one chunk per marker rather
// than trying to balance nested <div>s. Each slice runs past the end of its
// own card into the next card's leading image markup, but that trailing
// markup never contains the headline/subheadline/location classes below, so
// it can't bleed a wrong value into the current card.
function splitFoundationCards(html) {
  const pattern = new RegExp(FOUNDATION_CARD_MARKER_PATTERN.source, 'gi');
  const starts = [];
  let match;
  while ((match = pattern.exec(html))) starts.push(match.index);
  return starts.map((start, i) =>
    html.slice(start, i + 1 < starts.length ? starts[i + 1] : html.length),
  );
}

function parseFoundationCard(cardHtml) {
  const titleMatch = /<p class="fdn-teaser-headline[^>]*>\s*<a href="([^"]+)">([^<]+)<\/a>/i.exec(
    cardHtml,
  );
  if (!titleMatch) return null;
  const title = decodeHtmlEntities(titleMatch[2]).trim();
  if (!title) return null;

  const subheadlineMatch = /<p class="fdn-teaser-subheadline">([\s\S]*?)<\/p>/i.exec(cardHtml);
  const dateText = subheadlineMatch
    ? decodeHtmlEntities(subheadlineMatch[1]).replace(/\s+/g, ' ').trim()
    : null;

  const venueMatch = /<a class="fdn-event-teaser-location-link"[^>]*>([^<]+)<\/a>/i.exec(cardHtml);
  const venue = venueMatch ? decodeHtmlEntities(venueMatch[1]).trim() : undefined;

  const addressMatch = /fdn-inline-split-list[^>]*>\s*<span>\s*([^<]+?)\s*<\/span>/i.exec(cardHtml);
  const address = addressMatch
    ? decodeHtmlEntities(addressMatch[1]).replace(/\s+/g, ' ').trim()
    : undefined;

  const priceMatch = /<span class="fdn-event-teaser-price[^"]*">([^<]*)<\/span>/i.exec(cardHtml);
  const price = priceMatch ? decodeHtmlEntities(priceMatch[1]).replace(/\s+/g, ' ').trim() : undefined;

  const descriptionMatch = /<div class="fdn-teaser-description[^"]*">([\s\S]*?)<\/div>/i.exec(
    cardHtml,
  );
  const description = descriptionMatch
    ? decodeHtmlEntities(descriptionMatch[1].replace(/<[^>]+>/g, ' '))
        .replace(/\s+/g, ' ')
        .trim()
    : undefined;

  return { link: titleMatch[1], title, dateText, venue, address, price, description };
}

// The listing's date text never includes a year and uses "a.m./p.m." (with
// periods), which the generic parseDateTime() time-of-day group doesn't
// match - so only the date itself is trustworthy here, not the time. Resolve
// the year against the requested range rather than always defaulting to its
// start year, so events in, say, a January slice of a range that starts in
// December still land in the right year.
function resolveFoundationCardDate(dateText, rangeStart, rangeEnd) {
  if (!dateText) return null;
  const start = parseDateTime(dateText, rangeStart.getFullYear());
  if (!start) return null;
  if (start >= rangeStart && start <= rangeEnd) return start;
  const bumped = parseDateTime(dateText, rangeStart.getFullYear() + 1);
  if (bumped && bumped >= rangeStart && bumped <= rangeEnd) return bumped;
  return start;
}

function extractFoundationListingEvents({
  html,
  sourceId,
  sourceName,
  sourceUrl,
  city,
  rangeStart,
  rangeEnd,
}) {
  const cards = splitFoundationCards(html);
  const events = [];
  const seen = new Set();
  let skippedNoDate = 0;

  for (const cardHtml of cards) {
    const parsed = parseFoundationCard(cardHtml);
    if (!parsed) continue;
    const start = resolveFoundationCardDate(parsed.dateText, rangeStart, rangeEnd);
    if (!start) {
      skippedNoDate += 1;
      continue;
    }
    if (start < rangeStart || start > rangeEnd) continue;

    let detailUrl;
    try {
      detailUrl = new URL(parsed.link, sourceUrl).href;
    } catch (_) {
      detailUrl = sourceUrl;
    }
    const missingFields = ['time'];
    if (!parsed.venue) missingFields.push('venue');
    if (!parsed.address) missingFields.push('address');
    if (!parsed.price) missingFields.push('price');

    const dedupeKey = eventDedupeKey(parsed.title, start, parsed.venue);
    if (seen.has(dedupeKey)) continue;
    seen.add(dedupeKey);
    events.push({
      id: `${sourceId}-${stableId(`${parsed.title}|${start.toISOString()}|${detailUrl}`)}`,
      title: parsed.title,
      cleanedTitle: parsed.title,
      summary: parsed.description ? parsed.description.slice(0, 280) : undefined,
      startDateTimeMillis: start.getTime(),
      venueName: parsed.venue,
      address: parsed.address,
      city: city || undefined,
      sourceName,
      sourceType: 'webPage',
      sourceUrl: detailUrl,
      priceLabel: parsed.price,
      isFree: parsed.price ? /free/i.test(parsed.price) : undefined,
      tags: inferTags(`${parsed.title} ${parsed.description || ''}`),
      confidence: 0.75,
      missingFields,
      raw: { userSourceId: sourceId, extractionMode: 'deterministic-fdn-listing' },
      dedupeKey,
    });
  }

  return { events: events.slice(0, 60), totalCards: cards.length, skippedNoDate };
}

// ---- Structured data extraction ------------------------------------------
//
// Before falling back to heuristic text scanning or AI, look for data the
// source already published in a structured, machine-readable form: schema.org
// JSON-LD markup, embedded `application/json` blocks, or (for known-source
// resolvers) a JSON API response. This is high-confidence and source-agnostic
// - no site-specific code lives here.

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&');
}

function extractScriptBlocks(html, scriptType) {
  const blocks = [];
  const pattern = new RegExp(
    `<script[^>]*type=["']${escapeRegExp(scriptType)}["'][^>]*>([\\s\\S]*?)<\\/script>`,
    'gi',
  );
  let match;
  while ((match = pattern.exec(html)) && blocks.length < 20) {
    blocks.push(match[1]);
  }
  return blocks;
}

function isEventType(type) {
  if (typeof type === 'string') return /event$/i.test(type.trim());
  if (Array.isArray(type)) return type.some(isEventType);
  return false;
}

function flattenJsonLdNodes(parsed) {
  if (Array.isArray(parsed)) return parsed.flatMap(flattenJsonLdNodes);
  if (parsed && typeof parsed === 'object') {
    if (Array.isArray(parsed['@graph'])) return parsed['@graph'].flatMap(flattenJsonLdNodes);
    return [parsed];
  }
  return [];
}

function venueFromJsonLdLocation(location) {
  if (!location) return { venue: undefined, address: undefined };
  if (typeof location === 'string') return { venue: location.trim(), address: undefined };
  if (Array.isArray(location)) return venueFromJsonLdLocation(location[0]);
  if (typeof location === 'object') {
    const venue = typeof location.name === 'string' ? location.name.trim() : undefined;
    let address;
    if (typeof location.address === 'string') {
      address = location.address.trim();
    } else if (location.address && typeof location.address === 'object') {
      address =
        [
          location.address.streetAddress,
          location.address.addressLocality,
          location.address.addressRegion,
        ]
          .filter((part) => typeof part === 'string' && part.trim().length > 0)
          .join(', ') || undefined;
    }
    return { venue, address };
  }
  return { venue: undefined, address: undefined };
}

function priceFromJsonLdOffers(offers) {
  const offer = Array.isArray(offers) ? offers[0] : offers;
  if (!offer || typeof offer !== 'object') return undefined;
  if (typeof offer.price !== 'string' && typeof offer.price !== 'number') return undefined;
  const price = `${offer.price}`.trim();
  if (price.length === 0) return undefined;
  return offer.priceCurrency ? `${price} ${offer.priceCurrency}` : price;
}

function mapJsonLdEvent(node, ctx) {
  if (!node || typeof node !== 'object' || !isEventType(node['@type'])) return null;
  const title = typeof node.name === 'string' ? node.name.trim() : '';
  if (!title) return null;
  const start = node.startDate ? new Date(node.startDate) : null;
  if (!start || Number.isNaN(start.getTime())) return null;
  if (start < ctx.rangeStart || start > ctx.rangeEnd) return null;
  const end = node.endDate ? new Date(node.endDate) : null;
  const { venue, address } = venueFromJsonLdLocation(node.location);
  const summary =
    typeof node.description === 'string' ? node.description.trim().slice(0, 280) : undefined;
  const price = priceFromJsonLdOffers(node.offers);
  const ticketUrl = typeof node.url === 'string' ? node.url.trim() : undefined;

  return {
    id: `${ctx.sourceId}-${stableId(`${title}|${start.toISOString()}|${ctx.sourceUrl}`)}`,
    title,
    cleanedTitle: title,
    summary,
    startDateTimeMillis: start.getTime(),
    endDateTimeMillis:
      end && !Number.isNaN(end.getTime()) && end.getTime() > start.getTime()
        ? end.getTime()
        : undefined,
    venueName: venue,
    address,
    city: ctx.city || undefined,
    sourceName: ctx.sourceName,
    sourceType: 'webPage',
    sourceUrl: ctx.sourceUrl,
    ticketUrl,
    priceLabel: price,
    isFree: price ? /free|^0(\s|$)/i.test(price) : undefined,
    tags: inferTags(`${title} ${summary || ''}`),
    confidence: 0.9,
    missingFields: [venue ? null : 'venue', address ? null : 'address', price ? null : 'price'].filter(
      Boolean,
    ),
    raw: { userSourceId: ctx.sourceId, extractionMode: 'deterministic-json-ld' },
    dedupeKey: eventDedupeKey(title, start, venue),
  };
}

function extractJsonLdEvents(html, ctx) {
  const events = [];
  const seen = new Set();
  for (const block of extractScriptBlocks(html, 'application/ld+json')) {
    let parsed;
    try {
      parsed = JSON.parse(block);
    } catch (_) {
      continue;
    }
    for (const node of flattenJsonLdNodes(parsed)) {
      const mapped = mapJsonLdEvent(node, ctx);
      if (!mapped || seen.has(mapped.dedupeKey)) continue;
      seen.add(mapped.dedupeKey);
      events.push(mapped);
    }
  }
  return events;
}

const EVENT_JSON_TITLE_FIELDS = ['title', 'name', 'Name', 'eventName'];
const EVENT_JSON_START_FIELDS = ['startDate', 'DateStart', 'start', 'startTime', 'date'];
const EVENT_JSON_END_FIELDS = ['endDate', 'DateEnd', 'end', 'endTime'];
const EVENT_JSON_SUMMARY_FIELDS = ['summary', 'description', 'Summary', 'Details'];
const EVENT_JSON_VENUE_FIELDS = ['venueName', 'venue', 'OffsiteLocation', 'location'];
const EVENT_JSON_PRICE_FIELDS = ['priceLabel', 'price', 'Fee'];
const EVENT_JSON_ARRAY_FIELDS = ['events', 'items', 'results', 'data', 'Events'];

function firstStringField(item, fields) {
  for (const field of fields) {
    const value = item[field];
    if (typeof value === 'string' && value.trim().length > 0) return value.trim();
  }
  return undefined;
}

function venueFromEventJson(item) {
  const direct = firstStringField(item, EVENT_JSON_VENUE_FIELDS);
  if (direct) return direct;
  if (Array.isArray(item.Locations) && item.Locations[0] && typeof item.Locations[0].LongName === 'string') {
    return item.Locations[0].LongName.trim() || undefined;
  }
  return undefined;
}

function mapEventLikeJsonItem(item, ctx) {
  if (!item || typeof item !== 'object') return null;
  const title = firstStringField(item, EVENT_JSON_TITLE_FIELDS);
  const startRaw = firstStringField(item, EVENT_JSON_START_FIELDS);
  if (!title || !startRaw) return null;
  const start = new Date(startRaw);
  if (Number.isNaN(start.getTime())) return null;
  if (start < ctx.rangeStart || start > ctx.rangeEnd) return null;
  const endRaw = firstStringField(item, EVENT_JSON_END_FIELDS);
  const end = endRaw ? new Date(endRaw) : null;
  const summary = firstStringField(item, EVENT_JSON_SUMMARY_FIELDS);
  const venue = venueFromEventJson(item);
  const price = firstStringField(item, EVENT_JSON_PRICE_FIELDS);

  return {
    id: `${ctx.sourceId}-${stableId(`${title}|${start.toISOString()}|${ctx.sourceUrl}`)}`,
    title,
    cleanedTitle: title,
    summary: summary ? summary.replace(/<[^>]+>/g, ' ').slice(0, 280).trim() : undefined,
    startDateTimeMillis: start.getTime(),
    endDateTimeMillis: end && !Number.isNaN(end.getTime()) ? end.getTime() : undefined,
    venueName: venue,
    sourceName: ctx.sourceName,
    sourceType: 'webPage',
    sourceUrl: ctx.sourceUrl,
    city: ctx.city || undefined,
    priceLabel: price,
    isFree: price ? /free/i.test(price) : undefined,
    tags: inferTags(`${title} ${summary || ''}`),
    confidence: 0.95,
    missingFields: [venue ? null : 'venue', price ? null : 'price'].filter(Boolean),
    raw: { userSourceId: ctx.sourceId, extractionMode: 'deterministic-json' },
    dedupeKey: eventDedupeKey(title, start, venue),
  };
}

function eventLikeArrayFrom(parsed) {
  if (Array.isArray(parsed)) return parsed;
  if (parsed && typeof parsed === 'object') {
    for (const field of EVENT_JSON_ARRAY_FIELDS) {
      if (Array.isArray(parsed[field])) return parsed[field];
    }
    return [parsed];
  }
  return [];
}

function extractEventLikeJsonBlobs(text, ctx) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch (_) {
    return [];
  }
  const events = [];
  const seen = new Set();
  for (const item of eventLikeArrayFrom(parsed)) {
    const mapped = mapEventLikeJsonItem(item, ctx);
    if (!mapped || seen.has(mapped.dedupeKey)) continue;
    seen.add(mapped.dedupeKey);
    events.push(mapped);
  }
  return events;
}

function extractStructuredEvents({ html, jsonText, sourceId, sourceName, sourceUrl, city, rangeStart, rangeEnd }) {
  const ctx = { sourceId, sourceName, sourceUrl, city, rangeStart, rangeEnd };
  const events = [];
  const seen = new Set();
  const addAll = (found) => {
    for (const ev of found) {
      if (!ev || seen.has(ev.dedupeKey)) continue;
      seen.add(ev.dedupeKey);
      events.push(ev);
    }
  };

  if (jsonText) addAll(extractEventLikeJsonBlobs(jsonText, ctx));
  if (html) {
    addAll(extractJsonLdEvents(html, ctx));
    for (const block of extractScriptBlocks(html, 'application/json')) {
      addAll(extractEventLikeJsonBlobs(block, ctx));
    }
  }
  return events.slice(0, 30);
}

function extractDeterministicEvents({
  text,
  sourceId,
  sourceName,
  sourceUrl,
  city,
  rangeStart,
  rangeEnd,
}) {
  const lines = text.split('\n').filter((line) => line.trim().length > 0);
  const events = [];
  const seen = new Set();
  for (let i = 0; i < lines.length && events.length < 20; i += 1) {
    const window = lines.slice(Math.max(0, i - 1), i + 4).join(' ').trim();
    const start = parseDateTime(window, rangeStart.getFullYear());
    if (!start || start < rangeStart || start > rangeEnd) continue;
    const title = titleFromSnippet(window);
    const key = eventDedupeKey(title, start);
    if (seen.has(key)) continue;
    seen.add(key);
    const missingFields = ['venue', 'address', 'price'];
    if (!/\b\d{1,5}\s+\w+/.test(window)) missingFields.push('exact address');
    events.push({
      id: `${sourceId}-${stableId(`${title}|${start.toISOString()}|${sourceUrl}`)}`,
      title,
      cleanedTitle: title,
      summary: window.slice(0, 260),
      description: window.slice(0, 700),
      startDateTimeMillis: start.getTime(),
      sourceName,
      sourceType: 'webPage',
      sourceUrl,
      priceLabel: /free/i.test(window) ? 'Free' : 'Price unknown',
      isFree: /free/i.test(window) ? true : undefined,
      city,
      tags: inferTags(window),
      confidence: 0.52,
      missingFields: [...new Set(missingFields)],
      raw: {
        userSourceId: sourceId,
        extractionMode: 'deterministic-webpage-fallback',
      },
      dedupeKey: key,
    });
  }
  return events;
}

// ---- AI extraction -------------------------------------------------------

function clamp01(value) {
  const num = typeof value === 'number' ? value : Number.parseFloat(value);
  if (!Number.isFinite(num)) return null;
  return Math.min(1, Math.max(0, num));
}

function combineDateTime(dateStr, timeStr) {
  if (typeof dateStr !== 'string') return null;
  const dateMatch = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr.trim());
  if (!dateMatch) return null;
  const [, y, m, d] = dateMatch;
  let hour = 12;
  let minute = 0;
  if (typeof timeStr === 'string') {
    const timeMatch = /^(\d{1,2}):(\d{2})$/.exec(timeStr.trim());
    if (timeMatch) {
      hour = Number.parseInt(timeMatch[1], 10);
      minute = Number.parseInt(timeMatch[2], 10);
    }
  }
  return new Date(Number(y), Number(m) - 1, Number(d), hour, minute, 0);
}

function parseAiJson(content) {
  if (typeof content !== 'string' || content.trim().length === 0) {
    throw new Error('ai_empty_response');
  }
  const trimmed = content.trim();
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    const match = /\{[\s\S]*\}/.exec(trimmed);
    if (!match) throw new Error('ai_invalid_json');
    return JSON.parse(match[0]);
  }
}

function chunkText(text, chunkSize, maxChunks) {
  const chunks = [];
  for (
    let offset = 0;
    offset < text.length && chunks.length < maxChunks;
    offset += chunkSize
  ) {
    const chunk = text.slice(offset, offset + chunkSize).trim();
    if (chunk.length > 0) chunks.push(chunk);
  }
  return chunks;
}

function buildAiSystemPrompt() {
  return [
    'You extract event listings from messy public webpage text for a personal planning app.',
    'Return ONLY minified JSON matching exactly this shape, with no surrounding text or markdown:',
    '{"events":[{"title":string,"summary":string|null,"startDate":"YYYY-MM-DD"|null,"endDate":"YYYY-MM-DD"|null,"startTime":"HH:MM"|null,"endTime":"HH:MM"|null,"venue":string|null,"address":string|null,"price":string|null,"ticketUrl":string|null,"tags":string[],"confidence":number,"uncertainFields":string[]}]}.',
    'Rules: only list events you find clear evidence for in the supplied text. Never invent or guess a value that is not present - use null (or [] for tags) instead and add that field name to uncertainFields.',
    'startDate/endDate are YYYY-MM-DD; startTime/endTime are 24-hour HH:MM. confidence is your own 0-1 estimate that this is a real, correctly dated event.',
    'If the text has no events, return {"events":[]}.',
  ].join(' ');
}

function buildAiUserPrompt({
  sourceName,
  sourceUrl,
  city,
  rangeStart,
  rangeEnd,
  textChunk,
  chunkIndex,
  chunkCount,
}) {
  return [
    `Source: ${sourceName} (${sourceUrl})`,
    city ? `Default city if the page does not state one: ${city}.` : '',
    `Only include events between ${rangeStart.toISOString().slice(0, 10)} and ${rangeEnd.toISOString().slice(0, 10)} inclusive.`,
    chunkCount > 1
      ? `This is text section ${chunkIndex + 1} of ${chunkCount} from the page; some events may be cut off at the edges, only extract ones you can read in full.`
      : '',
    'Page text follows:',
    textChunk,
  ]
    .filter((part) => part && part.length > 0)
    .join('\n');
}

async function callOpenAi({
  apiKey,
  model,
  systemPrompt,
  userPrompt,
  fetchImpl,
  timeoutMs,
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(
      'https://api.openai.com/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          temperature: 0,
          response_format: { type: 'json_object' },
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userPrompt },
          ],
        }),
        signal: controller.signal,
      },
    );
    if (!response.ok) throw new Error(`openai_http_${response.status}`);
    const data = await response.json();
    const content =
      data && data.choices && data.choices[0] && data.choices[0].message
        ? data.choices[0].message.content
        : null;
    return parseAiJson(content);
  } finally {
    clearTimeout(timeout);
  }
}

async function callGemini({
  apiKey,
  model,
  systemPrompt,
  userPrompt,
  fetchImpl,
  timeoutMs,
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const response = await fetchImpl(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          { role: 'user', parts: [{ text: `${systemPrompt}\n\n${userPrompt}` }] },
        ],
        generationConfig: { temperature: 0, responseMimeType: 'application/json' },
      }),
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`gemini_http_${response.status}`);
    const data = await response.json();
    const content =
      data && data.candidates && data.candidates[0] && data.candidates[0].content
        ? data.candidates[0].content.parts
            .map((part) => (part && typeof part.text === 'string' ? part.text : ''))
            .join('')
        : null;
    return parseAiJson(content);
  } finally {
    clearTimeout(timeout);
  }
}

function mapAiEventItem({
  item,
  sourceId,
  sourceName,
  sourceUrl,
  city,
  rangeStart,
  rangeEnd,
  provider,
}) {
  if (!item || typeof item !== 'object') return null;
  const title = typeof item.title === 'string' ? item.title.trim() : '';
  if (!title) return null;
  const start = combineDateTime(item.startDate, item.startTime);
  if (!start || start < rangeStart || start > rangeEnd) return null;
  const end = combineDateTime(item.endDate || item.startDate, item.endTime);

  const uncertain = new Set(
    Array.isArray(item.uncertainFields)
      ? item.uncertainFields
          .filter((field) => typeof field === 'string' && field.trim().length > 0)
          .map((field) => field.trim())
      : [],
  );
  if (!item.startTime) uncertain.add('time');
  const venue =
    typeof item.venue === 'string' && item.venue.trim() ? item.venue.trim() : null;
  if (!venue) uncertain.add('venue');
  const address =
    typeof item.address === 'string' && item.address.trim()
      ? item.address.trim()
      : null;
  if (!address) uncertain.add('address');
  const price =
    typeof item.price === 'string' && item.price.trim() ? item.price.trim() : null;
  if (!price) uncertain.add('price');

  const confidence = clamp01(item.confidence) ?? 0.6;
  const tags = Array.isArray(item.tags)
    ? item.tags
        .filter((tag) => typeof tag === 'string' && tag.trim().length > 0)
        .map((tag) => tag.trim().toLowerCase())
    : [];
  const summary =
    typeof item.summary === 'string' && item.summary.trim()
      ? item.summary.trim().slice(0, 280)
      : undefined;
  const ticketUrl =
    typeof item.ticketUrl === 'string' && item.ticketUrl.trim()
      ? item.ticketUrl.trim()
      : undefined;

  return {
    id: `${sourceId}-${stableId(`${title}|${start.toISOString()}|${sourceUrl}`)}`,
    title,
    cleanedTitle: title,
    summary,
    startDateTimeMillis: start.getTime(),
    endDateTimeMillis:
      end && end.getTime() > start.getTime() ? end.getTime() : undefined,
    venueName: venue || undefined,
    address: address || undefined,
    city: city || undefined,
    sourceName,
    sourceType: 'webPage',
    sourceUrl,
    ticketUrl,
    priceLabel: price || undefined,
    isFree: price ? /free/i.test(price) : undefined,
    tags: tags.length > 0 ? tags : inferTags(`${title} ${summary || ''}`),
    confidence,
    missingFields: [...uncertain].sort(),
    raw: { userSourceId: sourceId, extractionMode: `ai-${provider}-webpage` },
    dedupeKey: eventDedupeKey(title, start, venue),
  };
}

async function extractEventsWithAi({
  text,
  provider,
  apiKey,
  model,
  sourceId,
  sourceName,
  sourceUrl,
  city,
  rangeStart,
  rangeEnd,
  fetchImpl,
}) {
  const chunks = chunkText(text, AI_CHUNK_SIZE, AI_MAX_CHUNKS);
  if (chunks.length === 0) {
    return {
      events: [],
      warnings: ['Page contained no extractable text for AI to review.'],
      failed: false,
    };
  }

  const systemPrompt = buildAiSystemPrompt();
  const events = [];
  const seen = new Set();
  let succeededChunks = 0;

  for (let index = 0; index < chunks.length; index += 1) {
    const userPrompt = buildAiUserPrompt({
      sourceName,
      sourceUrl,
      city,
      rangeStart,
      rangeEnd,
      textChunk: chunks[index],
      chunkIndex: index,
      chunkCount: chunks.length,
    });
    try {
      const parsed =
        provider === 'openai'
          ? await callOpenAi({
              apiKey,
              model,
              systemPrompt,
              userPrompt,
              fetchImpl,
              timeoutMs: AI_TIMEOUT_MS,
            })
          : await callGemini({
              apiKey,
              model,
              systemPrompt,
              userPrompt,
              fetchImpl,
              timeoutMs: AI_TIMEOUT_MS,
            });
      const rawEvents = Array.isArray(parsed && parsed.events) ? parsed.events : [];
      for (const item of rawEvents) {
        const mapped = mapAiEventItem({
          item,
          sourceId,
          sourceName,
          sourceUrl,
          city,
          rangeStart,
          rangeEnd,
          provider,
        });
        if (!mapped || seen.has(mapped.dedupeKey)) continue;
        seen.add(mapped.dedupeKey);
        events.push(mapped);
      }
      succeededChunks += 1;
    } catch (error) {
      console.error(
        'outside-events-webpage AI chunk error:',
        provider,
        error && error.message,
      );
    }
  }

  if (succeededChunks === 0) {
    return { events: [], warnings: [], failed: true };
  }
  const warnings = [];
  if (succeededChunks < chunks.length) {
    warnings.push(
      `AI extraction partially failed; ${chunks.length - succeededChunks} of ` +
        `${chunks.length} page section(s) were skipped.`,
    );
  }
  return { events: events.slice(0, 30), warnings, failed: false };
}

async function extractEventsWithAiOrFallback(input) {
  const env = input.env || process.env;
  const fetchImpl = input.fetchImpl || fetch;
  const provider = env.OPENAI_API_KEY
    ? 'openai'
    : env.GEMINI_API_KEY
      ? 'gemini'
      : null;

  if (!provider) {
    const events = extractDeterministicEvents(input);
    const warnings = [
      'AI organizer not configured. Used deterministic webpage extraction; review dates and details before adding.',
    ];
    if (events.length === 0) {
      warnings.push('No dated event-like snippets were found on this page.');
    }
    return { events, warnings, aiConfigured: false };
  }

  const apiKey = provider === 'openai' ? env.OPENAI_API_KEY : env.GEMINI_API_KEY;
  const model =
    provider === 'openai'
      ? env.OPENAI_MODEL || DEFAULT_OPENAI_MODEL
      : env.GEMINI_MODEL || DEFAULT_GEMINI_MODEL;

  const result = await extractEventsWithAi({
    text: input.text,
    provider,
    apiKey,
    model,
    sourceId: input.sourceId,
    sourceName: input.sourceName,
    sourceUrl: input.sourceUrl,
    city: input.city,
    rangeStart: input.rangeStart,
    rangeEnd: input.rangeEnd,
    fetchImpl,
  });

  if (result.failed) {
    const events = extractDeterministicEvents(input);
    const warnings = [
      `AI organizer (${provider}) could not extract events from this page; used ` +
        'deterministic fallback instead. Review dates and details before adding.',
    ];
    if (events.length === 0) {
      warnings.push('No dated event-like snippets were found on this page.');
    }
    return { events, warnings, aiConfigured: true };
  }

  const warnings = [...result.warnings];
  if (result.events.length === 0) {
    warnings.push('AI organizer found no events on this page.');
  }
  return { events: result.events, warnings, aiConfigured: true };
}

async function handler(event, context) {
  if (event.httpMethod !== 'GET') return methodNotAllowedResponse();

  const query = event.queryStringParameters || {};
  const rawUrl = readParam(query, 'url');
  if (!rawUrl) return badRequestResponse('missing_url');

  let parsedUrl;
  try {
    parsedUrl = await assertPublicUrl(rawUrl, (context && context.lookup) || dns.lookup);
  } catch (error) {
    return badRequestResponse(error && error.message);
  }

  const sourceId = readParam(query, 'sourceId', `web-${stableId(parsedUrl.href)}`);
  const sourceName = readParam(query, 'sourceName', parsedUrl.hostname);
  const city = readParam(query, 'city', '');
  const rangeStart = new Date(readParam(query, 'start', new Date().toISOString()));
  const rangeEnd = new Date(
    readParam(
      query,
      'end',
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    ),
  );

  try {
    const fetchImpl = (context && context.fetch) || fetch;
    const env = (context && context.env) || process.env;
    const resolver = findSourceResolver(parsedUrl.href);

    let html = null;
    let jsonText = null;
    let pagesFetched = 1;
    if (resolver) {
      const resolved = await resolver.fetchContent(parsedUrl.href, { fetchImpl });
      if (resolved.contentType === 'json') {
        jsonText = resolved.text;
      } else {
        html = resolved.text;
      }
    } else {
      const firstHtml = await fetchPage(parsedUrl.href, fetchImpl);
      const pages = await fetchPaginatedPages({
        firstUrl: parsedUrl.href,
        firstHtml,
        fetchImpl,
      });
      pagesFetched = pages.length;
      html = pages.map((page) => page.html).join('\n');
    }

    const structuredEvents = extractStructuredEvents({
      html,
      jsonText,
      sourceId,
      sourceName,
      sourceUrl: parsedUrl.href,
      city,
      rangeStart,
      rangeEnd,
    });

    const text = html ? cleanHtml(html) : jsonText || '';
    const foundationSource =
      structuredEvents.length === 0 && html ? findFoundationListingSource(parsedUrl.href) : null;
    const foundationResult = foundationSource
      ? extractFoundationListingEvents({
          html,
          sourceId,
          sourceName,
          sourceUrl: parsedUrl.href,
          city,
          rangeStart,
          rangeEnd,
        })
      : null;

    let extraction;
    if (structuredEvents.length > 0) {
      extraction = {
        events: structuredEvents,
        warnings: [],
        aiConfigured: Boolean(env.OPENAI_API_KEY || env.GEMINI_API_KEY),
      };
    } else if (foundationResult && foundationResult.events.length > 0) {
      const warnings = [];
      if (foundationResult.skippedNoDate > 0) {
        warnings.push(
          `${foundationResult.skippedNoDate} event(s) on this listing have no date shown ` +
            "on the card itself (only on their own detail page, which Life Shuffle doesn't " +
            'crawl into yet) and were skipped.',
        );
      }
      extraction = {
        events: foundationResult.events,
        warnings,
        aiConfigured: Boolean(env.OPENAI_API_KEY || env.GEMINI_API_KEY),
      };
    } else if (foundationResult && foundationResult.totalCards > 0) {
      extraction = {
        events: [],
        warnings: [
          `Listing page loaded (${pagesFetched} page${pagesFetched === 1 ? '' : 's'}, ` +
            `${foundationResult.totalCards} event card(s) visible), but none of them had a ` +
            "date shown on the card itself - each event's own detail page has the date, and " +
            "Life Shuffle does not crawl into individual event detail pages yet, so this " +
            "source can't extract dates from the listing alone.",
        ],
        aiConfigured: null,
      };
    } else {
      extraction = await extractEventsWithAiOrFallback({
        text,
        sourceId,
        sourceName,
        sourceUrl: parsedUrl.href,
        city,
        rangeStart,
        rangeEnd,
        fetchImpl,
        env,
      });
    }
    return jsonResponse(200, {
      sourceId,
      sourceName,
      sourceUrl: parsedUrl.href,
      contentLength: text.length,
      pagesFetched,
      aiConfigured: extraction.aiConfigured,
      warnings: extraction.warnings,
      events: extraction.events,
    });
  } catch (error) {
    console.error(
      'outside-events-webpage function error:',
      parsedUrl.href,
      error && error.message,
    );
    if (error && error.message === 'response_too_large') {
      return jsonResponse(413, { error: 'response_too_large' });
    }
    return upstreamErrorResponse('page_unavailable');
  }
}

module.exports = {
  handler,
  assertPublicUrl,
  cleanHtml,
  parseDateTime,
  findSourceResolver,
  sourceResolvers: SOURCE_RESOLVERS,
  findFoundationListingSource,
  foundationListingSources: FOUNDATION_LISTING_SOURCES,
  splitFoundationCards,
  parseFoundationCard,
  extractFoundationListingEvents,
  extractJsonLdEvents,
  extractEventLikeJsonBlobs,
  extractStructuredEvents,
  extractDeterministicEvents,
  extractEventsWithAiOrFallback,
  extractEventsWithAi,
  mapAiEventItem,
  combineDateTime,
  chunkText,
  parseAiJson,
  clamp01,
  callOpenAi,
  callGemini,
  buildAiSystemPrompt,
  buildAiUserPrompt,
  methodNotAllowedResponse,
  badRequestResponse,
  upstreamErrorResponse,
  findNextPageUrl,
  fetchPaginatedPages,
  MAX_ADDITIONAL_PAGES,
};
