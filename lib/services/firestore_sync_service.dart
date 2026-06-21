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

  static DocumentReference<Map<String, dynamic>> _getCalendarDoc(
    String calendarId,
  ) {
    return _db.collection('calendars').doc(calendarId);
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

  static Future<FirestoreSyncResult> saveState(
    String userId,
    SavedState state, {
    String? calendarId,
  }) async {
    try {
      final targetCalendarId =
          _normalizeCalendarId(calendarId) ?? defaultCalendarId(userId);
      final calendarDoc = _getCalendarDoc(targetCalendarId);
      final existing = await calendarDoc.get();
      if (!existing.exists && targetCalendarId != defaultCalendarId(userId)) {
        return FirestoreSyncResult.failure('Selected calendar unavailable');
      }
      final now = state.updatedAtMillis == 0
          ? DateTime.now().millisecondsSinceEpoch
          : state.updatedAtMillis;

      final data = <String, dynamic>{
        ...state.toMap(),
        'calendarId': calendarDoc.id,
        'updatedAtMillis': now,
      };
      final stateTitle = state.calendarTitle?.trim();
      final calendarTitle = stateTitle == null || stateTitle.isEmpty
          ? defaultCalendarTitle
          : stateTitle;

      if (existing.exists) {
        data['title'] = calendarTitle;
        data['name'] = calendarTitle;
      } else {
        data.addAll({
          'title': calendarTitle,
          'name': calendarTitle,
          'ownerUserId': userId,
          'memberUserIds': [userId],
          'createdAtMillis': now,
        });
      }

      await calendarDoc.set(data, SetOptions(merge: true));
      return FirestoreSyncResult.success();
    } on FirebaseException catch (e) {
      final result = FirestoreSyncResult.failure(_safeErrorMessage(e));
      if (kDebugMode) {
        debugPrint('Firestore saveState failed: ${e.code}');
      }
      return result;
    } catch (e) {
      final result = FirestoreSyncResult.failure('Unknown sync error');
      if (kDebugMode) {
        debugPrint('Firestore saveState failed: $e');
      }
      return result;
    }
  }

  static Future<SavedState?> loadState(String userId) async {
    final calendar = await loadDefaultCalendar(userId);
    return calendar?.state;
  }

  static Future<List<FirestoreCalendar>> loadAccessibleCalendars(
    String userId,
  ) async {
    try {
      final snapshot = await _db
          .collection('calendars')
          .where('memberUserIds', arrayContains: userId)
          .get();
      final calendars = snapshot.docs.map((doc) {
        final data = doc.data();
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
      }).toList()
        ..sort((a, b) {
          final defaultId = defaultCalendarId(userId);
          if (a.metadata.calendarId == defaultId) return -1;
          if (b.metadata.calendarId == defaultId) return 1;
          return a.metadata.title
              .toLowerCase()
              .compareTo(b.metadata.title.toLowerCase());
        });
      return calendars;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore loadAccessibleCalendars failed: $e');
      }
      return const [];
    }
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

  static Future<FirestoreSyncResult> upsertUserProfile({
    required String userId,
    String? email,
    String? displayName,
  }) async {
    try {
      final emailLower = _normalizeEmail(email);
      final trimmedDisplayName = displayName?.trim();
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.collection('userProfiles').doc(userId).set(
        <String, dynamic>{
          'uid': userId,
          if (emailLower != null) 'emailLower': emailLower,
          if (trimmedDisplayName != null && trimmedDisplayName.isNotEmpty)
            'displayName': trimmedDisplayName,
          'updatedAtMillis': now,
        },
        SetOptions(merge: true),
      );
      return FirestoreSyncResult.success();
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore upsertUserProfile failed: ${e.code}');
      }
      return FirestoreSyncResult.failure(_safeErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore upsertUserProfile failed: $e');
      }
      return FirestoreSyncResult.failure('Unknown sync error');
    }
  }

  static Future<UserProfile?> findUserProfileByEmail(String email) async {
    final emailLower = _normalizeEmail(email);
    if (emailLower == null) return null;
    try {
      final snapshot = await _db
          .collection('userProfiles')
          .where('emailLower', isEqualTo: emailLower)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final profile = UserProfile.fromMap(snapshot.docs.first.data());
      return profile.uid.isEmpty ? null : profile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore findUserProfileByEmail failed: $e');
      }
      return null;
    }
  }

  static Future<List<UserProfile>> loadUserProfilesByIds(
    List<String> userIds,
  ) async {
    final uniqueIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return const [];

    try {
      final profiles = <UserProfile>[];
      for (var start = 0; start < uniqueIds.length; start += 10) {
        final end =
            start + 10 > uniqueIds.length ? uniqueIds.length : start + 10;
        final chunk = uniqueIds.sublist(start, end);
        final snapshot = await _db
            .collection('userProfiles')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        profiles.addAll(
          snapshot.docs
              .map((doc) => UserProfile.fromMap(doc.data()))
              .where((profile) => profile.uid.isNotEmpty),
        );
      }
      return profiles;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore loadUserProfilesByIds failed: $e');
      }
      return const [];
    }
  }

  static Future<AddCalendarMemberResult> addMemberByEmail({
    required String calendarId,
    required String email,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null) {
      return AddCalendarMemberResult.failure('Enter an email address.');
    }

    final profile = await findUserProfileByEmail(normalizedEmail);
    if (profile == null) {
      return AddCalendarMemberResult.notFound(
        'Laura needs to sign in once before she can be added.',
      );
    }

    try {
      final calendar = await _getCalendarDoc(calendarId).get();
      final data = calendar.data();
      final existingMembers = data == null
          ? const <String>[]
          : CalendarMetadata._readStringList(data['memberUserIds'], const []);
      if (existingMembers.contains(profile.uid)) {
        return AddCalendarMemberResult.alreadyMember(profile);
      }

      await _getCalendarDoc(calendarId).update({
        'memberUserIds': FieldValue.arrayUnion([profile.uid]),
        'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
      return AddCalendarMemberResult.success(profile);
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore addMemberByEmail failed: ${e.code}');
      }
      return AddCalendarMemberResult.failure(_safeErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Firestore addMemberByEmail failed: $e');
      }
      return AddCalendarMemberResult.failure('Unknown sync error');
    }
  }

  static String? _normalizeCalendarId(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizeEmail(String? value) {
    final trimmed = value?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty || !trimmed.contains('@')) {
      return null;
    }
    return trimmed;
  }
}

