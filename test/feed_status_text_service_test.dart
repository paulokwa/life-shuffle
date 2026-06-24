import 'package:flutter_test/flutter_test.dart';
import 'package:life_shuffle/services/feed_status_text_service.dart';

void main() {
  test('reports not generated yet when there is no cached timestamp', () {
    expect(
      FeedStatusTextService.lastUpdatedLabel(null),
      'Feed not generated yet',
    );
  });

  test('reports just now for a timestamp under a minute old', () {
    final now = DateTime(2026, 6, 23, 15, 42);
    final updatedAt = now.subtract(const Duration(seconds: 30));
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated just now',
    );
  });

  test('reports minutes ago for a timestamp under an hour old', () {
    final now = DateTime(2026, 6, 23, 15, 42);
    final updatedAt = now.subtract(const Duration(minutes: 12));
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated 12 minutes ago',
    );
  });

  test('uses singular minute for exactly one minute ago', () {
    final now = DateTime(2026, 6, 23, 15, 42);
    final updatedAt = now.subtract(const Duration(minutes: 1));
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated 1 minute ago',
    );
  });

  test('reports today at a clock time for an older same-day timestamp', () {
    final now = DateTime(2026, 6, 23, 18, 30);
    final updatedAt = DateTime(2026, 6, 23, 15, 42);
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated today at 3:42 PM',
    );
  });

  test('reports yesterday at a clock time for a one-day-old timestamp', () {
    final now = DateTime(2026, 6, 23, 9, 5);
    final updatedAt = DateTime(2026, 6, 22, 8, 0);
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated yesterday at 8:00 AM',
    );
  });

  test('reports a month/day date for an older timestamp', () {
    final now = DateTime(2026, 6, 23, 9, 5);
    final updatedAt = DateTime(2026, 6, 1, 0, 0);
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated 6/1 at 12:00 AM',
    );
  });

  test('clamps a timestamp slightly in the future to just now', () {
    final now = DateTime(2026, 6, 23, 15, 42);
    final updatedAt = now.add(const Duration(seconds: 5));
    expect(
      FeedStatusTextService.lastUpdatedLabel(
        updatedAt.millisecondsSinceEpoch,
        now: now,
      ),
      'Feed updated just now',
    );
  });
}
