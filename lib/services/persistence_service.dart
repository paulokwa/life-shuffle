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
  static const _keyCalendarTitle = 'ls_calendar_title';
  static const _keyCalendarNameConfirmed = 'ls_calendar_name_confirmed';
  static const _keyDifficultyEnabled = 'ls_difficulty_enabled';
  static const _keyEnergyEnabled = 'ls_energy_enabled';
  static const _keySocialEnabled = 'ls_social_enabled';
  static const _keyDefaultDifficulty = 'ls_default_difficulty';
  static const _keyDefaultEnergy = 'ls_default_energy';
  static const _keyDefaultSocial = 'ls_default_social';
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
    final calendarTitle = _prefs.getString(_keyCalendarTitle);
    final calendarNameConfirmed =
        _prefs.getBool(_keyCalendarNameConfirmed) ?? false;
    final difficultyEnabled = _prefs.getBool(_keyDifficultyEnabled) ?? false;
    final energyEnabled = _prefs.getBool(_keyEnergyEnabled) ?? false;
    final socialEnabled = _prefs.getBool(_keySocialEnabled) ?? false;
    final defaultDifficulty = _prefs.getInt(_keyDefaultDifficulty) ?? 3;
    final defaultEnergy = _prefs.getString(_keyDefaultEnergy) ?? 'medium';
    final defaultSocial = _prefs.getString(_keyDefaultSocial) ?? 'either';
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
      calendarTitle: calendarTitle,
      calendarNameConfirmed: calendarNameConfirmed,
      difficultyEnabled: difficultyEnabled,
      energyEnabled: energyEnabled,
      socialEnabled: socialEnabled,
      defaultDifficulty: defaultDifficulty,
      defaultEnergy: defaultEnergy,
      defaultSocial: defaultSocial,
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

  static void saveCalendarTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      _prefs.remove(_keyCalendarTitle);
      return;
    }
    _prefs.setString(_keyCalendarTitle, value.trim());
  }

  static void saveCalendarNameConfirmed(bool value) =>
      _prefs.setBool(_keyCalendarNameConfirmed, value);

  static void saveDifficultyEnabled(bool value) =>
      _prefs.setBool(_keyDifficultyEnabled, value);

  static void saveEnergyEnabled(bool value) =>
      _prefs.setBool(_keyEnergyEnabled, value);

  static void saveSocialEnabled(bool value) =>
      _prefs.setBool(_keySocialEnabled, value);

  static void saveDefaultDifficulty(int value) =>
      _prefs.setInt(_keyDefaultDifficulty, value.clamp(1, 5).toInt());

  static void saveDefaultEnergy(String value) =>
      _prefs.setString(_keyDefaultEnergy, value.trim().toLowerCase());

  static void saveDefaultSocial(String value) =>
      _prefs.setString(_keyDefaultSocial, value.trim().toLowerCase());

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
    this.calendarTitle,
    this.calendarNameConfirmed = false,
    this.difficultyEnabled = false,
    this.energyEnabled = false,
    this.socialEnabled = false,
    this.defaultDifficulty = 3,
    this.defaultEnergy = 'medium',
    this.defaultSocial = 'either',
  });

  final List<Activity> activities;
  final int seed;
  final int updatedAtMillis;
  final String planStyle;
  final String? displayName;
  final bool displayNameConfirmed;
  final String? calendarTitle;
  final bool calendarNameConfirmed;
  final bool difficultyEnabled;
  final bool energyEnabled;
  final bool socialEnabled;
  final int defaultDifficulty;
  final String defaultEnergy;
  final String defaultSocial;
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
      'calendarTitle': calendarTitle,
      'calendarNameConfirmed': calendarNameConfirmed,
      'difficultyEnabled': difficultyEnabled,
      'energyEnabled': energyEnabled,
      'socialEnabled': socialEnabled,
      'defaultDifficulty': defaultDifficulty,
      'defaultEnergy': defaultEnergy,
      'defaultSocial': defaultSocial,
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
      displayNameConfirmed: _readBool(map['displayNameConfirmed']),
      calendarTitle: _readNullableString(map['calendarTitle']),
      calendarNameConfirmed: _readBool(map['calendarNameConfirmed']),
      difficultyEnabled: _readBool(map['difficultyEnabled']),
      energyEnabled: _readBool(map['energyEnabled']),
      socialEnabled: _readBool(map['socialEnabled']),
      defaultDifficulty: _readBoundedInt(
        map['defaultDifficulty'],
        fallback: 3,
        min: 1,
        max: 5,
      ),
      defaultEnergy: _readOption(
        map['defaultEnergy'],
        fallback: 'medium',
        allowed: const ['low', 'medium', 'high'],
      ),
      defaultSocial: _readOption(
        map['defaultSocial'],
        fallback: 'either',
        allowed: const ['solo', 'together', 'group', 'either'],
      ),
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

  static int _readBoundedInt(
    Object? value, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final read = _readInt(value);
    final candidate = read == 0 ? fallback : read;
    return candidate.clamp(min, max).toInt();
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _readBool(Object? value) => value is bool ? value : false;

  static String _readOption(
    Object? value, {
    required String fallback,
    required List<String> allowed,
  }) {
    if (value is! String) return fallback;
    final normalized = value.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
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
