'use strict';

const crypto = require('node:crypto');

const TIMEOUT_MS = 10000;
const DEFAULT_CITY = 'Halifax';
const DISCOVERY_URL = 'https://app.ticketmaster.com/discovery/v2/events.json';

function jsonResponse(statusCode, payload) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  };
}

function methodNotAllowedResponse() {
  return {
    statusCode: 405,
    headers: { Allow: 'GET', 'Content-Type': 'application/json' },
    body: JSON.stringify({ error: 'method_not_allowed' }),
  };
}

function readParam(query, name, fallback) {
  const value = query && query[name];
  if (typeof value !== 'string') return fallback ?? null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? (fallback ?? null) : trimmed;
}

function stableId(seed) {
  return crypto.createHash('sha1').update(seed).digest('hex').slice(0, 16);
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

function toTicketmasterDateTime(date) {
  return `${date.toISOString().slice(0, 19)}Z`;
}

function mapEvent(raw, city) {
  if (!raw || typeof raw !== 'object') return null;
  const title = typeof raw.name === 'string' ? raw.name.trim() : '';
  if (!title) return null;

  const dates = raw.dates && raw.dates.start;
  const startIso =
    dates &&
    (dates.dateTime ||
      (dates.localDate
        ? `${dates.localDate}T${dates.localTime || '19:00:00'}`
        : null));
  if (!startIso) return null;
  const start = new Date(startIso);
  if (Number.isNaN(start.getTime())) return null;

  const venue =
    raw._embedded && Array.isArray(raw._embedded.venues)
      ? raw._embedded.venues[0]
      : null;
  const venueName =
    venue && typeof venue.name === 'string' ? venue.name.trim() : null;
  const address =
    venue && venue.address && typeof venue.address.line1 === 'string'
      ? venue.address.line1.trim()
      : null;
  const priceRange = Array.isArray(raw.priceRanges) ? raw.priceRanges[0] : null;
  const priceLabel =
    priceRange && (priceRange.min || priceRange.min === 0)
      ? `$${priceRange.min}-$${priceRange.max}${priceRange.currency ? ` ${priceRange.currency}` : ''}`
      : null;
  const classification = Array.isArray(raw.classifications)
    ? raw.classifications[0]
    : null;
  const tags = classification
    ? [
        classification.segment && classification.segment.name,
        classification.genre && classification.genre.name,
      ]
        .filter(
          (tag) =>
            typeof tag === 'string' &&
            tag.trim().length > 0 &&
            tag.trim().toLowerCase() !== 'undefined',
        )
        .map((tag) => tag.trim().toLowerCase())
    : [];
  const missingFields = [];
  if (!venueName) missingFields.push('venue');
  if (!address) missingFields.push('address');
  if (!priceLabel) missingFields.push('price');

  return {
    id: `ticketmaster-${stableId(raw.id || `${title}|${start.toISOString()}`)}`,
    title,
    cleanedTitle: title,
    summary:
      typeof raw.info === 'string'
        ? raw.info
        : typeof raw.pleaseNote === 'string'
          ? raw.pleaseNote
          : undefined,
    startDateTimeMillis: start.getTime(),
    venueName: venueName || undefined,
    address: address || undefined,
    city: (venue && venue.city && venue.city.name) || city || undefined,
    sourceName: 'Ticketmaster',
    sourceType: 'ticketmaster',
    sourceUrl: typeof raw.url === 'string' ? raw.url : undefined,
    ticketUrl: typeof raw.url === 'string' ? raw.url : undefined,
    priceLabel: priceLabel || undefined,
    tags,
    confidence: 0.95,
    missingFields,
    raw: { extractionMode: 'ticketmaster-api' },
    dedupeKey: eventDedupeKey(title, start, venueName),
  };
}

async function handler(event, context) {
  if (event.httpMethod !== 'GET') return methodNotAllowedResponse();

  const env = (context && context.env) || process.env;
  const apiKey = env.TICKETMASTER_API_KEY;
  const query = event.queryStringParameters || {};
  const city = readParam(query, 'city', DEFAULT_CITY);

  if (!apiKey) {
    return jsonResponse(200, {
      configured: false,
      events: [],
      warnings: [
        'Ticketmaster is not configured. Set TICKETMASTER_API_KEY in Netlify ' +
          'to enable live results.',
      ],
    });
  }

  const start = new Date(
    readParam(query, 'start', new Date().toISOString()),
  );
  const end = new Date(
    readParam(
      query,
      'end',
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
    ),
  );

  const url = new URL(DISCOVERY_URL);
  url.searchParams.set('apikey', apiKey);
  url.searchParams.set('city', city);
  url.searchParams.set('startDateTime', toTicketmasterDateTime(start));
  url.searchParams.set('endDateTime', toTicketmasterDateTime(end));
  url.searchParams.set('size', '50');
  url.searchParams.set('sort', 'date,asc');

  const fetchImpl = (context && context.fetch) || fetch;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetchImpl(url.toString(), {
      signal: controller.signal,
    });
    if (!response.ok) {
      return jsonResponse(502, {
        configured: true,
        events: [],
        warnings: [`Ticketmaster returned HTTP ${response.status}.`],
      });
    }
    const data = await response.json();
    const rawEvents =
      data && data._embedded && Array.isArray(data._embedded.events)
        ? data._embedded.events
        : [];
    const events = rawEvents.map((raw) => mapEvent(raw, city)).filter(Boolean);
    return jsonResponse(200, { configured: true, events, warnings: [] });
  } catch (error) {
    console.error(
      'outside-events-ticketmaster function error:',
      error && error.message,
    );
    return jsonResponse(502, {
      configured: true,
      events: [],
      warnings: ['Ticketmaster could not be reached.'],
    });
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = {
  handler,
  mapEvent,
  toTicketmasterDateTime,
  eventDedupeKey,
  methodNotAllowedResponse,
};
