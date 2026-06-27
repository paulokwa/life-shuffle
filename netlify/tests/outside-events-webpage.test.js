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
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 1);
  assert.equal(payload.events[0].sourceType, 'webPage');
  assert.match(payload.warnings.join('\n'), /AI organizer not configured/);
});

test('combineDateTime builds a local Date from date/time strings', () => {
  const value = webpage.combineDateTime('2026-07-04', '18:30');
  assert.equal(value.getFullYear(), 2026);
  assert.equal(value.getMonth(), 6);
  assert.equal(value.getDate(), 4);
  assert.equal(value.getHours(), 18);
  assert.equal(value.getMinutes(), 30);

  const noTime = webpage.combineDateTime('2026-07-04', null);
  assert.equal(noTime.getHours(), 12);

  assert.equal(webpage.combineDateTime(null, '18:30'), null);
  assert.equal(webpage.combineDateTime('not-a-date', '18:30'), null);
});

test('chunkText splits long text and caps the number of chunks', () => {
  const text = 'a'.repeat(25000);
  const chunks = webpage.chunkText(text, 6000, 4);
  assert.equal(chunks.length, 4);
  assert.equal(chunks[0].length, 6000);
});

test('mapAiEventItem marks unknown fields as uncertain instead of inventing them', () => {
  const mapped = webpage.mapAiEventItem({
    item: {
      title: 'Garden concert',
      startDate: '2026-07-03',
      startTime: null,
      venue: null,
      address: null,
      price: null,
      confidence: 0.42,
      uncertainFields: [],
    },
    sourceId: 'src-1',
    sourceName: 'Venue page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
    provider: 'openai',
  });

  assert.ok(mapped);
  assert.equal(mapped.venueName, undefined);
  assert.equal(mapped.priceLabel, undefined);
  assert.deepEqual(mapped.missingFields, ['address', 'price', 'time', 'venue']);
  assert.equal(mapped.confidence, 0.42);
  assert.equal(mapped.raw.extractionMode, 'ai-openai-webpage');
});

test('mapAiEventItem rejects events outside the requested range', () => {
  const mapped = webpage.mapAiEventItem({
    item: { title: 'Out of range', startDate: '2026-08-01' },
    sourceId: 'src-1',
    sourceName: 'Venue page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
    provider: 'openai',
  });

  assert.equal(mapped, null);
});

test('extractEventsWithAiOrFallback calls OpenAI when OPENAI_API_KEY is set', async () => {
  let calledUrl = null;
  const extraction = await webpage.extractEventsWithAiOrFallback({
    text: 'Garden concert July 3, 2026 at 7pm. Free outdoor music at Victoria Park.',
    sourceId: 'src-1',
    sourceName: 'Venue page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
    env: { OPENAI_API_KEY: 'test-key' },
    fetchImpl: async (url, init) => {
      calledUrl = url;
      assert.match(url, /api\.openai\.com/);
      assert.equal(init.method, 'POST');
      assert.match(init.headers.Authorization, /Bearer test-key/);
      return {
        ok: true,
        json: async () => ({
          choices: [
            {
              message: {
                content: JSON.stringify({
                  events: [
                    {
                      title: 'Garden concert',
                      summary: 'Free outdoor music.',
                      startDate: '2026-07-03',
                      startTime: '19:00',
                      venue: 'Victoria Park',
                      address: null,
                      price: 'Free',
                      ticketUrl: null,
                      tags: ['music', 'outdoors'],
                      confidence: 0.9,
                      uncertainFields: ['address'],
                    },
                  ],
                }),
              },
            },
          ],
        }),
      };
    },
  });

  assert.ok(calledUrl);
  assert.equal(extraction.aiConfigured, true);
  assert.equal(extraction.events.length, 1);
  assert.equal(extraction.events[0].raw.extractionMode, 'ai-openai-webpage');
  assert.equal(extraction.events[0].venueName, 'Victoria Park');
  assert.equal(extraction.events[0].priceLabel, 'Free');
  assert.equal(extraction.events[0].isFree, true);
  assert.deepEqual(extraction.events[0].missingFields, ['address']);
});

