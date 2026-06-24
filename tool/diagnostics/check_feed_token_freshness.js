'use strict';

// Read-only diagnostic for the `calendars` collection's published-feed
// fields. Surfaces two things that are otherwise invisible from the
// Firebase console:
//
// - Duplicate `feedToken` values across documents. The feed endpoint
//   (netlify/functions/calendar-feed.js) tolerates this by serving
//   whichever matching doc has the freshest `cachedIcsUpdatedAtMillis`,
//   but a duplicate is still a data hygiene issue worth resolving by hand
//   (revoke/regenerate the token on whichever doc shouldn't have it).
// - Owners with more than one calendar doc, which is useful context when
//   diagnosing "the feed looks stale" reports.
//
// Never logs a full feedToken - only a first6...last6 preview.
// Performs no writes.

const fs = require('node:fs');
const path = require('node:path');
const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const localServiceAccountPath = path.resolve(
  process.cwd(),
  'tool',
  'serviceAccountKey.json',
);

function readCredentialsJson() {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
    return process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  }
  if (fs.existsSync(localServiceAccountPath)) {
    return fs.readFileSync(localServiceAccountPath, 'utf8');
  }
  throw new Error(
    'Missing Firebase service account credentials. Set FIREBASE_SERVICE_ACCOUNT_JSON or save a local gitignored file at tool/serviceAccountKey.json.',
  );
}

function initializeFirestore() {
  if (getApps().length === 0) {
    const credentials = JSON.parse(readCredentialsJson());
    initializeApp({ credential: cert(credentials) });
  }
  return getFirestore();
}

function tokenPreview(token) {
  if (typeof token !== 'string' || token.length === 0) return '(none)';
  if (token.length <= 12) return `${token.slice(0, 3)}...${token.slice(-3)}`;
  return `${token.slice(0, 6)}...${token.slice(-6)}`;
}

/** Latest DTSTAMP found in a cached ICS body, or null if there isn't one. */
function latestDtstamp(icsText) {
  if (typeof icsText !== 'string') return null;
  const matches = [...icsText.matchAll(/DTSTAMP:(\d{8}T\d{6}Z)/g)].map(
    (m) => m[1],
  );
  if (matches.length === 0) return null;
  return matches.reduce((max, value) => (value > max ? value : max));
}

function summarizeDoc(doc) {
  const data = doc.data() || {};
  return {
    documentId: doc.id,
    calendarId: typeof data.calendarId === 'string' ? data.calendarId : null,
    title:
      typeof data.title === 'string' && data.title.trim()
        ? data.title.trim()
        : '(untitled)',
    ownerUserId:
      typeof data.ownerUserId === 'string' ? data.ownerUserId : null,
    feedEnabled: data.feedEnabled === true,
    feedToken: typeof data.feedToken === 'string' ? data.feedToken : null,
    updatedAtMillis:
      typeof data.updatedAtMillis === 'number' ? data.updatedAtMillis : null,
    cachedIcsUpdatedAtMillis:
      typeof data.cachedIcsUpdatedAtMillis === 'number'
        ? data.cachedIcsUpdatedAtMillis
        : null,
    cachedIcsLength:
      typeof data.cachedIcsText === 'string' ? data.cachedIcsText.length : 0,
    latestDtstamp: latestDtstamp(data.cachedIcsText),
  };
}

function printDocSummaries(docs) {
  console.log(`Calendar docs found: ${docs.length}`);
  console.log('===');
  for (const d of docs) {
    console.log(`documentId: ${d.documentId}`);
    console.log(`  calendarId: ${d.calendarId ?? '(missing)'}`);
    console.log(`  title: ${d.title}`);
    console.log(`  ownerUserId present: ${d.ownerUserId ? 'yes' : 'no'}`);
    console.log(`  feedEnabled: ${d.feedEnabled}`);
    console.log(`  feedToken: ${tokenPreview(d.feedToken)}`);
    console.log(`  updatedAtMillis: ${d.updatedAtMillis ?? '(missing)'}`);
    console.log(
      `  cachedIcsUpdatedAtMillis: ${d.cachedIcsUpdatedAtMillis ?? '(missing)'}`,
    );
    console.log(`  cachedIcsText length: ${d.cachedIcsLength}`);
    console.log(
      `  latest DTSTAMP in cachedIcsText: ${d.latestDtstamp ?? '(none)'}`,
    );
    console.log('---');
  }
}

function printDuplicateFeedTokens(docs) {
  const byToken = new Map();
  for (const d of docs) {
    if (!d.feedToken) continue;
    const list = byToken.get(d.feedToken) ?? [];
    list.push(d);
    byToken.set(d.feedToken, list);
  }
  const duplicates = [...byToken.entries()].filter(
    ([, list]) => list.length > 1,
  );

  console.log('=== Duplicate feedToken check ===');
  if (duplicates.length === 0) {
    console.log('No duplicate feedToken values found across calendar docs.');
    return;
  }
  for (const [token, list] of duplicates) {
    console.log(
      `Token ${tokenPreview(token)} is shared by ${list.length} docs: ${list
        .map((d) => `${d.documentId} (calendarId=${d.calendarId})`)
        .join(', ')}`,
    );
  }
  console.log(
    'Resolve by signing into the account that should not own this token ' +
      'and tapping Revoke token in Settings.',
  );
}

function printMultiCalendarOwners(docs) {
  const byOwner = new Map();
  for (const d of docs) {
    if (!d.ownerUserId) continue;
    const list = byOwner.get(d.ownerUserId) ?? [];
    list.push(d);
    byOwner.set(d.ownerUserId, list);
  }
  const multiCalendarOwners = [...byOwner.entries()].filter(
    ([, list]) => list.length > 1,
  );

  console.log('=== Same-owner multi-calendar check ===');
  if (multiCalendarOwners.length === 0) {
    console.log('No owner has more than one calendar doc.');
    return;
  }
  for (const [, list] of multiCalendarOwners) {
    console.log(`Owner (uid hidden) has ${list.length} calendar docs:`);
    for (const d of list) {
      console.log(
        `  - ${d.documentId} (calendarId=${d.calendarId}, title=${d.title}, feedEnabled=${d.feedEnabled}, feedToken=${tokenPreview(d.feedToken)}, cachedIcsUpdatedAtMillis=${d.cachedIcsUpdatedAtMillis ?? '(missing)'}, latestDtstamp=${d.latestDtstamp ?? '(none)'})`,
      );
    }
  }
}

async function main() {
  const db = initializeFirestore();
  const snapshot = await db.collection('calendars').get();

  if (snapshot.empty) {
    console.log('No calendar docs found.');
    return;
  }

  const docs = snapshot.docs.map(summarizeDoc);
  printDocSummaries(docs);
  printDuplicateFeedTokens(docs);
  printMultiCalendarOwners(docs);
}

main().catch((error) => {
  console.error(`Diagnostic failed: ${error.message}`);
  process.exitCode = 1;
});