class FirestoreSyncResult {
  const FirestoreSyncResult._({
    required this.succeeded,
    required this.status,
    this.errorMessage,
  });

  factory FirestoreSyncResult.success() {
    return const FirestoreSyncResult._(
      succeeded: true,
      status: 'Last sync succeeded',
    );
  }

  factory FirestoreSyncResult.failure(String safeMessage) {
    return FirestoreSyncResult._(
      succeeded: false,
      status: safeMessage,
      errorMessage: safeMessage,
    );
  }

  final bool succeeded;
  final String status;
  final String? errorMessage;
}

class AddCalendarMemberResult {
  const AddCalendarMemberResult._({
    required this.succeeded,
    required this.status,
    this.profile,
    this.alreadyMember = false,
  });

  factory AddCalendarMemberResult.success(UserProfile profile) {
    return AddCalendarMemberResult._(
      succeeded: true,
      status: '${profile.displayLabel} added.',
      profile: profile,
    );
  }

  factory AddCalendarMemberResult.alreadyMember(UserProfile profile) {
    final label =
        profile.displayLabel.isEmpty ? 'That person' : profile.displayLabel;
    return AddCalendarMemberResult._(
      succeeded: true,
      status: '$label is already a member.',
      profile: profile,
      alreadyMember: true,
    );
  }

  factory AddCalendarMemberResult.notFound(String safeMessage) {
    return AddCalendarMemberResult._(
      succeeded: false,
      status: safeMessage,
    );
  }

  factory AddCalendarMemberResult.failure(String safeMessage) {
    return AddCalendarMemberResult._(
      succeeded: false,
      status: safeMessage,
    );
  }

  final bool succeeded;
  final String status;
  final UserProfile? profile;
  final bool alreadyMember;
}

String _safeErrorMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Firestore permission denied';
    case 'unauthenticated':
      return 'Firebase unavailable';
    case 'unavailable':
      return 'Firebase unavailable';
    default:
      return 'Unknown sync error';
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

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.emailLower,
    this.displayName,
  });

  final String uid;
  final String emailLower;
  final String? displayName;

  String get displayLabel {
    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) return trimmedName;
    return emailLower;
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: CalendarMetadata._readString(map['uid'], ''),
      emailLower: CalendarMetadata._readString(map['emailLower'], ''),
      displayName: CalendarMetadata._readNullableString(map['displayName']),
    );
  }
}

class CalendarMetadata {
  const CalendarMetadata({
    required this.calendarId,
    required this.title,
    required this.ownerUserId,
    required this.memberUserIds,
    required this.createdAtMillis,
    required this.updatedAtMillis,
    this.feedEnabled = false,
    this.feedToken,
    this.feedCreatedAtMillis,
    this.feedUpdatedAtMillis,
    this.feedRevokedAtMillis,
  });

  final String calendarId;
  final String title;
  final String ownerUserId;
  final List<String> memberUserIds;
  final int createdAtMillis;
  final int updatedAtMillis;
  final bool feedEnabled;
  final String? feedToken;
  final int? feedCreatedAtMillis;
  final int? feedUpdatedAtMillis;
  final int? feedRevokedAtMillis;

  CalendarMetadata copyWith({
    String? calendarId,
    String? title,
    String? ownerUserId,
    List<String>? memberUserIds,
    int? createdAtMillis,
    int? updatedAtMillis,
    bool? feedEnabled,
    String? feedToken,
    int? feedCreatedAtMillis,
    int? feedUpdatedAtMillis,
    int? feedRevokedAtMillis,
  }) {
    return CalendarMetadata(
      calendarId: calendarId ?? this.calendarId,
      title: title ?? this.title,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      memberUserIds: memberUserIds ?? this.memberUserIds,
      createdAtMillis: createdAtMillis ?? this.createdAtMillis,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
      feedEnabled: feedEnabled ?? this.feedEnabled,
      feedToken: feedToken ?? this.feedToken,
      feedCreatedAtMillis: feedCreatedAtMillis ?? this.feedCreatedAtMillis,
      feedUpdatedAtMillis: feedUpdatedAtMillis ?? this.feedUpdatedAtMillis,
      feedRevokedAtMillis: feedRevokedAtMillis ?? this.feedRevokedAtMillis,
    );
  }

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
      feedEnabled: _readBool(map['feedEnabled'] ?? map['isPublished']),
      feedToken: _readNullableString(map['feedToken']),
      feedCreatedAtMillis: _readNullableInt(map['feedCreatedAtMillis']),
      feedUpdatedAtMillis: _readNullableInt(map['feedUpdatedAtMillis']),
      feedRevokedAtMillis: _readNullableInt(map['feedRevokedAtMillis']),
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

  static int? _readNullableInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return null;
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _readBool(Object? value) => value is bool ? value : false;
}
