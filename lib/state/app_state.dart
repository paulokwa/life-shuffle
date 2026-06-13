import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../services/firestore_sync_service.dart';
import '../services/persistence_service.dart';
import '../services/planner_service.dart';

/// Holds all mutable in-session state: activity pool, current week plan.
/// Persists changes to [PersistenceService] and [FirestoreSyncService] (if signed in) on every mutation.
/// Screens read from it via [AppStateScope.of(context)].
class AppState extends ChangeNotifier {
  final List<Activity> activities;
  late List<DayPlan> _weekPlan;
  int _seed = 0;
  int _updatedAtMillis = 0;
  String? _userId;

  AppState({required this.activities, SavedState? savedState}) {
    if (savedState != null) {
      _applySavedState(savedState, persistLocal: false);
    } else {
      _weekPlan = _buildPlan();
    }
  }

  List<DayPlan> get weekPlan => _weekPlan;
  String? get userId => _userId;

  void setUserId(String? uid) {
    if (_userId == uid) return;
    _userId = uid;
    if (uid != null) {
      syncWithFirestore();
    }
  }

  Future<void> syncWithFirestore() async {
    final uid = _userId;
    if (uid == null) return;
    final remote = await FirestoreSyncService.loadState(uid);
    if (_userId != uid) return;

    final local = _currentSavedState();
    if (remote != null && remote.updatedAtMillis > local.updatedAtMillis) {
      _applySavedState(remote);
      FirestoreSyncService.saveState(uid, remote);
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
  }

  // ─── Activities ───────────────────────────────────────────────────────────

  void setActivityEnabled(String id, {required bool enabled}) {
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    activities[idx].enabled = enabled;
    _persist();
    notifyListeners();
  }

  // ─── Plan ─────────────────────────────────────────────────────────────────

  void regenerate() {
    _seed++;
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
    _seed = saved.seed;
    _updatedAtMillis = saved.updatedAtMillis;
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
    PersistenceService.saveSeed(state.seed);
    PersistenceService.saveUpdatedAtMillis(state.updatedAtMillis);
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
      seed: _seed,
      updatedAtMillis: updatedAtMillis ?? _updatedAtMillis,
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
        : lockedItems.values
            .expand((l) => l)
            .map((a) => a.activity.id)
            .toSet();

    final pool = activities
        .where((a) => a.enabled && !lockedIds.contains(a.id))
        .toList();

    final plan = PlannerService.generate(
      weekStart: weekStart,
      pool: pool,
      seed: seed,
    );

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
