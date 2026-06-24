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
  findCalendarByFeedToken,
  pickFreshestCalendar,
} = require('../functions/calendar-feed');

/**
 * Minimal fake of the chained Firestore query builder
 * (`collection().where().get()`) used by `findCalendarByFeedToken`.
 * Records every `where`/`orderBy`/`limit` call so tests can assert exactly
 * which query shape was built, without touching real Firestore.
 */
function fakeDb(matchingDocs) {
  const calls = { where: [], orderBy: [], limit: [] };
  const query = {
    where(...args) {
      calls.where.push(args);
      return query;
    },
    orderBy(...args) {
      calls.orderBy.push(args);
      return query;
    },
    limit(...args) {
      calls.limit.push(args);
      return query;
    },
    async get() {
      return {
        empty: matchingDocs.length === 0,
        docs: matchingDocs.map((data) => ({ data: () => data })),
      };
    },
  };
  return { collection: () => query, calls };
}

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

test('pickFreshestCalendar returns the only candidate when there is just one', () => {
  const only = { calendarId: 'a', cachedIcsUpdatedAtMillis: 100 };
  assert.equal(pickFreshestCalendar([only]), only);
});

test('pickFreshestCalendar prefers the candidate with the highest cachedIcsUpdatedAtMillis, regardless of input order', () => {
  const stale = { calendarId: 'old', cachedIcsUpdatedAtMillis: 100 };
  const fresh = { calendarId: 'new', cachedIcsUpdatedAtMillis: 200 };
  assert.equal(pickFreshestCalendar([stale, fresh]), fresh);
  assert.equal(pickFreshestCalendar([fresh, stale]), fresh);
});

test('pickFreshestCalendar treats a missing cachedIcsUpdatedAtMillis as oldest', () => {
  const neverCached = { calendarId: 'never' };
  const cached = { calendarId: 'cached', cachedIcsUpdatedAtMillis: 1 };
  assert.equal(pickFreshestCalendar([neverCached, cached]), cached);
  assert.equal(pickFreshestCalendar([cached, neverCached]), cached);
});

test('findCalendarByFeedToken returns null when no doc matches the token', async () => {
  const db = fakeDb([]);
  assert.equal(await findCalendarByFeedToken(db, 'tok'), null);
});

test('findCalendarByFeedToken returns the single matching doc', async () => {
  const data = { calendarId: 'solo', feedToken: 'tok', cachedIcsUpdatedAtMillis: 5 };
  const db = fakeDb([data]);
  assert.equal(await findCalendarByFeedToken(db, 'tok'), data);
});

test('findCalendarByFeedToken queries by feedToken equality only - no orderBy/limit, so no composite Firestore index is required', async () => {
  const db = fakeDb([{ calendarId: 'solo', cachedIcsUpdatedAtMillis: 1 }]);
  await findCalendarByFeedToken(db, 'tok');
  assert.deepEqual(db.calls.where, [['feedToken', '==', 'tok']]);
  assert.deepEqual(db.calls.orderBy, []);
  assert.deepEqual(db.calls.limit, []);
});

test('findCalendarByFeedToken resolves duplicate feedToken docs (e.g. two different accounts that shared a device) by returning the one with the freshest cached feed', async () => {
  const stale = {
    calendarId: 'owner_a_default',
    feedToken: 'shared-tok',
    cachedIcsUpdatedAtMillis: 1000,
    cachedIcsText: 'stale ics',
  };
  const fresh = {
    calendarId: 'owner_b_default',
    feedToken: 'shared-tok',
    cachedIcsUpdatedAtMillis: 2000,
    cachedIcsText: 'fresh ics',
  };
  const db = fakeDb([stale, fresh]);
  assert.equal(await findCalendarByFeedToken(db, 'shared-tok'), fresh);

  // Order returned by Firestore is not guaranteed - must still pick fresh
  // when it happens to come first too.
  const dbReversed = fakeDb([fresh, stale]);
  assert.equal(await findCalendarByFeedToken(dbReversed, 'shared-tok'), fresh);
});
