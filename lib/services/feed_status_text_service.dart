/// Plain-language "Feed updated ..." text for the Settings screen, derived
/// from `AppState.cachedIcsUpdatedAtMillis`. Kept separate from
/// `AppState`/`SettingsScreen` so the wording can be unit-tested with an
/// explicit `now` instead of depending on the real clock.
class FeedStatusTextService {
  FeedStatusTextService._();

  static String lastUpdatedLabel(
    int? cachedIcsUpdatedAtMillis, {
    DateTime? now,
  }) {
    if (cachedIcsUpdatedAtMillis == null) return 'Feed not generated yet';

    final updated = DateTime.fromMillisecondsSinceEpoch(
      cachedIcsUpdatedAtMillis,
    );
    final current = now ?? DateTime.now();
    // Clamp clock skew (e.g. a cached timestamp that lands a moment in the
    // future) to zero instead of printing a negative duration.
    final diff = current.difference(updated);
    final safeDiff = diff.isNegative ? Duration.zero : diff;
    if (safeDiff.inSeconds < 60) return 'Feed updated just now';
    if (safeDiff.inMinutes < 60) {
      final minutes = safeDiff.inMinutes;
      return 'Feed updated $minutes minute${minutes == 1 ? '' : 's'} ago';
    }

    final time = _formatClockTime(updated);
    if (_isSameDate(updated, current)) {
      return 'Feed updated today at $time';
    }
    final yesterday = current.subtract(const Duration(days: 1));
    if (_isSameDate(updated, yesterday)) {
      return 'Feed updated yesterday at $time';
    }
    return 'Feed updated ${updated.month}/${updated.day} at $time';
  }

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _formatClockTime(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $period';
  }
}
