'use strict';

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
    let credentials;
    try {
      credentials = JSON.parse(readCredentialsJson());
    } catch (error) {
      throw new Error('Firebase service account JSON could not be parsed.');
    }
    initializeApp({ credential: cert(credentials) });
  }

  return getFirestore();
}

function readTitle(data) {
  if (typeof data.title === 'string' && data.title.trim()) return data.title.trim();
  if (typeof data.name === 'string' && data.name.trim()) return data.name.trim();
  return '(untitled)';
}

function readMemberCount(data) {
  return Array.isArray(data.memberUserIds) ? data.memberUserIds.length : 0;
}

function previewToken(token) {
  if (typeof token !== 'string' || token.length === 0) return 'no';
  if (token.length <= 10) return 'yes (short token hidden)';
  return `yes (${token.slice(0, 6)}...${token.slice(-4)})`;
}

function hasString(value) {
  return typeof value === 'string' && value.length > 0;
}

async function main() {
  const db = initializeFirestore();
  const snapshot = await db.collection('calendars').get();

  if (snapshot.empty) {
    console.log('No calendars found. The web app has not successfully written to Firestore yet.');
    return;
  }

  console.log(`Calendars found: ${snapshot.size}`);
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    console.log('---');
    console.log(`documentId: ${doc.id}`);
    console.log(`calendarId: ${typeof data.calendarId === 'string' ? data.calendarId : '(missing)'}`);
    console.log(`title/name: ${readTitle(data)}`);
    console.log(`ownerUserId present: ${hasString(data.ownerUserId) ? 'yes' : 'no'}`);
    console.log(`member count: ${readMemberCount(data)}`);
    console.log(`feedEnabled: ${data.feedEnabled === true ? 'true' : 'false'}`);
    console.log(`hasFeedToken: ${previewToken(data.feedToken)}`);
    console.log(`hasCachedIcsText: ${hasString(data.cachedIcsText) ? 'yes' : 'no'}`);
    console.log(`cachedIcsUpdatedAtMillis: ${data.cachedIcsUpdatedAtMillis || '(missing)'}`);
    console.log(`updatedAtMillis: ${data.updatedAtMillis || '(missing)'}`);
  }
}

main().catch((error) => {
  console.error(`Firestore calendar diagnostic failed: ${error.message}`);
  process.exitCode = 1;
});
