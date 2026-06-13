import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'persistence_service.dart';

class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const _defaultCalendarTitle = 'Kwame and Laura';

  static String defaultCalendarId(String userId) => '${userId}_default';

  static DocumentReference<Map<String, dynamic>> _getDefaultCalendarDoc(
    String userId,
  ) {
    return _db.collection('calendars').doc(defaultCalendarId(userId));
  }

  static DocumentReference<Map<String, dynamic>> _getLegacyCalendarDoc(
    String userId,
  ) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('calendars')
        .doc('default');
  }

  static Future<void> saveState(String userId, SavedState state) async {
    try {
      final calendarDoc = _getDefaultCalendarDoc(userId);
      final existing = await calendarDoc.get();
      final now = state.updatedAtMillis == 0
          ? DateTime.now().millisecondsSinceEpoch
          : state.updatedAtMillis;

      final data = <String, dynamic>{
        ...state.toMap(),
        'calendarId': calendarDoc.id,
        'updatedAtMillis': now,
      };

      if (existing.exists) {
        data['memberUserIds'] = FieldValue.arrayUnion([userId]);
      } else {
        data.addAll({
          'title': _defaultCalendarTitle,
          'name': _defaultCalendarTitle,
          'ownerUserId': userId,
          'memberUserIds': [userId],
          'createdAtMillis': now,
        });
      }

      await calendarDoc.set(data, SetOptions(merge: true));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore saveState failed: $e');
      }
    }
  }

  static Future<SavedState?> loadState(String userId) async {
    try {
      var doc = await _getDefaultCalendarDoc(userId).get();
      if (!doc.exists) {
        doc = await _getLegacyCalendarDoc(userId).get();
      }
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
