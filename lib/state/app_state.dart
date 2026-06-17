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
  bool _checkInPromptDismissed = false;
  String? _userId;
  String? _calendarId;
  String _calendarTitle = FirestoreSyncService.defaultCalendarTitle;
  String? _calendarOwnerUserId;
  List<String> _calendarMemberUserIds = const [];

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
  String? get calendarOwnerUserId => _calendarOwnerUserId;
  List<String> get calendarMemberUserIds =>
      List.unmodifiable(_calendarMemberUserIds);

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
    final changed = _calendarId != metadata.calendarId ||
        _calendarTitle != metadata.title ||
        _calendarOwnerUserId != metadata.ownerUserId ||
        _calendarMemberUserIds.join('|') != metadata.memberUserIds.join('|');

    _calendarId = metadata.calendarId;
    _calendarTitle = metadata.title;
    _calendarOwnerUserId = metadata.ownerUserId;
    _calendarMemberUserIds = List.unmodifiable(metadata.memberUserIds);
    return changed;
  }

  void _clearCalendarMetadata() {
    _calendarId = null;
    _calendarTitle = FirestoreSyncService.defaultCalendarTitle;
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

  static PlanStyle _parsePlanStyle(String value) {
    return PlanStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PlanStyle.balanced,
    );
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
