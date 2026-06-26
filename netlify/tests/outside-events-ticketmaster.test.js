'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const ticketmaster = require('../functions/outside-events-ticketmaster');

test('handler rejects non-GET methods', async () => {
  const response = await ticketmaster.handler({ httpMethod: 'POST' }, {});

  assert.equal(response.statusCode, 405);
  assert.equal(response.headers.Allow, 'GET');
});

test('handler reports unconfigured state when TICKETMASTER_API_KEY is missing', async () => {
  const response = await ticketmaster.handler(
    { httpMethod: 'GET', queryStringParameters: {} },
    { env: {} },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.configured, false);
  assert.deepEqual(payload.events, []);
  assert.match(payload.warnings.join('\n'), /not configured/);
});

test('handler fetches and maps live Ticketmaster events when configured', async () => {
  let requestedUrl = null;
  const response = await ticketmaster.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        city: 'Halifax',
        start: '2026-07-01T00:00:00.000Z',
        end: '2026-07-07T00:00:00.000Z',
      },
    },
    {
      env: { TICKETMASTER_API_KEY: 'tm-key' },
      fetch: async (url) => {
        requestedUrl = url;
        return {
          ok: true,
          json: async () => ({
            _embedded: {
              events: [
                {
                  id: 'evt-1',
                  name: 'Garden concert',
                  url: 'https://ticketmaster.example/evt-1',
                  dates: { start: { dateTime: '2026-07-03T23:00:00Z' } },
                  priceRanges: [{ min: 20, max: 60, currency: 'CAD' }],
                  classifications: [
                    { segment: { name: 'Music' }, genre: { name: 'Rock' } },
                  ],
                  _embedded: {
                    venues: [
                      {
                        name: 'Scotiabank Centre',
                        city: { name: 'Halifax' },
                        address: { line1: '1800 Argyle Street' },
                      },
                    ],
                  },
                },
              ],
            },
          }),
        };
      },
    },
  );

  assert.equal(response.statusCode, 200);
  assert.match(requestedUrl, /apikey=tm-key/);
  assert.match(requestedUrl, /city=Halifax/);
  const payload = JSON.parse(response.body);
  assert.equal(payload.configured, true);
  assert.equal(payload.events.length, 1);
  const [mapped] = payload.events;
  assert.equal(mapped.title, 'Garden concert');
  assert.equal(mapped.venueName, 'Scotiabank Centre');
  assert.equal(mapped.address, '1800 Argyle Street');
  assert.equal(mapped.priceLabel, '$20-$60 CAD');
  assert.deepEqual(mapped.tags, ['music', 'rock']);
  assert.equal(mapped.sourceType, 'ticketmaster');
  assert.equal(mapped.raw.extractionMode, 'ticketmaster-api');
});

test('handler reports upstream errors without throwing', async () => {
  const response = await ticketmaster.handler(
    { httpMethod: 'GET', queryStringParameters: {} },
    {
      env: { TICKETMASTER_API_KEY: 'tm-key' },
      fetch: async () => ({ ok: false, status: 500 }),
    },
  );

  assert.equal(response.statusCode, 502);
  const payload = JSON.parse(response.body);
  assert.equal(payload.configured, true);
  assert.match(payload.warnings.join('\n'), /HTTP 500/);
});

test('mapEvent skips events with no name or no start date', () => {
  assert.equal(ticketmaster.mapEvent({}, 'Halifax'), null);
  assert.equal(
    ticketmaster.mapEvent({ name: 'No date event' }, 'Halifax'),
    null,
  );
});
