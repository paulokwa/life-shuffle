import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight local storage for in-session state.
/// Wraps SharedPreferences (localStorage on web).
/// Call [init] once in main() before creating AppState.
class PersistenceService {
  PersistenceService._();

  static late SharedPreferences _prefs;

  // ─── Key prefixes ─────────────────────────────────────────────────────────
  static const _keySeed    = 'ls_seed';
  static const _pfxEnabled = 'ls_en_';
  static const _pfxCheckin = 'ls_ci_';
  static const _pfxLocked  = 'ls_lk_';

  // ─── Init ─────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── Load (synchronous after init) ───────────────────────────────────────

  static SavedState load(List<String> activityIds) {
    final seed = _prefs.getInt(_keySeed) ?? 0;
    final enabledMap = <String, bool>{};
    final checkinMap = <String, int>{};
    final lockedMap  = <String, bool>{};

    for (final id in activityIds) {
      final e = _prefs.getBool('$_pfxEnabled$id');
      if (e != null) enabledMap[id] = e;

      final c = _prefs.getInt('$_pfxCheckin$id');
      if (c != null) checkinMap[id] = c;

      final l = _prefs.getBool('$_pfxLocked$id');
      if (l != null) lockedMap[id] = l;
    }

    return SavedState(
      seed: seed,
      enabledMap: enabledMap,
      checkinMap: checkinMap,
      lockedMap: lockedMap,
    );
  }

  // ─── Save (fire-and-forget; synchronous on web localStorage) ─────────────

  static void saveSeed(int seed)               => _prefs.setInt(_keySeed, seed);
  static void saveEnabled(String id, bool v)   => _prefs.setBool('$_pfxEnabled$id', v);
  static void saveCheckin(String id, int v)    => _prefs.setInt('$_pfxCheckin$id', v);
  static void saveLocked(String id, bool v)    => _prefs.setBool('$_pfxLocked$id', v);
}

// ─── Persisted snapshot ───────────────────────────────────────────────────────

class SavedState {
  final int seed;
  final Map<String, bool> enabledMap; // activityId → enabled
  final Map<String, int>  checkinMap; // activityId → CheckStatus.index
  final Map<String, bool> lockedMap;  // activityId → locked

  const SavedState({
    required this.seed,
    required this.enabledMap,
    required this.checkinMap,
    required this.lockedMap,
  });
}
