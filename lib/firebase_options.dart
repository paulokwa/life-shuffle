// ─────────────────────────────────────────────────────────────────────────────
// STUB — replace this file by running:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// Steps before running that command:
//   1. Go to console.firebase.google.com and create a project.
//   2. Add a Web app inside the project.
//   3. Under Authentication > Sign-in method, enable Google.
//   4. Run `flutterfire configure` — it will overwrite this file with real values.
//
// Until the real file is in place, the app runs in local-only mode
// (no sign-in prompt; the full local planner loop still works).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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

  // Replace all REPLACE_ME values by running: flutterfire configure

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDpB3IANRhHvoyxsq0JBF6vuTReR65Yhm8',
    appId: '1:461306833305:web:d942b45b46e816ff110b08',
    messagingSenderId: '461306833305',
    projectId: 'life-shuffle-8d3bd',
    authDomain: 'life-shuffle-8d3bd.firebaseapp.com',
    storageBucket: 'life-shuffle-8d3bd.firebasestorage.app',
  );
}