test('extractEventsWithAiOrFallback calls Gemini when only GEMINI_API_KEY is set', async () => {
  const extraction = await webpage.extractEventsWithAiOrFallback({
    text: 'Library night July 2, 2026 at 6pm. A community event.',
    sourceId: 'src-2',
    sourceName: 'Library page',
    sourceUrl: 'https://example.com/library',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
    env: { GEMINI_API_KEY: 'gem-key' },
    fetchImpl: async (url) => {
      assert.match(url, /generativelanguage\.googleapis\.com/);
      assert.match(url, /key=gem-key/);
      return {
        ok: true,
        json: async () => ({
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: JSON.stringify({
                      events: [
                        {
                          title: 'Library night',
                          startDate: '2026-07-02',
                          startTime: '18:00',
                          venue: 'Central Library',
                          confidence: 0.8,
                          uncertainFields: [],
                        },
                      ],
                    }),
                  },
                ],
              },
            },
          ],
        }),
      };
    },
  });

  assert.equal(extraction.aiConfigured, true);
  assert.equal(extraction.events.length, 1);
  assert.equal(extraction.events[0].raw.extractionMode, 'ai-gemini-webpage');
});

test('extractEventsWithAiOrFallback falls back to deterministic extraction when AI fails', async () => {
  const extraction = await webpage.extractEventsWithAiOrFallback({
    text: 'Neighbourhood Market July 2, 2026 at 6:00pm Free local food and music.',
    sourceId: 'src-3',
    sourceName: 'Community page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
    env: { OPENAI_API_KEY: 'test-key' },
    fetchImpl: async () => ({ ok: false, status: 500 }),
  });

  assert.equal(extraction.aiConfigured, true);
  assert.equal(extraction.events.length, 1);
  assert.equal(
    extraction.events[0].raw.extractionMode,
    'deterministic-webpage-fallback',
  );
  assert.match(extraction.warnings.join('\n'), /could not extract events/);
});

test('extractEventsWithAi merges and dedupes events across multiple chunks', async () => {
  const longText = `Garden concert July 3, 2026 at 7pm. Free music.${' filler'.repeat(2000)}`;
  let calls = 0;
  const result = await webpage.extractEventsWithAi({
    text: longText,
    provider: 'openai',
    apiKey: 'test-key',
    model: 'gpt-4o-mini',
    sourceId: 'src-4',
    sourceName: 'Venue page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
    fetchImpl: async () => {
      calls += 1;
      return {
        ok: true,
        json: async () => ({
          choices: [
            {
              message: {
                content: JSON.stringify({
                  events: [
                    {
                      title: 'Garden concert',
                      startDate: '2026-07-03',
                      startTime: '19:00',
                      venue: 'Victoria Park',
                      confidence: 0.7,
                      uncertainFields: [],
                    },
                  ],
                }),
              },
            },
          ],
        }),
      };
    },
  });

  assert.ok(calls > 1);
  assert.equal(result.failed, false);
  assert.equal(result.events.length, 1);
});

// ---- Known-source resolvers ----------------------------------------------

test('findSourceResolver detects NSCC event detail URLs and ignores others', () => {
  const resolver = webpage.findSourceResolver(
    'https://www.nscc.ca/alumni/get-involved/events/eventdetails.aspx?eventid=6574&recurs=0&rd=1782577800000',
  );
  assert.ok(resolver);
  assert.equal(resolver.id, 'nscc');

  assert.equal(webpage.findSourceResolver('https://example.com/events/123'), null);
  assert.equal(
    webpage.findSourceResolver('https://www.nscc.ca/alumni/get-involved/events/eventdetails.aspx'),
    null,
  );
});

