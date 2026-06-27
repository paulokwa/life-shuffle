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
    return readLimitedText(response);
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

const SOURCE_RESOLVERS = [nsccResolver];

function findSourceResolver(url) {
  return SOURCE_RESOLVERS.find((resolver) => resolver.matches(url)) || null;
}

// ---- Known listing-only sources -------------------------------------------
//
// Some event-listing pages only show a title and link per event - the date
// lives on each event's own detail page (e.g. community.thecoast.ca's event
// search: confirmed via curl that the listing HTML has no per-event date
// anywhere, but every detail page carries a full schema.org Event JSON-LD
// with startDate/endDate). Extracting these for real needs a second-level
// crawl (listing page -> each event's own detail page), which is a bigger
// feature with its own timeout/cost budget and isn't built yet. Detecting
// the pattern up front gives a specific, actionable diagnostic instead of a
// generic "no events found", and skips a wasted AI/deterministic extraction
// call on a page we already know has no dates to find.
const LISTING_ONLY_NO_DATE_SOURCES = [
  {
    id: 'thecoast-community-events',
    matches(url) {
      return /community\.thecoast\.ca\/.+\/EventSearch/i.test(url);
    },
    // Matches the listing's repeated event-card markup, purely to confirm
    // (and count, for the diagnostic message) that events really are
    // visible on the listing - not used for date extraction.
    eventCardPattern: /fdn-event-search-text-block/gi,
    explanation:
      "each event's own detail page has the date - the listing itself " +
      'never shows it. Life Shuffle does not crawl into individual event ' +
      "detail pages yet, so this source can't extract dates from the " +
      'listing alone.',
  },
];

function findListingOnlyNoDateSource(url) {
  return (
    LISTING_ONLY_NO_DATE_SOURCES.find((source) => source.matches(url)) || null
  );
}

function countMatches(text, pattern) {
  if (!text || !pattern) return 0;
  const matches = text.match(pattern);
  return matches ? matches.length : 0;
}

function cleanHtml(rawHtml) {
  return rawHtml
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
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
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
    const listingOnlySource =
      structuredEvents.length === 0
        ? findListingOnlyNoDateSource(parsedUrl.href)
        : null;
    const extraction =
      structuredEvents.length > 0
        ? {
            events: structuredEvents,
            warnings: [],
            aiConfigured: Boolean(env.OPENAI_API_KEY || env.GEMINI_API_KEY),
          }
        : listingOnlySource
          ? {
              events: [],
              warnings: [
                `Listing page loaded (${pagesFetched} page` +
                  `${pagesFetched === 1 ? '' : 's'}, ` +
                  `${countMatches(html, listingOnlySource.eventCardPattern)} ` +
                  'event card(s) visible), but no dated events were found ' +
                  `on the listing - ${listingOnlySource.explanation}`,
              ],
              aiConfigured: null,
            }
          : await extractEventsWithAiOrFallback({
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
  findListingOnlyNoDateSource,
  listingOnlyNoDateSources: LISTING_ONLY_NO_DATE_SOURCES,
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
