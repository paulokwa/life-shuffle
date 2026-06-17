import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';

/// Lightweight local storage for in-session state.
/// Wraps SharedPreferences (localStorage on web).
/// Call [init] once in main() before creating AppState.
class PersistenceService {
  PersistenceService._();

  static late SharedPreferences _prefs;

  static const _keyActivities = 'ls_activities';
  static const _keySeed = 'ls_seed';
  static const _keyUpdatedAtMillis = 'ls_updated_at_millis';
  static const _keyPlanStyle = 'ls_plan_style';
  static const _keyDisplayName = 'ls_display_name';
  static const _keyDisplayNameConfirmed = 'ls_display_name_confirmed';
  static const _pfxEnabled = 'ls_en_';
  static const _pfxCheckin = 'ls_ci_';
  static const _pfxLocked = 'ls_lk_';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SavedState load(List<Activity> defaultActivities) {
    final activities = _loadActivities(defaultActivities);
    final seed = _prefs.getInt(_keySeed) ?? 0;
    final updatedAtMillis = _prefs.getInt(_keyUpdatedAtMillis) ?? 0;
    final displayName = _prefs.getString(_keyDisplayName);
    final displayNameConfirmed =
        _prefs.getBool(_keyDisplayNameConfirmed) ?? false;
    final enabledMap = <String, bool>{};
    final checkinMap = <String, int>{};
    final lockedMap = <String, bool>{};

    for (final activity in activities) {
      final enabled = _prefs.getBool('$_pfxEnabled${activity.id}');
      if (enabled != null) {
        enabledMap[activity.id] = enabled;
        activity.enabled = enabled;
      }

      final checkin = _prefs.getInt('$_pfxCheckin${activity.id}');
      if (checkin != null) checkinMap[activity.id] = checkin;

      final locked = _prefs.getBool('$_pfxLocked${activity.id}');
      if (locked != null) lockedMap[activity.id] = locked;
    }

    final planStyle = _prefs.getString(_keyPlanStyle) ?? 'balanced';

    return SavedState(
      activities: activities,
      seed: seed,
      updatedAtMillis: updatedAtMillis,
      planStyle: planStyle,
      displayName: displayName,
      displayNameConfirmed: displayNameConfirmed,
      enabledMap: enabledMap,
      checkinMap: checkinMap,
      lockedMap: lockedMap,
    );
  }

  static void saveActivities(List<Activity> activities) => _prefs.setString(
        _keyActivities,
        jsonEncode(activities.map((activity) => activity.toMap()).toList()),
      );

  static void saveSeed(int seed) => _prefs.setInt(_keySeed, seed);

  static void savePlanStyle(String value) =>
      _prefs.setString(_keyPlanStyle, value);

  static void saveDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      _prefs.remove(_keyDisplayName);
      return;
    }
    _prefs.setString(_keyDisplayName, value.trim());
  }

  static void saveDisplayNameConfirmed(bool value) =>
      _prefs.setBool(_keyDisplayNameConfirmed, value);

  static void saveUpdatedAtMillis(int value) =>
      _prefs.setInt(_keyUpdatedAtMillis, value);

  static void saveEnabled(String id, bool value) =>
      _prefs.setBool('$_pfxEnabled$id', value);

  static void saveCheckin(String id, int value) =>
      _prefs.setInt('$_pfxCheckin$id', value);

  static void saveLocked(String id, bool value) =>
      _prefs.setBool('$_pfxLocked$id', value);

  static List<Activity> _loadActivities(List<Activity> defaultActivities) {
    final raw = _prefs.getString(_keyActivities);
    if (raw == null || raw.isEmpty) {
      return defaultActivities.map((activity) => activity.copy()).toList();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final activities = decoded
            .whereType<Map>()
            .map((map) => Activity.fromMap(Map<String, dynamic>.from(map)))
            .toList();
        if (activities.isNotEmpty) return activities;
      }
    } catch (_) {
      // Fall through to starter activities if local activity JSON is invalid.
    }

    return defaultActivities.map((activity) => activity.copy()).toList();
  }
}

class SavedState {
  const SavedState({
    required this.activities,
    required this.seed,
    required this.updatedAtMillis,
    required this.enabledMap,
    required this.checkinMap,
    required this.lockedMap,
    this.planStyle = 'balanced',
    this.displayName,
    this.displayNameConfirmed = false,
  });

  final List<Activity> activities;
  final int seed;
  final int updatedAtMillis;
  final String planStyle;
  final String? displayName;
  final bool displayNameConfirmed;
  final Map<String, bool> enabledMap;
  final Map<String, int> checkinMap;
  final Map<String, bool> lockedMap;

  Map<String, dynamic> toMap() {
    return {
      'activities': activities.map((activity) => activity.toMap()).toList(),
      'seed': seed,
      'updatedAtMillis': updatedAtMillis,
      'planStyle': planStyle,
      'displayName': displayName,
      'displayNameConfirmed': displayNameConfirmed,
      'enabledMap': enabledMap,
      'checkinMap': checkinMap,
      'lockedMap': lockedMap,
    };
  }

  factory SavedState.fromMap(
    Map<String, dynamic> map, {
    List<Activity> fallbackActivities = const [],
  }) {
    return SavedState(
      activities: _readActivities(map['activities'], fallbackActivities),
      seed: _readInt(map['seed']),
      updatedAtMillis: _readInt(map['updatedAtMillis']),
      planStyle: (map['planStyle'] as String?) ?? 'balanced',
      displayName: _readNullableString(map['displayName']),
      displayNameConfirmed: map['displayNameConfirmed'] is bool
          ? map['displayNameConfirmed'] as bool
          : false,
      enabledMap: Map<String, bool>.from(map['enabledMap'] ?? {}),
      checkinMap: Map<String, int>.from(map['checkinMap'] ?? {}),
      lockedMap: Map<String, bool>.from(map['lockedMap'] ?? {}),
    );
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<Activity> _readActivities(
    Object? value,
    List<Activity> fallbackActivities,
  ) {
    if (value is Iterable) {
      final activities = value
          .whereType<Map>()
          .map((map) => Activity.fromMap(Map<String, dynamic>.from(map)))
          .toList();
      if (activities.isNotEmpty) return activities;
    }
    return fallbackActivities.map((activity) => activity.copy()).toList();
  }
}
