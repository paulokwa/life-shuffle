'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const rss = require('../functions/outside-events-rss');

test('extractSourceId trims source query parameter', () => {
  assert.equal(
    rss.extractSourceId({ source: ' the-coast-arts-music ' }),
    'the-coast-arts-music',
  );
  assert.equal(rss.extractSourceId({ source: ' ' }), null);
  assert.equal(rss.extractSourceId({}), null);
});

test('handler rejects non-GET methods', async () => {
  const response = await rss.handler({ httpMethod: 'POST' }, {});

  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, 'GET');
});

test('handler rejects unknown sources instead of proxying arbitrary URLs', async () => {
  const response = await rss.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { source: 'https://example.com/feed.xml' },
    },
    {},
  );

  assert.equal(response.statusCode, 400);
  assert.deepEqual(JSON.parse(response.body), { error: 'unknown_source' });
});

test('handler returns XML for a curated source', async () => {
  const response = await rss.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { source: 'discover-halifax-events' },
    },
    {
      fetch: async (url) => {
        assert.equal(url, rss.FEEDS['discover-halifax-events'].url);
        return {
          ok: true,
          status: 200,
          text: async () => '<?xml version="1.0"?><rss></rss>',
        };
      },
    },
  );

  assert.equal(response.statusCode, 200);
  assert.match(response.headers['Content-Type'], /application\/xml/);
  assert.equal(response.body, '<?xml version="1.0"?><rss></rss>');
});

test('handler can proxy a validated user feed URL', async () => {
  const response = await rss.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { url: 'https://example.com/events/feed.xml' },
    },
    {
      lookup: async () => [{ address: '93.184.216.34', family: 4 }],
      fetch: async (url) => {
        assert.equal(url, 'https://example.com/events/feed.xml');
        return {
          ok: true,
          status: 200,
          headers: { get: () => null },
          text: async () => '<?xml version="1.0"?><rss></rss>',
        };
      },
    },
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body, '<?xml version="1.0"?><rss></rss>');
});

test('handler blocks private user feed URLs', async () => {
  const response = await rss.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { url: 'http://localhost/feed.xml' },
    },
    {
      lookup: async () => [{ address: '127.0.0.1', family: 4 }],
    },
  );

  assert.equal(response.statusCode, 400);
  assert.deepEqual(JSON.parse(response.body), { error: 'private_url' });
});

test('handler reports unavailable feeds cleanly', async () => {
  const response = await rss.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { source: 'discover-halifax-events' },
    },
    {
      fetch: async () => ({
        ok: false,
        status: 503,
        text: async () => 'nope',
      }),
    },
  );

  assert.equal(response.statusCode, 502);
  assert.deepEqual(JSON.parse(response.body), { error: 'feed_unavailable' });
});
