import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'persistence_service.dart';

class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static DocumentReference _getCalendarDoc(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('calendars')
        .doc('default');
  }

  static Future<void> saveState(String userId, SavedState state) async {
    try {
      await _getCalendarDoc(userId).set(
        state.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore saveState failed: $e');
      }
    }
  }

  static Future<SavedState?> loadState(String userId) async {
    try {
      final doc = await _getCalendarDoc(userId).get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return null;
      return SavedState.fromMap(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore loadState failed: $e');
      }
      return null;
    }
  }
}
