import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../services/firestore_sync_service.dart';
import '../services/persistence_service.dart';
import '../services/planner_service.dart'
    show PlannerGenerationResult, PlannerService, PlanStyle;

/// Holds all mutable in-session state: activity pool, current week plan.
/// Persists changes to [PersistenceService] and [FirestoreSyncService] (if signed in) on every mutation.
/// Screens read from it via [AppStateScope.of(context)].
class AppState extends ChangeNotifier {
  final List<Activity> activities;
  late List<DayPlan> _weekPlan;
  int _seed = 0;
  int _updatedAtMillis = 0;
  PlanStyle _planStyle = PlanStyle.balanced;
  SavedState? _lastRegenerationSnapshot;
  String? _plannerConflictMessage;
  String? _displayName;
  bool _displayNameConfirmed = false;
  bool _calendarNameConfirmed = false;
  bool _checkInPromptDismissed = false;
  String? _userId;
  String? _calendarId;
  String _calendarTitle = FirestoreSyncService.defaultCalendarTitle;
  String? _calendarOwnerUserId;
  List<String> _calendarMemberUserIds = const [];
  bool _difficultyEnabled = false;
  bool _energyEnabled = false;
  bool _socialEnabled = false;
  int _defaultDifficulty = 3;
  String _defaultEnergy = 'medium';
  String _defaultSocial = 'either';
  bool _feedEnabled = false;
  String? _feedToken;
  int? _feedCreatedAtMillis;
  int? _feedUpdatedAtMillis;
  int? _feedRevokedAtMillis;

  AppState({required List<Activity> activities, SavedState? savedState})
      : activities = activities.map((activity) => activity.copy()).toList() {
    if (savedState != null) {
      _applySavedState(savedState, persistLocal: false);
    } else {
      _weekPlan = _buildPlan();
    }
  }

