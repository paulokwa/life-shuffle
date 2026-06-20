'use strict';

// Read-only, token-gated .ics feed for a published Life Shuffle calendar.
//
// This function does not run the planner. It only looks up a calendar
// document by `feedToken` and serves whatever ICS text the Flutter app
// already cached in `cachedIcsText` (see lib/state/app_state.dart
// `_refreshCachedIcs()` and docs/ICS_FEED_ENDPOINT_PLAN.md section 0).
//
// I/O (Firestore access) lives only in `findCalendarByFeedToken` and
// `handler`. Every other exported function below is pure and can be
// unit-tested without Firebase credentials - see netlify/tests/calendar-feed.test.js.

// firebase-admin v14 dropped the old namespaced `admin.firestore()` /
// `admin.credential.cert()` / `admin.apps` API in favor of these modular
// subpath imports.
const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const CALENDARS_COLLECTION = 'calendars';
const ICS_CONTENT_TYPE = 'text/calendar; charset=utf-8; method=PUBLISH';
const ICS_FILENAME = 'life-shuffle.ics';
const ICS_CACHE_CONTROL = 'private, max-age=900, must-revalidate';

let cachedDb = null;

function getFirestoreDb() {
  if (cachedDb) return cachedDb;

  if (getApps().length === 0) {
    const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    if (!raw) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not set');
    }

    let credentials;
    try {
      credentials = JSON.parse(raw);
    } catch (error) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON');
    }

    initializeApp({ credential: cert(credentials) });
  }

  cachedDb = getFirestore();
  return cachedDb;
}

function jsonResponse(statusCode, payload, extraHeaders) {
  return {
    statusCode,
    headers: { 'Content-Type': 'application/json', ...(extraHeaders || {}) },
    body: JSON.stringify(payload),
  };
}

function methodNotAllowedResponse() {
  return jsonResponse(405, { error: 'method_not_allowed' }, { Allow: 'GET' });
}

// Used for every "this feed is not available" case: no token, token never
// existed, feed disabled, token revoked, or no cached ICS yet. They are all
// deliberately indistinguishable from the outside - see
// docs/ICS_FEED_ENDPOINT_PLAN.md section 4 (never reveal *why* a feed 404s).
function notFoundResponse() {
  return jsonResponse(404, { error: 'not_found' });
}

function internalErrorResponse() {
  return jsonResponse(500, { error: 'internal_error' });
}

function icsResponse(icsText) {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': ICS_CONTENT_TYPE,
      'Content-Disposition': `inline; filename="${ICS_FILENAME}"`,
      'Cache-Control': ICS_CACHE_CONTROL,
    },
    body: icsText,
  };
}

/** Reads and trims the `token` query param. Returns null if missing/blank. */
function extractToken(queryStringParameters) {
  const token = queryStringParameters && queryStringParameters.token;
  if (typeof token !== 'string') return null;
  const trimmed = token.trim();
  return trimmed.length === 0 ? null : trimmed;
}

/**
 * A calendar's feed only counts as enabled if `feedEnabled` is true, falling
 * back to the legacy `isPublished` field - matches the same fallback in
 * `CalendarMetadata.fromMap` (lib/services/firestore_sync_service.dart).
 */
function isFeedEnabled(calendarData) {
  if (!calendarData) return false;
  return (
    calendarData.feedEnabled === true || calendarData.isPublished === true
  );
}

/**
 * Pure decision function: given the matching calendar document's data (or
 * null/undefined when no doc was found for the token), decides what to send
 * back. No Firestore/network access happens here.
 */
function buildFeedResponse(calendarData) {
  if (!isFeedEnabled(calendarData)) return notFoundResponse();

  const icsText = calendarData.cachedIcsText;
  if (typeof icsText !== 'string' || icsText.length === 0) {
    return notFoundResponse();
  }

  return icsResponse(icsText);
}

/** Looks up a calendar by feedToken. No index needed - see plan doc section 3. */
async function findCalendarByFeedToken(db, token) {
  const snapshot = await db
    .collection(CALENDARS_COLLECTION)
    .where('feedToken', '==', token)
    .limit(1)
    .get();
  return snapshot.empty ? null : snapshot.docs[0].data();
}

async function handler(event) {
  if (event.httpMethod !== 'GET') {
    return methodNotAllowedResponse();
  }

  const token = extractToken(event.queryStringParameters);
  if (!token) {
    return notFoundResponse();
  }

  try {
    const db = getFirestoreDb();
    const calendarData = await findCalendarByFeedToken(db, token);
    return buildFeedResponse(calendarData);
  } catch (error) {
    // Deliberately do not log the token itself - see plan doc section 4.
    console.error('calendar-feed function error:', error && error.message);
    return internalErrorResponse();
  }
}

module.exports = {
  handler,
  extractToken,
  isFeedEnabled,
  buildFeedResponse,
  findCalendarByFeedToken,
  methodNotAllowedResponse,
  notFoundResponse,
  internalErrorResponse,
  icsResponse,
};
