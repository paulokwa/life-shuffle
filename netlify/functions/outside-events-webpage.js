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
      fetchImpl,
      env: (context && context.env) || process.env,
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
};
