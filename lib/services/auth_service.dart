import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  AuthService._();

  static bool _ready = false;

  static bool get isReady => _ready;
  static void markReady() => _ready = true;

  static Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await FirebaseAuth.instance.signInWithPopup(provider);
    } else {
      await FirebaseAuth.instance.signInWithRedirect(provider);
    }
  }

  static Future<void> signOut() async {
    if (!_ready) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  static User? get currentUser => _ready ? FirebaseAuth.instance.currentUser : null;
}
