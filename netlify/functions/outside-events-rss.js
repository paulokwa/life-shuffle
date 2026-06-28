'use strict';

const dns = require('node:dns/promises');
const net = require('node:net');

const FEEDS = Object.freeze({
  'discover-halifax-events': {
    name: 'Discover Halifax events',
    url: 'https://discoverhalifaxns.com/events/feed/',
  },
  'the-coast-arts-music': {
    name: 'The Coast arts and music',
    url: 'https://www.thecoast.ca/category/arts-music/feed/',
  },
  'the-coast-food-drink': {
    name: 'The Coast food and drink',
    url: 'https://www.thecoast.ca/category/food-drink/feed/',
  },
  'feed-nova-scotia-events': {
    name: 'Feed Nova Scotia events',
    url: 'https://feednovascotia.ca/events/feed/',
  },
});

const MAX_BYTES = 512 * 1024;
const TIMEOUT_MS = 8000;

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
  return jsonResponse(400, { error: error || 'unknown_source' });
}

function upstreamErrorResponse() {
  return jsonResponse(502, { error: 'feed_unavailable' });
}

function extractSourceId(queryStringParameters) {
  const source = queryStringParameters && queryStringParameters.source;
  if (typeof source !== 'string') return null;
  const trimmed = source.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function extractSourceUrl(queryStringParameters) {
  const url = queryStringParameters && queryStringParameters.url;
  if (typeof url !== 'string') return null;
  const trimmed = url.trim();
  return trimmed.length === 0 ? null : trimmed;
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
  if (net.isIP(host) && isPrivateIp(host)) {
    throw new Error('private_url');
  }
  const records = await lookupImpl(host, { all: true });
  if (!Array.isArray(records) || records.length === 0) {
    throw new Error('dns_failed');
  }
  if (records.some((record) => isPrivateIp(record.address))) {
    throw new Error('private_url');
  }
  return parsed.toString();
}

async function readLimitedText(response) {
  const declared =
    response.headers && typeof response.headers.get === 'function'
      ? Number.parseInt(response.headers.get('content-length') || '0', 10)
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

async function fetchFeedXml(feed, fetchImpl) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetchImpl(feed.url, {
      headers: {
        Accept: 'application/rss+xml, application/atom+xml, text/xml',
        'User-Agent': 'LifeShuffleOutsideEvents/1.0',
      },
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`Feed returned ${response.status}`);
    }
    const body = await readLimitedText(response);
    if (!body.trimStart().startsWith('<')) {
      throw new Error('Feed did not return XML');
    }
    return body;
  } finally {
    clearTimeout(timeout);
  }
}

function xmlResponse(xmlText) {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/xml; charset=utf-8',
      'Cache-Control': 'public, max-age=900, stale-while-revalidate=1800',
    },
    body: xmlText,
  };
}

async function handler(event, context) {
  if (event.httpMethod !== 'GET') {
    return methodNotAllowedResponse();
  }

  const sourceId = extractSourceId(event.queryStringParameters);
  const sourceUrl = extractSourceUrl(event.queryStringParameters);
  let feed = sourceId ? FEEDS[sourceId] : null;
  if (!feed && sourceUrl) {
    try {
      const lookupImpl = context && context.lookup;
      feed = {
        name: 'User RSS/Atom source',
        url: await assertPublicUrl(sourceUrl, lookupImpl || dns.lookup),
      };
    } catch (error) {
      return badRequestResponse(error && error.message);
    }
  }
  if (!feed) return badRequestResponse('unknown_source');

  try {
    const fetchImpl = (context && context.fetch) || fetch;
    return xmlResponse(await fetchFeedXml(feed, fetchImpl));
  } catch (error) {
    console.error(
      'outside-events-rss function error:',
      sourceId,
      error && error.message,
    );
    return upstreamErrorResponse();
  }
}

module.exports = {
  handler,
  FEEDS,
  extractSourceId,
  fetchFeedXml,
  xmlResponse,
  methodNotAllowedResponse,
  badRequestResponse,
  upstreamErrorResponse,
};