test('handler resolves NSCC URLs via the NSCC web API and normalizes the JSON', async () => {
  const nsccUrl =
    'https://www.nscc.ca/alumni/get-involved/events/eventdetails.aspx?eventid=6574&recurs=0&rd=1782577800000';
  const apiUrl = 'https://webapi.nscc.ca/nsccapi/api/events/event/6574';
  const fetchedUrls = [];

  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: nsccUrl,
        start: '2026-06-01T00:00:00Z',
        end: '2026-07-01T23:59:59Z',
      },
    },
    {
      lookup: publicLookup,
      fetch: async (url) => {
        fetchedUrls.push(url);
        if (url === apiUrl) {
          return {
            ok: true,
            status: 200,
            headers: { get: () => null },
            text: async () =>
              JSON.stringify({
                EventId: 6574,
                Name: 'Truro Pride Parade',
                Summary: 'Celebrate Pride with NSCC',
                DateStart: '2026-06-27T13:30:00',
                DateEnd: '2026-06-27T14:30:00',
                OffsiteLocation: 'Truro, Nova Scotia',
                IsPublished: true,
              }),
          };
        }
        return { ok: false, status: 404 };
      },
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 1);
  assert.equal(payload.events[0].title, 'Truro Pride Parade');
  assert.equal(payload.events[0].venueName, 'Truro, Nova Scotia');
  assert.equal(payload.events[0].raw.extractionMode, 'deterministic-json');
  assert.ok(fetchedUrls.includes(apiUrl));
  assert.ok(!fetchedUrls.includes(nsccUrl));
});

test('handler returns no events when the NSCC API responds with unusable data', async () => {
  const nsccUrl =
    'https://www.nscc.ca/alumni/get-involved/events/eventdetails.aspx?eventid=9999';

  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: nsccUrl,
        start: '2026-06-01T00:00:00Z',
        end: '2026-07-01T23:59:59Z',
      },
    },
    {
      lookup: publicLookup,
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () => JSON.stringify({ EventId: 9999, IsPublished: false }),
      }),
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 0);
});

// ---- Structured data extraction -------------------------------------------

test('extractEventLikeJsonBlobs parses NSCC-shaped JSON via generic field aliases', () => {
  const json = JSON.stringify({
    Name: 'Test Event',
    DateStart: '2026-06-27T13:30:00',
    Summary: 'Test Summary',
    OffsiteLocation: 'Test Venue',
  });

  const events = webpage.extractEventLikeJsonBlobs(json, {
    sourceId: 'src-1',
    sourceName: 'NSCC',
    sourceUrl: 'https://example.com',
    rangeStart: new Date('2026-01-01'),
    rangeEnd: new Date('2026-12-31'),
  });

  assert.equal(events.length, 1);
  assert.equal(events[0].title, 'Test Event');
  assert.equal(events[0].venueName, 'Test Venue');
  assert.equal(events[0].raw.extractionMode, 'deterministic-json');
});

test('extractJsonLdEvents extracts schema.org Event markup from a webpage', () => {
  const html = `
    <html><head>
    <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"Event","name":"Garden Concert",
       "startDate":"2026-07-03T19:00:00","endDate":"2026-07-03T21:00:00",
       "description":"Free outdoor music in the park.",
       "location":{"@type":"Place","name":"City Park","address":"123 Main St, Halifax"},
       "offers":{"price":"0","priceCurrency":"CAD"}}
    </script>
    </head><body></body></html>
  `;

  const events = webpage.extractJsonLdEvents(html, {
    sourceId: 'src-1',
    sourceName: 'Venue page',
    sourceUrl: 'https://example.com/events',
    city: 'Halifax',
    rangeStart: new Date('2026-07-01T00:00:00'),
    rangeEnd: new Date('2026-07-07T23:59:00'),
  });

  assert.equal(events.length, 1);
  assert.equal(events[0].title, 'Garden Concert');
  assert.equal(events[0].venueName, 'City Park');
  assert.equal(events[0].address, '123 Main St, Halifax');
  assert.equal(events[0].raw.extractionMode, 'deterministic-json-ld');
});

