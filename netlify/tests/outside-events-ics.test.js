'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const ics = require('../functions/outside-events-ics');

const publicLookup = async () => [{ address: '93.184.216.34', family: 4 }];

test('extractSourceUrl trims url query parameter', () => {
  assert.equal(
    ics.extractSourceUrl({ url: ' https://example.com/events/?ical=1 ' }),
    'https://example.com/events/?ical=1',
  );
  assert.equal(ics.extractSourceUrl({ url: ' ' }), null);
  assert.equal(ics.extractSourceUrl({}), null);
});

test('handler rejects non-GET methods', async () => {
  const response = await ics.handler({ httpMethod: 'POST' }, {});

  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, 'GET');
});

test('handler rejects requests with no url', async () => {
  const response = await ics.handler(
    { httpMethod: 'GET', queryStringParameters: {} },
    {},
  );

  assert.equal(response.statusCode, 400);
  assert.deepEqual(JSON.parse(response.body), { error: 'missing_url' });
});

test('handler proxies a validated ICS feed URL', async () => {
  const icsBody = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    'SUMMARY:Test Event',
    'DTSTART:20260701T180000Z',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');

  const response = await ics.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { url: 'https://example.com/events/?ical=1' },
    },
    {
      lookup: publicLookup,
      fetch: async (url) => {
        assert.equal(url, 'https://example.com/events/?ical=1');
        return {
          ok: true,
          status: 200,
          headers: { get: () => null },
          text: async () => icsBody,
        };
      },
    },
  );

  assert.equal(response.statusCode, 200);
  assert.match(response.headers['Content-Type'], /text\/calendar/);
  assert.equal(response.body, icsBody);
});

test('handler blocks private feed URLs', async () => {
  const response = await ics.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { url: 'http://localhost/events.ics' },
    },
    {
      lookup: async () => [{ address: '127.0.0.1', family: 4 }],
    },
  );

  assert.equal(response.statusCode, 400);
  assert.deepEqual(JSON.parse(response.body), { error: 'private_url' });
});

test('handler reports unavailable feeds cleanly', async () => {
  const response = await ics.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { url: 'https://example.com/events.ics' },
    },
    {
      lookup: publicLookup,
      fetch: async () => ({ ok: false, status: 503, headers: { get: () => null } }),
    },
  );

  assert.equal(response.statusCode, 502);
  assert.deepEqual(JSON.parse(response.body), { error: 'feed_unavailable' });
});

test('handler rejects a response that is not actually an iCalendar file', async () => {
  const response = await ics.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { url: 'https://example.com/not-ics' },
    },
    {
      lookup: publicLookup,
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () => '<html>not a calendar</html>',
      }),
    },
  );

  assert.equal(response.statusCode, 415);
  assert.deepEqual(JSON.parse(response.body), { error: 'not_icalendar' });
});
