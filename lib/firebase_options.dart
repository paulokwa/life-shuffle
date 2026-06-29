// ─────────────────────────────────────────────────────────────────────────────
// Firebase project identifiers for life-shuffle-8d3bd.
//
// The web API key is NOT stored here. GitHub secret scanning flags Google API
// keys committed to source, so it is injected at build time instead:
//
//   flutter run -d chrome --dart-define=FIREBASE_WEB_API_KEY=your-key-here
//   flutter build web --dart-define=FIREBASE_WEB_API_KEY=your-key-here
//
// See README.md for local setup and netlify.toml for the Netlify build, which
// reads FIREBASE_WEB_API_KEY from a Netlify environment variable.
//
// If FIREBASE_WEB_API_KEY is not supplied, apiKey is empty and main.dart
// skips Firebase init, falling back to local-only mode.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      default:
        throw UnsupportedError(
          'Run flutterfire configure to generate platform options.',
        );
    }
  }

  static const String webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: webApiKey,
    appId: '1:461306833305:web:d942b45b46e816ff110b08',
    messagingSenderId: '461306833305',
    projectId: 'life-shuffle-8d3bd',
    authDomain: 'life-shuffle-8d3bd.firebaseapp.com',
    storageBucket: 'life-shuffle-8d3bd.firebasestorage.app',
  );
}
