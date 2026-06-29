'use strict';

const dns = require('node:dns/promises');
const net = require('node:net');

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
  return jsonResponse(400, { error: error || 'invalid_request' });
}

function upstreamErrorResponse() {
  return jsonResponse(502, { error: 'feed_unavailable' });
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

async function fetchIcsText(url, fetchImpl) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetchImpl(url, {
      headers: {
        Accept: 'text/calendar, application/ics, text/plain;q=0.5',
        'User-Agent': 'LifeShuffleOutsideEvents/1.0',
      },
      signal: controller.signal,
    });
    if (!response.ok) {
      throw new Error(`Feed returned ${response.status}`);
    }
    const body = await readLimitedText(response);
    if (!/BEGIN:VCALENDAR/i.test(body.slice(0, 200))) {
      throw new Error('not_icalendar');
    }
    return body;
  } finally {
    clearTimeout(timeout);
  }
}

function icsResponse(icsText) {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'text/calendar; charset=utf-8',
      'Cache-Control': 'public, max-age=900, stale-while-revalidate=1800',
    },
    body: icsText,
  };
}

async function handler(event, context) {
  if (event.httpMethod !== 'GET') {
    return methodNotAllowedResponse();
  }

  const sourceUrl = extractSourceUrl(event.queryStringParameters);
  if (!sourceUrl) return badRequestResponse('missing_url');

  let url;
  try {
    const lookupImpl = context && context.lookup;
    url = await assertPublicUrl(sourceUrl, lookupImpl || dns.lookup);
  } catch (error) {
    return badRequestResponse(error && error.message);
  }

  try {
    const fetchImpl = (context && context.fetch) || fetch;
    return icsResponse(await fetchIcsText(url, fetchImpl));
  } catch (error) {
    console.error(
      'outside-events-ics function error:',
      sourceUrl,
      error && error.message,
    );
    if (error && error.message === 'response_too_large') {
      return jsonResponse(413, { error: 'response_too_large' });
    }
    if (error && error.message === 'not_icalendar') {
      return jsonResponse(415, { error: 'not_icalendar' });
    }
    return upstreamErrorResponse();
  }
}

module.exports = {
  handler,
  assertPublicUrl,
  fetchIcsText,
  icsResponse,
  extractSourceUrl,
  methodNotAllowedResponse,
  badRequestResponse,
  upstreamErrorResponse,
};
