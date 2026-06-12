import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../services/persistence_service.dart';
import '../services/planner_service.dart';

/// Holds all mutable in-session state: activity pool, current week plan.
/// Persists changes to [PersistenceService] on every mutation.
/// Screens read from it via [AppStateScope.of(context)].
class AppState extends ChangeNotifier {
  final List<Activity> activities;
  late List<DayPlan> _weekPlan;
  int _seed = 0;

  AppState({required this.activities, SavedState? savedState}) {
    if (savedState != null) {
      _seed = savedState.seed;
      for (final entry in savedState.enabledMap.entries) {
        final idx = activities.indexWhere((a) => a.id == entry.key);
        if (idx >= 0) activities[idx].enabled = entry.value;
      }
    }
    _weekPlan = _buildPlan();
    if (savedState != null) _applyOverlays(savedState);
  }

  List<DayPlan> get weekPlan => _weekPlan;

  // ─── Activities ───────────────────────────────────────────────────────────

  void setActivityEnabled(String id, {required bool enabled}) {
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    activities[idx].enabled = enabled;
    PersistenceService.saveEnabled(id, enabled);
    notifyListeners();
  }

  // ─── Plan ─────────────────────────────────────────────────────────────────

  void regenerate() {
    _seed++;
    _weekPlan = _buildPlan(lockedItems: _collectLocked());
    PersistenceService.saveSeed(_seed);
    _saveAllPlanStates();
    notifyListeners();
  }

  void toggleLock(PlannedActivity activity) {
    activity.locked = !activity.locked;
    PersistenceService.saveLocked(activity.activity.id, activity.locked);
    notifyListeners();
  }

  void notifyCheckIn(PlannedActivity activity) {
    PersistenceService.saveCheckin(activity.activity.id, activity.status.index);
    notifyListeners();
  }

  // ─── Private ─────────────────────────────────────────────────────────────

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

  void _saveAllPlanStates() {
    for (final day in _weekPlan) {
      for (final pa in day.activities) {
        PersistenceService.saveCheckin(pa.activity.id, pa.status.index);
        PersistenceService.saveLocked(pa.activity.id, pa.locked);
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
