'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const webpage = require('../functions/outside-events-webpage');

const publicLookup = async () => [{ address: '93.184.216.34', family: 4 }];

test('handler rejects non-GET methods', async () => {
  const response = await webpage.handler({ httpMethod: 'POST' }, {});

  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, 'GET');
});

test('assertPublicUrl blocks localhost and private IPs', async () => {
  await assert.rejects(
    () => webpage.assertPublicUrl('http://localhost/events', publicLookup),
    /private_url/,
  );
  await assert.rejects(
    () => webpage.assertPublicUrl('https://192.168.1.10/events', publicLookup),
    /private_url/,
  );
});

test('cleanHtml strips scripts and keeps readable text', () => {
  const text = webpage.cleanHtml(
    '<html><script>bad()</script><h1>Events</h1><p>Market July 2 at 6pm</p></html>',
  );

  assert.equal(text.includes('bad()'), false);
  assert.match(text, /Events/);
  assert.match(text, /Market July 2 at 6pm/);
});

test('extractDeterministicEvents returns EventSuggestion-shaped JSON', () => {
  const events = webpage.extractDeterministicEvents({
    text: 'Neighbourhood Market July 2, 2026 at 6:00pm Free local food and music.',
    sourceId: 'src-1',
    sourceName: 'Community page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
  });

  assert.equal(events.length, 1);
  assert.equal(events[0].sourceType, 'webPage');
  assert.equal(events[0].sourceName, 'Community page');
  assert.equal(events[0].priceLabel, 'Free');
  assert.equal(events[0].raw.extractionMode, 'deterministic-webpage-fallback');
});

test('handler fetches a public webpage and returns extracted events', async () => {
  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: 'https://example.com/events',
        sourceId: 'web-fixture',
        sourceName: 'Fixture events',
        city: 'Halifax',
        start: '2026-07-01T00:00:00',
        end: '2026-07-07T23:59:00',
      },
    },
    {
      lookup: publicLookup,
      fetch: async (url) => {
        assert.equal(url, 'https://example.com/events');
        return {
          ok: true,
          status: 200,
          headers: { get: () => null },
          text: async () =>
            '<article><h2>Garden concert July 3, 2026 at 7pm</h2><p>Free outdoor music.</p></article>',
        };
      },
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 1);
  assert.equal(payload.events[0].sourceType, 'webPage');
  assert.match(payload.warnings.join('\n'), /AI organizer not configured/);
});