  List<DayPlan> get weekPlan => _weekPlan;
  PlanStyle get planStyle => _planStyle;
  bool get canUndoLastRegeneration => _lastRegenerationSnapshot != null;
  String? get plannerConflictMessage => _plannerConflictMessage;
  String? get displayName => _displayName;
  bool get displayNameConfirmed => _displayNameConfirmed;
  bool get checkInPromptDismissed => _checkInPromptDismissed;
  String? get userId => _userId;
  String? get calendarId => _calendarId;
  String get calendarTitle => _calendarTitle;
  bool get calendarNameConfirmed => _calendarNameConfirmed;
  String? get calendarOwnerUserId => _calendarOwnerUserId;
  List<String> get calendarMemberUserIds =>
      List.unmodifiable(_calendarMemberUserIds);
  bool get difficultyEnabled => _difficultyEnabled;
  bool get energyEnabled => _energyEnabled;
  bool get socialEnabled => _socialEnabled;
  int get defaultDifficulty => _defaultDifficulty;
  String get defaultEnergy => _defaultEnergy;
  String get defaultSocial => _defaultSocial;
  String get defaultEnergyLabel => _capitalize(_defaultEnergy);
  String get defaultSocialLabel => _capitalize(_defaultSocial);
  bool get feedEnabled => _feedEnabled;
  bool get isPublished => _feedEnabled;
  String? get feedToken => _feedToken;
  int? get feedCreatedAtMillis => _feedCreatedAtMillis;
  int? get feedUpdatedAtMillis => _feedUpdatedAtMillis;
  int? get feedRevokedAtMillis => _feedRevokedAtMillis;
  String get feedTokenPreview {
    final token = _feedToken;
    if (token == null || token.isEmpty) return 'No token yet';
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 6)}';
  }

  void setUserId(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    if (uid != null) {
      _applyCalendarMetadata(FirestoreSyncService.defaultMetadata(uid));
      syncWithFirestore();
    } else {
      _clearCalendarMetadata();
    }
  }

  Future<void> syncWithFirestore() async {
    final uid = _userId;
    if (uid == null) return;
    final remote = await FirestoreSyncService.loadDefaultCalendar(uid);
    if (_userId != uid) return;

    final local = _currentSavedState();
    var metadataChanged = false;
    if (remote != null) {
      metadataChanged = _applyCalendarMetadata(remote.metadata);
    }
    if (remote != null &&
        remote.state.updatedAtMillis > local.updatedAtMillis) {
      _applySavedState(remote.state);
      FirestoreSyncService.saveState(uid, remote.state);
      notifyListeners();
      return;
    }

    final stateToSave = local.updatedAtMillis == 0
        ? _currentSavedState(
            updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
          )
        : local;
    if (stateToSave.updatedAtMillis != _updatedAtMillis) {
      _updatedAtMillis = stateToSave.updatedAtMillis;
      _persistLocal(stateToSave);
    }
    FirestoreSyncService.saveState(uid, stateToSave);
    if (metadataChanged) {
      notifyListeners();
    }
  }

  // ─── Activities ───────────────────────────────────────────────────────────

  void setActivityEnabled(String id, {required bool enabled}) {
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    activities[idx].enabled = enabled;
    _persist();
    notifyListeners();
  }

  void addActivity({
    required String title,
    required String category,
    required int durationMinutes,
    required String preferredTime,
    int? difficulty,
    String? energy,
    String? social,
    required int maxPerWeek,
    required List<int> allowedWeekdays,
    required bool noConsecutiveDays,
    required bool enabled,
  }) {
    activities.add(
      Activity(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        category: category,
        durationMinutes: durationMinutes,
        preferredTime: preferredTime,
        difficulty: difficulty ?? _defaultDifficulty,
        energy: energy ?? _defaultEnergy,
        social: social ?? _defaultSocial,
        maxPerWeek: maxPerWeek,
        allowedWeekdays: allowedWeekdays,
        noConsecutiveDays: noConsecutiveDays,
        enabled: enabled,
      ),
    );
    _persist();
    notifyListeners();
  }

  bool hasActivityTitle(String title) {
    final normalized = _normalizeActivityTitle(title);
    return activities.any(
      (activity) => _normalizeActivityTitle(activity.title) == normalized,
    );
  }

  bool addStarterActivity(Activity starter) {
    if (hasActivityTitle(starter.title)) return false;
    activities.add(
      Activity(
        id: '${starter.id}_${DateTime.now().microsecondsSinceEpoch}',
        title: starter.title,
        category: starter.category,
        durationMinutes: starter.durationMinutes,
        preferredTime: starter.preferredTime,
        difficulty: starter.difficulty,
        energy: starter.energy,
        social: starter.social,
        maxPerWeek: starter.maxPerWeek,
        allowedWeekdays: starter.allowedWeekdays,
        noConsecutiveDays: starter.noConsecutiveDays,
        enabled: starter.enabled,
      ),
    );
    _persist();
    notifyListeners();
    return true;
  }

  void updateActivity(
    String id, {
    required String title,
    required String category,
    required int durationMinutes,
    required String preferredTime,
    int? difficulty,
    String? energy,
    String? social,
    required int maxPerWeek,
    required List<int> allowedWeekdays,
    required bool noConsecutiveDays,
    required bool enabled,
  }) {
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final activity = activities[idx];
    activity
      ..title = title
      ..category = category
      ..durationMinutes = durationMinutes
      ..preferredTime = preferredTime
      ..difficulty = (difficulty ?? activity.difficulty).clamp(1, 5).toInt()
      ..energy = _normalizeOption(
        energy ?? activity.energy,
        fallback: activity.energy,
        allowed: const ['low', 'medium', 'high'],
      )
      ..social = _normalizeOption(
        social ?? activity.social,
        fallback: activity.social,
        allowed: const ['solo', 'together', 'group', 'either'],
      )
      ..maxPerWeek = maxPerWeek
      ..allowedWeekdays = List<int>.from(allowedWeekdays)
      ..noConsecutiveDays = noConsecutiveDays
      ..enabled = enabled;
    _persist();
    notifyListeners();
  }

  // ─── Plan ─────────────────────────────────────────────────────────────────

  bool confirmDisplayName(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return false;
    _displayName = trimmed;
    _displayNameConfirmed = true;
    _persist();
    notifyListeners();
    return true;
  }

  bool confirmCalendarTitle(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return false;
    _calendarTitle = trimmed;
    _calendarNameConfirmed = true;
    _persist();
    notifyListeners();
    return true;
  }

  void regenerate() {
    _lastRegenerationSnapshot = _currentSavedState();
    _seed++;
    _weekPlan = _buildPlan(lockedItems: _collectLocked());
    _persist();
    notifyListeners();
  }

  void undoLastRegeneration() {
    final snapshot = _lastRegenerationSnapshot;
    if (snapshot == null) return;
    _lastRegenerationSnapshot = null;
    _applySavedState(snapshot, persistLocal: false);
    _persist();
    notifyListeners();
  }

  void dismissCheckInPrompt() {
    if (_checkInPromptDismissed) return;
    _checkInPromptDismissed = true;
    notifyListeners();
  }

  void setPlanStyle(PlanStyle style) {
    if (_planStyle == style) return;
    _planStyle = style;
    _weekPlan = _buildPlan(lockedItems: _collectLocked());
    _persist();
    notifyListeners();
  }

  void setDifficultyEnabled(bool value) {
    if (_difficultyEnabled == value) return;
    _difficultyEnabled = value;
    _persist();
    notifyListeners();
  }

  void setEnergyEnabled(bool value) {
    if (_energyEnabled == value) return;
    _energyEnabled = value;
    _persist();
    notifyListeners();
  }

  void setSocialEnabled(bool value) {
    if (_socialEnabled == value) return;
    _socialEnabled = value;
    _persist();
    notifyListeners();
  }

  void setDefaultDifficulty(int value) {
    final normalized = value.clamp(1, 5).toInt();
    if (_defaultDifficulty == normalized) return;
    _defaultDifficulty = normalized;
    _persist();
    notifyListeners();
  }

  void setDefaultEnergy(String value) {
    final normalized = _normalizeOption(
      value,
      fallback: _defaultEnergy,
      allowed: const ['low', 'medium', 'high'],
    );
    if (_defaultEnergy == normalized) return;
    _defaultEnergy = normalized;
    _persist();
    notifyListeners();
  }

  void setDefaultSocial(String value) {
    final normalized = _normalizeOption(
      value,
      fallback: _defaultSocial,
      allowed: const ['solo', 'together', 'group', 'either'],
    );
    if (_defaultSocial == normalized) return;
    _defaultSocial = normalized;
    _persist();
    notifyListeners();
  }

  void setFeedEnabled(bool value) {
    if (value) {
      _enableFeed();
      return;
    }
    _disableFeed();
  }

  void regenerateFeedToken() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hadToken = _feedToken != null && _feedToken!.isNotEmpty;
    _feedToken = _generateFeedToken();
    _feedEnabled = true;
    _feedCreatedAtMillis ??= now;
    _feedUpdatedAtMillis = now;
    if (hadToken) {
      _feedRevokedAtMillis = now;
    }
    _persist();
    notifyListeners();
  }

  void revokeFeedToken() {
    if (!_feedEnabled && _feedToken == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _feedEnabled = false;
    _feedToken = null;
    _feedUpdatedAtMillis = now;
    _feedRevokedAtMillis = now;
    _persist();
    notifyListeners();
  }

  void toggleLock(PlannedActivity activity) {
    activity.locked = !activity.locked;
    _persist();
    notifyListeners();
  }

  void notifyCheckIn(PlannedActivity activity) {
    _persist();
    notifyListeners();
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  void _applySavedState(SavedState saved, {bool persistLocal = true}) {
    _lastRegenerationSnapshot = null;
    activities
      ..clear()
      ..addAll(saved.activities.map((activity) => activity.copy()));
    _seed = saved.seed;
    _updatedAtMillis = saved.updatedAtMillis;
    _planStyle = _parsePlanStyle(saved.planStyle);
    _displayName = saved.displayName;
    _displayNameConfirmed =
        saved.displayNameConfirmed && saved.displayName != null;
    final savedCalendarTitle = saved.calendarTitle;
    if (savedCalendarTitle != null) {
      _calendarTitle = savedCalendarTitle;
    }
    _calendarNameConfirmed = saved.calendarNameConfirmed &&
        (savedCalendarTitle != null || _calendarTitle.trim().isNotEmpty);
    _difficultyEnabled = saved.difficultyEnabled;
    _energyEnabled = saved.energyEnabled;
    _socialEnabled = saved.socialEnabled;
    _defaultDifficulty = saved.defaultDifficulty.clamp(1, 5).toInt();
    _defaultEnergy = _normalizeOption(
      saved.defaultEnergy,
      fallback: 'medium',
      allowed: const ['low', 'medium', 'high'],
    );
    _defaultSocial = _normalizeOption(
      saved.defaultSocial,
      fallback: 'either',
      allowed: const ['solo', 'together', 'group', 'either'],
    );
    _feedEnabled = saved.feedEnabled;
    _feedToken = saved.feedToken;
    _feedCreatedAtMillis = saved.feedCreatedAtMillis;
    _feedUpdatedAtMillis = saved.feedUpdatedAtMillis;
    _feedRevokedAtMillis = saved.feedRevokedAtMillis;
    for (final entry in saved.enabledMap.entries) {
      final idx = activities.indexWhere((a) => a.id == entry.key);
      if (idx >= 0) activities[idx].enabled = entry.value;
    }
    _weekPlan = _buildPlan();
    _applyOverlays(saved);

    if (persistLocal) {
      _persistLocal(saved);
    }
  }

  void _persist() {
    _updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    final state = _currentSavedState(updatedAtMillis: _updatedAtMillis);
    _persistLocal(state);
    if (_userId != null) {
      FirestoreSyncService.saveState(_userId!, state);
    }
  }

  void _persistLocal(SavedState state) {
    PersistenceService.saveActivities(state.activities);
    PersistenceService.saveSeed(state.seed);
    PersistenceService.saveUpdatedAtMillis(state.updatedAtMillis);
    PersistenceService.savePlanStyle(state.planStyle);
    PersistenceService.saveDisplayName(state.displayName);
    PersistenceService.saveDisplayNameConfirmed(state.displayNameConfirmed);
    PersistenceService.saveCalendarTitle(state.calendarTitle);
    PersistenceService.saveCalendarNameConfirmed(state.calendarNameConfirmed);
    PersistenceService.saveDifficultyEnabled(state.difficultyEnabled);
    PersistenceService.saveEnergyEnabled(state.energyEnabled);
    PersistenceService.saveSocialEnabled(state.socialEnabled);
    PersistenceService.saveDefaultDifficulty(state.defaultDifficulty);
    PersistenceService.saveDefaultEnergy(state.defaultEnergy);
    PersistenceService.saveDefaultSocial(state.defaultSocial);
    PersistenceService.saveFeedEnabled(state.feedEnabled);
    PersistenceService.saveFeedToken(state.feedToken);
    PersistenceService.saveFeedCreatedAtMillis(state.feedCreatedAtMillis);
    PersistenceService.saveFeedUpdatedAtMillis(state.feedUpdatedAtMillis);
    PersistenceService.saveFeedRevokedAtMillis(state.feedRevokedAtMillis);
    for (final entry in state.enabledMap.entries) {
      PersistenceService.saveEnabled(entry.key, entry.value);
    }
    for (final entry in state.checkinMap.entries) {
      PersistenceService.saveCheckin(entry.key, entry.value);
    }
    for (final entry in state.lockedMap.entries) {
      PersistenceService.saveLocked(entry.key, entry.value);
    }
  }

  bool _applyCalendarMetadata(CalendarMetadata metadata) {
    final nextTitle = _calendarNameConfirmed &&
            _calendarTitle.trim().isNotEmpty &&
            metadata.title == FirestoreSyncService.defaultCalendarTitle
        ? _calendarTitle
        : metadata.title;
    final changed = _calendarId != metadata.calendarId ||
        _calendarTitle != nextTitle ||
        _calendarOwnerUserId != metadata.ownerUserId ||
        _calendarMemberUserIds.join('|') != metadata.memberUserIds.join('|');

    _calendarId = metadata.calendarId;
    _calendarTitle = nextTitle;
    _calendarOwnerUserId = metadata.ownerUserId;
    _calendarMemberUserIds = List.unmodifiable(metadata.memberUserIds);
    return changed;
  }

  void _clearCalendarMetadata() {
    _calendarId = null;
    if (!_calendarNameConfirmed) {
      _calendarTitle = FirestoreSyncService.defaultCalendarTitle;
    }
    _calendarOwnerUserId = null;
    _calendarMemberUserIds = const [];
  }

  SavedState _currentSavedState({int? updatedAtMillis}) {
    final enabledMap = <String, bool>{};
    for (final a in activities) {
      enabledMap[a.id] = a.enabled;
    }

    final checkinMap = <String, int>{};
    final lockedMap = <String, bool>{};
    for (final day in _weekPlan) {
      for (final pa in day.activities) {
        checkinMap[pa.activity.id] = pa.status.index;
        lockedMap[pa.activity.id] = pa.locked;
      }
    }

    return SavedState(
      activities: activities.map((activity) => activity.copy()).toList(),
      seed: _seed,
      updatedAtMillis: updatedAtMillis ?? _updatedAtMillis,
      planStyle: _planStyle.name,
      displayName: _displayName,
      displayNameConfirmed: _displayNameConfirmed,
      calendarTitle: _calendarTitle,
      calendarNameConfirmed: _calendarNameConfirmed,
      difficultyEnabled: _difficultyEnabled,
      energyEnabled: _energyEnabled,
      socialEnabled: _socialEnabled,
      defaultDifficulty: _defaultDifficulty,
      defaultEnergy: _defaultEnergy,
      defaultSocial: _defaultSocial,
      feedEnabled: _feedEnabled,
      feedToken: _feedToken,
      feedCreatedAtMillis: _feedCreatedAtMillis,
      feedUpdatedAtMillis: _feedUpdatedAtMillis,
      feedRevokedAtMillis: _feedRevokedAtMillis,
      enabledMap: enabledMap,
      checkinMap: checkinMap,
      lockedMap: lockedMap,
    );
  }

  Map<int, List<PlannedActivity>> _collectLocked() {
    final result = <int, List<PlannedActivity>>{};
    for (var i = 0; i < _weekPlan.length; i++) {
      result[i] = _weekPlan[i].activities.where((a) => a.locked).toList();
    }
    return result;
  }

  List<DayPlan> _buildPlan({Map<int, List<PlannedActivity>>? lockedItems}) {
    final weekStart = PlannerService.mondayOf(DateTime.now());
    final weekIndex =
        weekStart.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24 * 7);
    final seed = weekIndex + _seed * 1000;

    final lockedIds = lockedItems == null
        ? <String>{}
        : lockedItems.values.expand((l) => l).map((a) => a.activity.id).toSet();

    final pool = activities
        .where((a) => a.enabled && !lockedIds.contains(a.id))
        .toList();

    final generation = PlannerService.generateWithDiagnostics(
      weekStart: weekStart,
      pool: pool,
      seed: seed,
      planStyle: _planStyle,
      difficultyAware: _difficultyEnabled,
      scheduledContext: lockedItems ?? const <int, List<PlannedActivity>>{},
    );
    _plannerConflictMessage = _buildPlannerConflictMessage(generation);
    final plan = generation.plan;

    if (lockedItems != null) {
      for (var i = 0; i < plan.length; i++) {
        final dayLocked = lockedItems[i] ?? [];
        if (dayLocked.isNotEmpty) {
          plan[i].activities.addAll(dayLocked);
          plan[i].activities.sort(
                (a, b) => PlannerService.timeRank(a.timeSlot)
                    .compareTo(PlannerService.timeRank(b.timeSlot)),
              );
        }
      }
    }

    return plan;
  }

  String? _buildPlannerConflictMessage(PlannerGenerationResult generation) {
    if (!generation.hasBlockedActivitySlots) return null;
    final count = generation.unfilledActivityCount;
    final slotLabel = count == 1 ? 'slot was' : 'slots were';
    return 'This week is lighter than expected because $count activity '
        '$slotLabel blocked by rules. Try relaxing weekdays, increasing max '
        'per week, turning off no-consecutive-days, or choosing a lighter '
        'plan style.';
  }

  void _applyOverlays(SavedState saved) {
    for (final day in _weekPlan) {
      for (final pa in day.activities) {
        final id = pa.activity.id;

        final statusIdx = saved.checkinMap[id];
        if (statusIdx != null && statusIdx < CheckStatus.values.length) {
          pa.status = CheckStatus.values[statusIdx];
        }

        final locked = saved.lockedMap[id];
        if (locked != null) pa.locked = locked;
      }
    }
  }

  static String _normalizeActivityTitle(String title) {
    return title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  void _enableFeed() {
    final hasToken = _feedToken != null && _feedToken!.isNotEmpty;
    if (_feedEnabled && hasToken) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _feedEnabled = true;
    if (!hasToken) {
      _feedToken = _generateFeedToken();
      _feedCreatedAtMillis ??= now;
    }
    _feedUpdatedAtMillis = now;
    _persist();
    notifyListeners();
  }

  void _disableFeed() {
    if (!_feedEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _feedEnabled = false;
    _feedUpdatedAtMillis = now;
    _persist();
    notifyListeners();
  }

  static String _generateFeedToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static PlanStyle _parsePlanStyle(String value) {
    return PlanStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PlanStyle.balanced,
    );
  }

  static String _normalizeOption(
    String value, {
    required String fallback,
    required List<String> allowed,
  }) {
    final normalized = value.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value.characters.first.toUpperCase()}${value.substring(1)}';
  }
}

// ─── InheritedNotifier scope ──────────────────────────────────────────────────

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}