test('handler extracts events from JSON-LD on a normal (non-resolver) webpage', async () => {
  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: 'https://example.com/events',
        start: '2026-07-01T00:00:00',
        end: '2026-07-07T23:59:00',
      },
    },
    {
      lookup: publicLookup,
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () =>
          '<html><script type="application/ld+json">' +
          '{"@type":"Event","name":"Market Day","startDate":"2026-07-02T10:00:00"}' +
          '</script></html>',
      }),
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 1);
  assert.equal(payload.events[0].title, 'Market Day');
  assert.equal(payload.events[0].raw.extractionMode, 'deterministic-json-ld');
});

test('handler falls back to existing AI/deterministic extraction when no resolver matches and no structured data is present', async () => {
  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: 'https://example.com/events',
        start: '2026-07-01T00:00:00',
        end: '2026-07-07T23:59:00',
      },
    },
    {
      lookup: publicLookup,
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () =>
          '<article><h2>Garden concert July 3, 2026 at 7pm</h2><p>Free outdoor music.</p></article>',
      }),
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 1);
  assert.equal(payload.events[0].raw.extractionMode, 'deterministic-webpage-fallback');
});

// ---- Known listing-only sources --------------------------------------------

test('findListingOnlyNoDateSource detects The Coast event search URLs and ignores others', () => {
  const source = webpage.findListingOnlyNoDateSource(
    'https://community.thecoast.ca/halifax/EventSearch?narrowByDate=2026-06-26-to-2027-01-01&sortType=date&v=g',
  );
  assert.ok(source);
  assert.equal(source.id, 'thecoast-community-events');

  assert.equal(
    webpage.findListingOnlyNoDateSource('https://example.com/events'),
    null,
  );
});

test('handler returns a specific diagnostic for The Coast listing pages instead of a generic "no events" warning', async () => {
  const listingHtml =
    '<html><body>' +
    '<div class="fdn-event-search-text-block"><a href="/halifax/girls-day-out/Event?oid=1">Girls Day Out</a></div>' +
    '<div class="fdn-event-search-text-block"><a href="/halifax/market/Event?oid=2">Market Day</a></div>' +
    '</body></html>';

  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: 'https://community.thecoast.ca/halifax/EventSearch?narrowByDate=2026-06-26-to-2027-01-01&sortType=date&v=g',
        start: '2026-07-01T00:00:00',
        end: '2026-07-07T23:59:00',
      },
    },
    {
      lookup: publicLookup,
      fetch: async () => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () => listingHtml,
      }),
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.events.length, 0);
  assert.equal(payload.warnings.length, 1);
  assert.match(payload.warnings[0], /2 event card\(s\) visible/);
  assert.match(payload.warnings[0], /no dated events were found on the listing/);
  assert.match(payload.warnings[0], /detail page has the date/);
});

// ---- Same-domain pagination ------------------------------------------------

test('findNextPageUrl follows a same-origin ?page=N+1 link', () => {
  const html =
    '<a href="https://example.com/events?page=2">2</a>' +
    '<a href="https://example.com/events?page=3">3</a>';
  const next = webpage.findNextPageUrl(html, 'https://example.com/events');
  assert.equal(next, 'https://example.com/events?page=2');
});

test('findNextPageUrl advances from the current page number, not always page 2', () => {
  const html = '<a href="https://example.com/events?page=4">4</a>';
  const next = webpage.findNextPageUrl(
    html,
    'https://example.com/events?page=3',
  );
  assert.equal(next, 'https://example.com/events?page=4');
});

test('findNextPageUrl ignores cross-origin links even if the page param matches', () => {
  const html = '<a href="https://other.example.com/events?page=2">2</a>';
  const next = webpage.findNextPageUrl(html, 'https://example.com/events');
  assert.equal(next, null);
});

test('findNextPageUrl ignores links whose only difference is non-numeric', () => {
  const html =
    '<a href="https://example.com/events?sortType=name">By name</a>';
  const next = webpage.findNextPageUrl(
    html,
    'https://example.com/events?sortType=date',
  );
  assert.equal(next, null);
});

