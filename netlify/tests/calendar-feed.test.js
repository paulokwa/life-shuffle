'use strict';

// Uses Node's built-in test runner (node --test) so these run with zero
// extra dependencies. No real Firestore/Admin SDK access happens here -
// the pure helpers are tested directly, and `handler` is only exercised
// for the paths that don't require live credentials.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  handler,
  extractToken,
  isFeedEnabled,
  buildFeedResponse,
} = require('../functions/calendar-feed');

test('extractToken reads and trims the token query param', () => {
  assert.equal(extractToken({ token: ' abc123 ' }), 'abc123');
});

test('extractToken returns null when missing, blank, or absent', () => {
  assert.equal(extractToken(undefined), null);
  assert.equal(extractToken({}), null);
  assert.equal(extractToken({ token: '' }), null);
  assert.equal(extractToken({ token: '   ' }), null);
});

test('isFeedEnabled reads feedEnabled, falling back to legacy isPublished', () => {
  assert.equal(isFeedEnabled(null), false);
  assert.equal(isFeedEnabled({}), false);
  assert.equal(isFeedEnabled({ feedEnabled: false }), false);
  assert.equal(isFeedEnabled({ feedEnabled: true }), true);
  assert.equal(isFeedEnabled({ isPublished: true }), true);
  assert.equal(isFeedEnabled({ feedEnabled: false, isPublished: true }), true);
});

test('buildFeedResponse returns cached ICS text with calendar headers when enabled', () => {
  const response = buildFeedResponse({
    feedEnabled: true,
    feedToken: 'tok',
    cachedIcsText: 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
  });

  assert.equal(response.statusCode, 200);
  assert.equal(
    response.headers['Content-Type'],
    'text/calendar; charset=utf-8; method=PUBLISH',
  );
  assert.match(response.headers['Cache-Control'], /private/);
  assert.match(response.headers['Content-Disposition'], /life-shuffle\.ics/);
  assert.equal(response.body, 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n');
});

test('buildFeedResponse 404s for a calendar that was never published', () => {
  assert.equal(buildFeedResponse(null).statusCode, 404);
  assert.equal(buildFeedResponse(undefined).statusCode, 404);
});

test('buildFeedResponse 404s for a disabled feed even though the token still matched', () => {
  const response = buildFeedResponse({
    feedEnabled: false,
    feedToken: 'still-here',
    cachedIcsText: 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n',
  });
  assert.equal(response.statusCode, 404);
});

test('buildFeedResponse 404s when enabled but no cached ICS exists yet', () => {
  assert.equal(buildFeedResponse({ feedEnabled: true }).statusCode, 404);
  assert.equal(
    buildFeedResponse({ feedEnabled: true, cachedIcsText: '' }).statusCode,
    404,
  );
});

test('buildFeedResponse never reveals which specific reason caused the 404', () => {
  const neverPublished = buildFeedResponse(null);
  const disabled = buildFeedResponse({ feedEnabled: false });
  const noCacheYet = buildFeedResponse({ feedEnabled: true });

  assert.deepEqual(neverPublished, disabled);
  assert.deepEqual(disabled, noCacheYet);
});

test('handler 404s when the token query param is missing', async () => {
  const response = await handler({
    httpMethod: 'GET',
    queryStringParameters: {},
  });
  assert.equal(response.statusCode, 404);
});

test('handler 404s when there is no query string at all', async () => {
  const response = await handler({ httpMethod: 'GET' });
  assert.equal(response.statusCode, 404);
});

test('handler rejects non-GET methods with 405', async () => {
  const response = await handler({
    httpMethod: 'POST',
    queryStringParameters: { token: 'x' },
  });
  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, 'GET');
});

test('handler returns 500 when Firestore admin credentials are not configured', async () => {
  // This test environment never sets FIREBASE_SERVICE_ACCOUNT_JSON, so a
  // request with a real-looking token should fail closed with a generic
  // 500 rather than crashing the function or leaking the missing-env error.
  assert.equal(process.env.FIREBASE_SERVICE_ACCOUNT_JSON, undefined);

  const response = await handler({
    httpMethod: 'GET',
    queryStringParameters: { token: 'some-token' },
  });
  assert.equal(response.statusCode, 500);
});
