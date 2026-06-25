'use strict';

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
  'halifax-municipal-news': {
    name: 'Halifax municipal news',
    url: 'https://www.halifax.ca/news/rss-feed',
  },
  'feed-nova-scotia-events': {
    name: 'Feed Nova Scotia events',
    url: 'https://feednovascotia.ca/events/feed/',
  },
});

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

function badRequestResponse() {
  return jsonResponse(400, { error: 'unknown_source' });
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

async function fetchFeedXml(feed, fetchImpl) {
  const response = await fetchImpl(feed.url, {
    headers: {
      Accept: 'application/rss+xml, application/atom+xml, text/xml',
      'User-Agent': 'LifeShuffleOutsideEvents/1.0',
    },
  });
  if (!response.ok) {
    throw new Error(`Feed returned ${response.status}`);
  }
  const body = await response.text();
  if (!body.trimStart().startsWith('<')) {
    throw new Error('Feed did not return XML');
  }
  return body;
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
  const feed = sourceId ? FEEDS[sourceId] : null;
  if (!feed) return badRequestResponse();

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
