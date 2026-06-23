import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';
import '../models/day_plan.dart' show OccurrenceOverride;
import '../models/manual_plan_item.dart';
import '../models/range_type.dart';

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
  static const _keyRangeType = 'ls_range_type';
  static const _keyViewMode = 'ls_view_mode';
  static const _keyRangeStartMillis = 'ls_range_start_millis';
  static const _keyDisplayName = 'ls_display_name';
  static const _keyDisplayNameConfirmed = 'ls_display_name_confirmed';
  static const _keyCalendarTitle = 'ls_calendar_title';
  static const _keySelectedCalendarId = 'ls_selected_calendar_id';
  static const _keyCalendarNameConfirmed = 'ls_calendar_name_confirmed';
  static const _keyIntroOnboardingCompleted = 'ls_intro_onboarding_completed';
  static const _keyDifficultyEnabled = 'ls_difficulty_enabled';
  static const _keyEnergyEnabled = 'ls_energy_enabled';
  static const _keySocialEnabled = 'ls_social_enabled';
  static const _keyDefaultDifficulty = 'ls_default_difficulty';
  static const _keyDefaultEnergy = 'ls_default_energy';
  static const _keyDefaultSocial = 'ls_default_social';
  static const _keyFeedEnabled = 'ls_feed_enabled';
  static const _keyFeedToken = 'ls_feed_token';
  static const _keyFeedCreatedAtMillis = 'ls_feed_created_at_millis';
  static const _keyFeedUpdatedAtMillis = 'ls_feed_updated_at_millis';
  static const _keyFeedRevokedAtMillis = 'ls_feed_revoked_at_millis';
  static const _keyCachedIcsText = 'ls_cached_ics_text';
  static const _keyCachedIcsUpdatedAtMillis = 'ls_cached_ics_updated_at_millis';
  static const _keyExportShowTime = 'ls_export_show_time';
  static const _keyExportShowDuration = 'ls_export_show_duration';
  static const _keyExportShowCategory = 'ls_export_show_category';
  static const _keyExportShowCheckInStatus = 'ls_export_show_checkin_status';
  static const _keyExportShowLockedStatus = 'ls_export_show_locked_status';
  static const _keyExportShowEnabledDimensions =
      'ls_export_show_enabled_dimensions';
  static const _pfxEnabled = 'ls_en_';
  // Legacy per-activity-id keys, read-only: superseded by the occurrence-keyed
  // blobs below, but old saved devices still have data under these prefixes.
  static const _pfxCheckin = 'ls_ci_';
  static const _pfxLocked = 'ls_lk_';
  static const _keyCheckinMap = 'ls_checkin_map';
  static const _keyLockedMap = 'ls_locked_map';
  static const _keyRemovedMap = 'ls_removed_map';
  static const _keyOccurrenceOverridesMap = 'ls_occurrence_overrides_map';
  static const _keyManualPlanItems = 'ls_manual_plan_items';

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
    final selectedCalendarId = _prefs.getString(_keySelectedCalendarId);
    final calendarNameConfirmed =
        _prefs.getBool(_keyCalendarNameConfirmed) ?? false;
    final introOnboardingCompleted =
        _prefs.getBool(_keyIntroOnboardingCompleted) ?? false;
    final difficultyEnabled = _prefs.getBool(_keyDifficultyEnabled) ?? false;
    final energyEnabled = _prefs.getBool(_keyEnergyEnabled) ?? false;
    final socialEnabled = _prefs.getBool(_keySocialEnabled) ?? false;
    final defaultDifficulty = _prefs.getInt(_keyDefaultDifficulty) ?? 3;
    final defaultEnergy = _prefs.getString(_keyDefaultEnergy) ?? 'medium';
    final defaultSocial = _prefs.getString(_keyDefaultSocial) ?? 'either';
    final feedEnabled = _prefs.getBool(_keyFeedEnabled) ?? false;
    final feedToken = _prefs.getString(_keyFeedToken);
    final feedCreatedAtMillis = _prefs.getInt(_keyFeedCreatedAtMillis);
    final feedUpdatedAtMillis = _prefs.getInt(_keyFeedUpdatedAtMillis);
    final feedRevokedAtMillis = _prefs.getInt(_keyFeedRevokedAtMillis);
    final cachedIcsText = _prefs.getString(_keyCachedIcsText);
    final cachedIcsUpdatedAtMillis =
        _prefs.getInt(_keyCachedIcsUpdatedAtMillis);
    final exportShowTime = _prefs.getBool(_keyExportShowTime) ?? true;
    final exportShowDuration = _prefs.getBool(_keyExportShowDuration) ?? true;
    final exportShowCategory = _prefs.getBool(_keyExportShowCategory) ?? true;
    final exportShowCheckInStatus =
        _prefs.getBool(_keyExportShowCheckInStatus) ?? true;
    final exportShowLockedStatus =
        _prefs.getBool(_keyExportShowLockedStatus) ?? true;
    final exportShowEnabledDimensions =
        _prefs.getBool(_keyExportShowEnabledDimensions) ?? true;
    final enabledMap = <String, bool>{};
    final legacyCheckinMap = <String, int>{};
    final legacyLockedMap = <String, bool>{};

    for (final activity in activities) {
      final enabled = _prefs.getBool('$_pfxEnabled${activity.id}');
      if (enabled != null) {
        enabledMap[activity.id] = enabled;
        activity.enabled = enabled;
      }

      final checkin = _prefs.getInt('$_pfxCheckin${activity.id}');
      if (checkin != null) legacyCheckinMap[activity.id] = checkin;

      final locked = _prefs.getBool('$_pfxLocked${activity.id}');
      if (locked != null) legacyLockedMap[activity.id] = locked;
    }

    // Occurrence-keyed blobs supersede the legacy per-activity-id keys above.
    // A device that has never saved under the new app version falls back to
    // the legacy activity-id-keyed data; AppState applies that to the
    // current week only and rewrites it in occurrence-keyed form on next save.
    final checkinMap = _loadCheckinMapBlob() ?? legacyCheckinMap;
    final lockedMap = _loadLockedMapBlob() ?? legacyLockedMap;
    final removedMap = _loadRemovedMapBlob() ?? const <String, bool>{};
    final occurrenceOverrides = _loadOccurrenceOverridesMapBlob() ??
        const <String, OccurrenceOverride>{};
    final manualPlanItems =
        _loadManualPlanItemsBlob() ?? const <String, ManualPlanItem>{};

    final planStyle = _prefs.getString(_keyPlanStyle) ?? 'balanced';
    final rangeType = rangeTypeFromName(_prefs.getString(_keyRangeType));
    final viewMode = rangeTypeFromNameOrNull(_prefs.getString(_keyViewMode));
    final rangeStartMillis = _prefs.getInt(_keyRangeStartMillis);
    final rangeStart = rangeStartMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(rangeStartMillis);

    return SavedState(
      activities: activities,
      seed: seed,
      updatedAtMillis: updatedAtMillis,
      planStyle: planStyle,
      rangeType: rangeType,
      viewMode: viewMode,
      rangeStart: rangeStart,
      displayName: displayName,
      displayNameConfirmed: displayNameConfirmed,
      calendarTitle: calendarTitle,
      selectedCalendarId: selectedCalendarId,
      calendarNameConfirmed: calendarNameConfirmed,
      introOnboardingCompleted: introOnboardingCompleted,
      difficultyEnabled: difficultyEnabled,
      energyEnabled: energyEnabled,
      socialEnabled: socialEnabled,
      defaultDifficulty: defaultDifficulty,
      defaultEnergy: defaultEnergy,
      defaultSocial: defaultSocial,
      feedEnabled: feedEnabled,
      feedToken: feedToken,
      feedCreatedAtMillis: feedCreatedAtMillis,
      feedUpdatedAtMillis: feedUpdatedAtMillis,
      feedRevokedAtMillis: feedRevokedAtMillis,
      cachedIcsText: cachedIcsText,
      cachedIcsUpdatedAtMillis: cachedIcsUpdatedAtMillis,
      exportShowTime: exportShowTime,
      exportShowDuration: exportShowDuration,
      exportShowCategory: exportShowCategory,
      exportShowCheckInStatus: exportShowCheckInStatus,
      exportShowLockedStatus: exportShowLockedStatus,
      exportShowEnabledDimensions: exportShowEnabledDimensions,
      enabledMap: enabledMap,
      checkinMap: checkinMap,
      lockedMap: lockedMap,
      removedMap: removedMap,
      occurrenceOverrides: occurrenceOverrides,
      manualPlanItems: manualPlanItems,
    );
  }

  static void saveActivities(List<Activity> activities) => _prefs.setString(
        _keyActivities,
        jsonEncode(activities.map((activity) => activity.toMap()).toList()),
      );

  static void saveSeed(int seed) => _prefs.setInt(_keySeed, seed);

  static void savePlanStyle(String value) =>
      _prefs.setString(_keyPlanStyle, value);

  static void saveRangeType(RangeType value) =>
      _prefs.setString(_keyRangeType, value.name);

  static void saveViewMode(RangeType value) =>
      _prefs.setString(_keyViewMode, value.name);

  static void saveRangeStartMillis(int? value) =>
      _saveNullableInt(_keyRangeStartMillis, value);

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

  static void saveSelectedCalendarId(String? value) {
    if (value == null || value.trim().isEmpty) {
      _prefs.remove(_keySelectedCalendarId);
      return;
    }
    _prefs.setString(_keySelectedCalendarId, value.trim());
  }

  static void saveCalendarNameConfirmed(bool value) =>
      _prefs.setBool(_keyCalendarNameConfirmed, value);

  static void saveIntroOnboardingCompleted(bool value) =>
      _prefs.setBool(_keyIntroOnboardingCompleted, value);

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

  static void saveFeedEnabled(bool value) =>
      _prefs.setBool(_keyFeedEnabled, value);

  static void saveFeedToken(String? value) {
    if (value == null || value.trim().isEmpty) {
      _prefs.remove(_keyFeedToken);
      return;
    }
    _prefs.setString(_keyFeedToken, value.trim());
  }

  static void saveFeedCreatedAtMillis(int? value) =>
      _saveNullableInt(_keyFeedCreatedAtMillis, value);

  static void saveFeedUpdatedAtMillis(int? value) =>
      _saveNullableInt(_keyFeedUpdatedAtMillis, value);

  static void saveFeedRevokedAtMillis(int? value) =>
      _saveNullableInt(_keyFeedRevokedAtMillis, value);

  static void saveCachedIcsText(String? value) {
    if (value == null || value.isEmpty) {
      _prefs.remove(_keyCachedIcsText);
      return;
    }
    _prefs.setString(_keyCachedIcsText, value);
  }

  static void saveCachedIcsUpdatedAtMillis(int? value) =>
      _saveNullableInt(_keyCachedIcsUpdatedAtMillis, value);

  static void saveExportShowTime(bool value) =>
      _prefs.setBool(_keyExportShowTime, value);

  static void saveExportShowDuration(bool value) =>
      _prefs.setBool(_keyExportShowDuration, value);

  static void saveExportShowCategory(bool value) =>
      _prefs.setBool(_keyExportShowCategory, value);

  static void saveExportShowCheckInStatus(bool value) =>
      _prefs.setBool(_keyExportShowCheckInStatus, value);

  static void saveExportShowLockedStatus(bool value) =>
      _prefs.setBool(_keyExportShowLockedStatus, value);

  static void saveExportShowEnabledDimensions(bool value) =>
      _prefs.setBool(_keyExportShowEnabledDimensions, value);

  static void saveUpdatedAtMillis(int value) =>
      _prefs.setInt(_keyUpdatedAtMillis, value);

  static void saveEnabled(String id, bool value) =>
      _prefs.setBool('$_pfxEnabled$id', value);

  static void saveCheckinMap(Map<String, int> value) =>
      _prefs.setString(_keyCheckinMap, jsonEncode(value));

  static void saveLockedMap(Map<String, bool> value) =>
      _prefs.setString(_keyLockedMap, jsonEncode(value));

  static void saveRemovedMap(Map<String, bool> value) =>
      _prefs.setString(_keyRemovedMap, jsonEncode(value));

  static void saveOccurrenceOverridesMap(
    Map<String, OccurrenceOverride> value,
  ) =>
      _prefs.setString(
        _keyOccurrenceOverridesMap,
        jsonEncode(value.map((key, value) => MapEntry(key, value.toMap()))),
      );

  static void saveManualPlanItems(Map<String, ManualPlanItem> value) =>
      _prefs.setString(
        _keyManualPlanItems,
        jsonEncode(value.map((key, value) => MapEntry(key, value.toMap()))),
      );

  static Map<String, int>? _loadCheckinMapBlob() {
    final raw = _prefs.getString(_keyCheckinMap);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            value is int ? value : (value is num ? value.toInt() : 0),
          ),
        );
      }
    } catch (_) {
      // Fall through to the legacy per-activity-id scan.
    }
    return null;
  }

  static Map<String, bool>? _loadLockedMapBlob() {
    final raw = _prefs.getString(_keyLockedMap);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value is bool && value),
        );
      }
    } catch (_) {
      // Fall through to the legacy per-activity-id scan.
    }
    return null;
  }

  static Map<String, bool>? _loadRemovedMapBlob() {
    final raw = _prefs.getString(_keyRemovedMap);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value is bool && value),
        );
      }
    } catch (_) {
      // No legacy format for removed occurrences to fall back to.
    }
    return null;
  }

  static Map<String, OccurrenceOverride>? _loadOccurrenceOverridesMapBlob() {
    final raw = _prefs.getString(_keyOccurrenceOverridesMap);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            OccurrenceOverride.fromMap(
              value is Map ? Map<String, dynamic>.from(value) : const {},
            ),
          ),
        );
      }
    } catch (_) {
      // Fall through to an empty map: a malformed blob is no worse than no
      // overrides having ever been saved.
    }
    return null;
  }

  static Map<String, ManualPlanItem>? _loadManualPlanItemsBlob() {
    final raw = _prefs.getString(_keyManualPlanItems);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(
            key.toString(),
            ManualPlanItem.fromMap(
              value is Map ? Map<String, dynamic>.from(value) : const {},
            ),
          ),
        );
      }
    } catch (_) {
      // A malformed blob is no worse than no manual items having ever been
      // saved.
    }
    return null;
  }

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

  static void _saveNullableInt(String key, int? value) {
    if (value == null || value <= 0) {
      _prefs.remove(key);
      return;
    }
    _prefs.setInt(key, value);
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
    this.removedMap = const {},
    this.occurrenceOverrides = const {},
    this.manualPlanItems = const {},
    this.planStyle = 'balanced',
    this.rangeType = RangeType.week,
    RangeType? viewMode,
    this.rangeStart,
    this.displayName,
    this.displayNameConfirmed = false,
    this.calendarTitle,
    this.selectedCalendarId,
    this.calendarNameConfirmed = false,
    this.introOnboardingCompleted = false,
    this.difficultyEnabled = false,
    this.energyEnabled = false,
    this.socialEnabled = false,
    this.defaultDifficulty = 3,
    this.defaultEnergy = 'medium',
    this.defaultSocial = 'either',
    this.feedEnabled = false,
    this.feedToken,
    this.feedCreatedAtMillis,
    this.feedUpdatedAtMillis,
    this.feedRevokedAtMillis,
    this.cachedIcsText,
    this.cachedIcsUpdatedAtMillis,
    this.exportShowTime = true,
    this.exportShowDuration = true,
    this.exportShowCategory = true,
    this.exportShowCheckInStatus = true,
    this.exportShowLockedStatus = true,
    this.exportShowEnabledDimensions = true,
  }) : viewMode = viewMode ?? rangeType;

  final List<Activity> activities;
  final int seed;
  final int updatedAtMillis;
  final String planStyle;
  final RangeType rangeType;

  /// How the Plan screen displays [rangeType]'s generated range. Defaults to
  /// [rangeType] when not given, since saves from before view/horizon were
  /// separated never recorded a distinct view mode.
  final RangeType viewMode;

  /// The day the generated range started from. `null` for saves from before
  /// this was tracked; [AppState] defaults that to today on load.
  final DateTime? rangeStart;
  final String? displayName;
  final bool displayNameConfirmed;
  final String? calendarTitle;
  final String? selectedCalendarId;
  final bool calendarNameConfirmed;
  final bool introOnboardingCompleted;
  final bool difficultyEnabled;
  final bool energyEnabled;
  final bool socialEnabled;
  final int defaultDifficulty;
  final String defaultEnergy;
  final String defaultSocial;
  final bool feedEnabled;
  final String? feedToken;
  final int? feedCreatedAtMillis;
  final int? feedUpdatedAtMillis;
  final int? feedRevokedAtMillis;
  final String? cachedIcsText;
  final int? cachedIcsUpdatedAtMillis;
  final bool exportShowTime;
  final bool exportShowDuration;
  final bool exportShowCategory;
  final bool exportShowCheckInStatus;
  final bool exportShowLockedStatus;
  final bool exportShowEnabledDimensions;
  final Map<String, bool> enabledMap;
  final Map<String, int> checkinMap;
  final Map<String, bool> lockedMap;

  /// Occurrence-keyed (`yyyy-MM-dd:activityId`) record of "Remove from this
  /// plan" choices: `true` means that occurrence should stay out of the
  /// generated plan after a reload, without disabling or deleting the
  /// source [Activity]. See [AppState.removeFromPlan].
  final Map<String, bool> removedMap;

  /// Occurrence-keyed (`yyyy-MM-dd:activityId`) per-occurrence edits (actual
  /// scheduled time, category, and enabled planning dimensions) made
  /// through the focused "Edit this plan item" sheet, without changing the
  /// source [Activity] template. See [AppState.editPlannedOccurrence].
  final Map<String, OccurrenceOverride> occurrenceOverrides;

  /// Stable-id-keyed manual plan items. See [ManualPlanItem].
  final Map<String, ManualPlanItem> manualPlanItems;

  Map<String, dynamic> toMap() {
    return {
      'activities': activities.map((activity) => activity.toMap()).toList(),
      'seed': seed,
      'updatedAtMillis': updatedAtMillis,
      'planStyle': planStyle,
      'rangeType': rangeType.name,
      'viewMode': viewMode.name,
      'rangeStartMillis': rangeStart?.millisecondsSinceEpoch,
      'displayName': displayName,
      'displayNameConfirmed': displayNameConfirmed,
      'calendarTitle': calendarTitle,
      'calendarNameConfirmed': calendarNameConfirmed,
      'introOnboardingCompleted': introOnboardingCompleted,
      'difficultyEnabled': difficultyEnabled,
      'energyEnabled': energyEnabled,
      'socialEnabled': socialEnabled,
      'defaultDifficulty': defaultDifficulty,
      'defaultEnergy': defaultEnergy,
      'defaultSocial': defaultSocial,
      'feedEnabled': feedEnabled,
      'isPublished': feedEnabled,
      'feedToken': feedToken,
      'feedCreatedAtMillis': feedCreatedAtMillis,
      'feedUpdatedAtMillis': feedUpdatedAtMillis,
      'feedRevokedAtMillis': feedRevokedAtMillis,
      'cachedIcsText': cachedIcsText,
      'cachedIcsUpdatedAtMillis': cachedIcsUpdatedAtMillis,
      'exportShowTime': exportShowTime,
      'exportShowDuration': exportShowDuration,
      'exportShowCategory': exportShowCategory,
      'exportShowCheckInStatus': exportShowCheckInStatus,
      'exportShowLockedStatus': exportShowLockedStatus,
      'exportShowEnabledDimensions': exportShowEnabledDimensions,
      'enabledMap': enabledMap,
      'checkinMap': checkinMap,
      'lockedMap': lockedMap,
      'removedMap': removedMap,
      'occurrenceOverrides':
          occurrenceOverrides.map((key, value) => MapEntry(key, value.toMap())),
      'manualPlanItems':
          manualPlanItems.map((key, value) => MapEntry(key, value.toMap())),
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
      rangeType: rangeTypeFromName(map['rangeType'] as String?),
      viewMode: rangeTypeFromNameOrNull(map['viewMode'] as String?),
      rangeStart: _readNullableDateTimeMillis(map['rangeStartMillis']),
      displayName: _readNullableString(map['displayName']),
      displayNameConfirmed: _readBool(map['displayNameConfirmed']),
      calendarTitle: _readNullableString(map['calendarTitle']),
      selectedCalendarId: _readNullableString(map['selectedCalendarId']),
      calendarNameConfirmed: _readBool(map['calendarNameConfirmed']),
      introOnboardingCompleted: _readBool(map['introOnboardingCompleted']),
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
      feedEnabled: _readBool(map['feedEnabled'] ?? map['isPublished']),
      feedToken: _readNullableString(map['feedToken']),
      feedCreatedAtMillis: _readNullableInt(map['feedCreatedAtMillis']),
      feedUpdatedAtMillis: _readNullableInt(map['feedUpdatedAtMillis']),
      feedRevokedAtMillis: _readNullableInt(map['feedRevokedAtMillis']),
      cachedIcsText: _readRawNullableString(map['cachedIcsText']),
      cachedIcsUpdatedAtMillis:
          _readNullableInt(map['cachedIcsUpdatedAtMillis']),
      exportShowTime: _readBoolOrDefault(map['exportShowTime'], true),
      exportShowDuration: _readBoolOrDefault(map['exportShowDuration'], true),
      exportShowCategory: _readBoolOrDefault(map['exportShowCategory'], true),
      exportShowCheckInStatus:
          _readBoolOrDefault(map['exportShowCheckInStatus'], true),
      exportShowLockedStatus:
          _readBoolOrDefault(map['exportShowLockedStatus'], true),
      exportShowEnabledDimensions:
          _readBoolOrDefault(map['exportShowEnabledDimensions'], true),
      enabledMap: Map<String, bool>.from(map['enabledMap'] ?? {}),
      checkinMap: Map<String, int>.from(map['checkinMap'] ?? {}),
      lockedMap: Map<String, bool>.from(map['lockedMap'] ?? {}),
      removedMap: Map<String, bool>.from(map['removedMap'] ?? {}),
      occurrenceOverrides: _readOccurrenceOverrides(
        map['occurrenceOverrides'],
      ),
      manualPlanItems: _readManualPlanItems(map['manualPlanItems']),
    );
  }

  static Map<String, OccurrenceOverride> _readOccurrenceOverrides(
    Object? value,
  ) {
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(
          key.toString(),
          OccurrenceOverride.fromMap(
            entry is Map ? Map<String, dynamic>.from(entry) : const {},
          ),
        ),
      );
    }
    return const {};
  }

  static Map<String, ManualPlanItem> _readManualPlanItems(Object? value) {
    if (value is Map) {
      return value.map(
        (key, entry) => MapEntry(
          key.toString(),
          ManualPlanItem.fromMap(
            entry is Map ? Map<String, dynamic>.from(entry) : const {},
          ),
        ),
      );
    }
    return const {};
  }

  static int _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  static int? _readNullableInt(Object? value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    return null;
  }

  static DateTime? _readNullableDateTimeMillis(Object? value) {
    final millis = _readNullableInt(value);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
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

  // Unlike _readNullableString, this does not trim: cachedIcsText is literal
  // ICS content whose required trailing CRLF would otherwise be stripped.
  static String? _readRawNullableString(Object? value) {
    if (value is! String) return null;
    return value.isEmpty ? null : value;
  }

  static bool _readBool(Object? value) => value is bool ? value : false;

  static bool _readBoolOrDefault(Object? value, bool fallback) =>
      value is bool ? value : fallback;

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
