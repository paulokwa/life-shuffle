'use strict';

const crypto = require('node:crypto');
const dns = require('node:dns/promises');
const net = require('node:net');

const MAX_BYTES = 1024 * 1024;
const TIMEOUT_MS = 10000;

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

async function fetchPage(url, fetchImpl) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: {
        Accept: 'text/html, application/xhtml+xml, text/plain;q=0.9, */*;q=0.5',
        'User-Agent': 'LifeShuffleOutsideEvents/1.0',
      },
      signal: controller.signal,
    });
    if (!response.ok) throw new Error(`Page returned ${response.status}`);
    return readLimitedText(response);
  } finally {
    clearTimeout(timeout);
  }
}

function cleanHtml(rawHtml) {
  return rawHtml
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
    .replace(/<svg[\s\S]*?<\/svg>/gi, ' ')
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

async function extractEventsWithAiOrFallback(input) {
  const aiConfigured = Boolean(process.env.OPENAI_API_KEY || process.env.GEMINI_API_KEY);
  const events = extractDeterministicEvents(input);
  const warnings = [];
  if (!aiConfigured) {
    warnings.push(
      'AI organizer not configured. Used deterministic webpage extraction; review dates and details before adding.',
    );
  } else {
    warnings.push(
      'AI organizer endpoint seam is present, but this spike still uses deterministic extraction until provider wiring is finished.',
    );
  }
  if (events.length === 0) {
    warnings.push('No dated event-like snippets were found on this page.');
  }
  return { events, warnings, aiConfigured };
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
    const rawHtml = await fetchPage(parsedUrl.href, fetchImpl);
    const text = cleanHtml(rawHtml);
    const extraction = await extractEventsWithAiOrFallback({
      text,
      sourceId,
      sourceName,
      sourceUrl: parsedUrl.href,
      city,
      rangeStart,
      rangeEnd,
    });
    return jsonResponse(200, {
      sourceId,
      sourceName,
      sourceUrl: parsedUrl.href,
      contentLength: text.length,
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
  extractDeterministicEvents,
  extractEventsWithAiOrFallback,
  methodNotAllowedResponse,
  badRequestResponse,
  upstreamErrorResponse,
};
