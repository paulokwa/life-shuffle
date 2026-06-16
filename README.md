# life-shuffle
Mobile-first Flutter app for planning personal activities, generating rule-based calendars, and helping users get unstuck.

## Local dev setup

The Firebase web API key is not committed to the repo (GitHub secret scanning flags committed Google API keys). It's passed in at build time via `--dart-define`:

```
flutter run -d chrome --web-port 8769 --dart-define=FIREBASE_WEB_API_KEY=your-key-here
flutter build web --dart-define=FIREBASE_WEB_API_KEY=your-key-here
```

Without the key, the app falls back to local-only mode (no sign-in, full local planner still works). Get the key from Firebase Console → Project settings → General → Web app, or ask whoever holds the project credentials.

To avoid retyping the key, copy `tool/local_run.ps1.example` to `tool/local_run.ps1` (gitignored) and fill in your key there.

## Netlify

Netlify build reads the key from a `FIREBASE_WEB_API_KEY` environment variable (Site settings → Environment variables) and passes it through in `netlify.toml`. Never put the real key in `netlify.toml` itself.
