import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'persistence_service.dart';
import 'planner_service.dart';

class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const defaultCalendarTitle = 'Kwame and Laura';

  static String defaultCalendarId(String userId) => '${userId}_default';

  static CalendarMetadata defaultMetadata(String userId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return CalendarMetadata(
      calendarId: defaultCalendarId(userId),
      title: defaultCalendarTitle,
      ownerUserId: userId,
      memberUserIds: [userId],
      createdAtMillis: now,
      updatedAtMillis: now,
    );
  }

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
          'title': defaultCalendarTitle,
          'name': defaultCalendarTitle,
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
    final calendar = await loadDefaultCalendar(userId);
    return calendar?.state;
  }

  static Future<FirestoreCalendar?> loadDefaultCalendar(String userId) async {
    try {
      var doc = await _getDefaultCalendarDoc(userId).get();
      if (!doc.exists) {
        doc = await _getLegacyCalendarDoc(userId).get();
      }
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return FirestoreCalendar(
        state: SavedState.fromMap(
          data,
          fallbackActivities: PlannerService.defaultActivities,
        ),
        metadata: CalendarMetadata.fromMap(
          data,
          fallback: defaultMetadata(userId),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore loadState failed: $e');
      }
      return null;
    }
  }
}

class FirestoreCalendar {
  const FirestoreCalendar({
    required this.state,
    required this.metadata,
  });

  final SavedState state;
  final CalendarMetadata metadata;
}

class CalendarMetadata {
  const CalendarMetadata({
    required this.calendarId,
    required this.title,
    required this.ownerUserId,
    required this.memberUserIds,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  final String calendarId;
  final String title;
  final String ownerUserId;
  final List<String> memberUserIds;
  final int createdAtMillis;
  final int updatedAtMillis;

  factory CalendarMetadata.fromMap(
    Map<String, dynamic> map, {
    required CalendarMetadata fallback,
  }) {
    return CalendarMetadata(
      calendarId: _readString(map['calendarId'], fallback.calendarId),
      title: _readString(map['title'] ?? map['name'], fallback.title),
      ownerUserId: _readString(map['ownerUserId'], fallback.ownerUserId),
      memberUserIds: _readStringList(
        map['memberUserIds'],
        fallback.memberUserIds,
      ),
      createdAtMillis: _readInt(
        map['createdAtMillis'],
        fallback.createdAtMillis,
      ),
      updatedAtMillis: _readInt(
        map['updatedAtMillis'],
        fallback.updatedAtMillis,
      ),
    );
  }

  static String _readString(Object? value, String fallback) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  static List<String> _readStringList(Object? value, List<String> fallback) {
    if (value is Iterable) {
      final values = value.whereType<String>().toList();
      if (values.isNotEmpty) return values;
    }
    return fallback;
  }

  static int _readInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }
}