test('findNextPageUrl returns null when there is no next-page link', () => {
  const html = '<a href="https://example.com/about">About</a>';
  const next = webpage.findNextPageUrl(html, 'https://example.com/events');
  assert.equal(next, null);
});

test('fetchPaginatedPages follows links across pages and stops when no more are found', async () => {
  const pageHtml = (page, hasNext) =>
    `<p>page ${page}</p>` +
    (hasNext
      ? `<a href="https://example.com/events?page=${page + 1}">next</a>`
      : '');
  const fetched = [];
  const fetchImpl = async (url) => {
    fetched.push(url);
    const page = Number.parseInt(new URL(url).searchParams.get('page') || '1', 10);
    return {
      ok: true,
      status: 200,
      headers: { get: () => null },
      text: async () => pageHtml(page, page < 3),
    };
  };

  const pages = await webpage.fetchPaginatedPages({
    firstUrl: 'https://example.com/events',
    firstHtml: pageHtml(1, true),
    fetchImpl,
  });

  assert.equal(pages.length, 3);
  assert.equal(pages[1].url, 'https://example.com/events?page=2');
  assert.equal(pages[2].url, 'https://example.com/events?page=3');
  assert.equal(fetched.length, 2);
});

test('fetchPaginatedPages caps at MAX_ADDITIONAL_PAGES even if more links exist', async () => {
  const fetchImpl = async (url) => {
    const page = Number.parseInt(new URL(url).searchParams.get('page') || '1', 10);
    return {
      ok: true,
      status: 200,
      headers: { get: () => null },
      text: async () =>
        `<a href="https://example.com/events?page=${page + 1}">next</a>`,
    };
  };

  const pages = await webpage.fetchPaginatedPages({
    firstUrl: 'https://example.com/events',
    firstHtml: '<a href="https://example.com/events?page=2">next</a>',
    fetchImpl,
  });

  assert.equal(pages.length, 1 + webpage.MAX_ADDITIONAL_PAGES);
});

test('fetchPaginatedPages returns only the first page when there is no pagination link', async () => {
  let calls = 0;
  const fetchImpl = async () => {
    calls += 1;
    return { ok: true, status: 200, headers: { get: () => null }, text: async () => '<p>only page</p>' };
  };

  const pages = await webpage.fetchPaginatedPages({
    firstUrl: 'https://example.com/events',
    firstHtml: '<p>only page</p>',
    fetchImpl,
  });

  assert.equal(pages.length, 1);
  assert.equal(calls, 0);
});

test('handler merges JSON-LD events found across paginated pages', async () => {
  const page1Html =
    '<script type="application/ld+json">' +
    '{"@type":"Event","name":"Page one show","startDate":"2026-07-02T19:00:00"}' +
    '</script>' +
    '<a href="https://example.com/events?page=2">next</a>';
  const page2Html =
    '<script type="application/ld+json">' +
    '{"@type":"Event","name":"Page two show","startDate":"2026-07-04T19:00:00"}' +
    '</script>';

  const response = await webpage.handler(
    {
      httpMethod: 'GET',
      queryStringParameters: {
        url: 'https://example.com/events',
        start: '2026-07-01T00:00:00',
        end: '2026-07-07T23:59:00',
      },
    },
    {
      lookup: publicLookup,
      fetch: async (url) => ({
        ok: true,
        status: 200,
        headers: { get: () => null },
        text: async () =>
          new URL(url).searchParams.get('page') === '2' ? page2Html : page1Html,
      }),
      env: {},
    },
  );

  assert.equal(response.statusCode, 200);
  const payload = JSON.parse(response.body);
  assert.equal(payload.pagesFetched, 2);
  assert.equal(payload.events.length, 2);
  assert.deepEqual(
    payload.events.map((event) => event.title).sort(),
    ['Page one show', 'Page two show'],
  );
});
