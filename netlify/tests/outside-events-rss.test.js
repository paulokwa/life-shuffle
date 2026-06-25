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
      queryStringParameters: { source: 'halifax-municipal-news' },
    },
    {
      fetch: async (url) => {
        assert.equal(url, rss.FEEDS['halifax-municipal-news'].url);
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

test('handler reports unavailable feeds cleanly', async () => {
  const response = await rss.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: { source: 'halifax-municipal-news' },
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
