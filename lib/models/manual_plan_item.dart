import 'activity.dart';
import 'day_plan.dart';
import 'mock_data.dart' show CheckStatus;

/// A user-added plan item that exists independently of the rule-based
/// generator. Manual items are pinned to a specific date/time and survive
/// regeneration, view switches, and reload/sync by default.
///
/// They are *not* source activities/templates. When created from an existing
/// activity, the source [Activity] is copied at creation time and is never
/// mutated by edits to this manual item. When a one-off item is saved to the
/// activity library, a separate [Activity] is created there; this model's
/// [sourceActivityId] merely records that link.
class ManualPlanItem {
  ManualPlanItem({
    required this.id,
    required this.dateKey,
    required this.title,
    required this.timeSlot,
    required this.category,
    required this.durationMinutes,
    this.difficulty = 3,
    this.energy = 'medium',
    this.social = 'either',
    this.sourceActivityId,
  });

  /// Stable identifier for this manual item.
  final String id;

  /// `yyyy-MM-dd` key for the date this item belongs to.
  String dateKey;

  String title;
  String timeSlot;
  String category;
  int durationMinutes;
  int difficulty;
  String energy;
  String social;

  /// Optional reference to the library activity this item was created from
  /// (existing-activity path) or saved into (one-off + "Save to library").
  String? sourceActivityId;

  ManualPlanItem copy() {
    return ManualPlanItem(
      id: id,
      dateKey: dateKey,
      title: title,
      timeSlot: timeSlot,
      category: category,
      durationMinutes: durationMinutes,
      difficulty: difficulty,
      energy: energy,
      social: social,
      sourceActivityId: sourceActivityId,
    );
  }

  /// Builds a standalone [PlannedActivity] for this manual item. The backing
  /// [Activity] is synthetic (`id` is `manual_${id}`) so it never collides
  /// with generated occurrences of the same source activity and is never used
  /// by the generator (it is marked `enabled: false` and lives outside the
  /// activity library).
  PlannedActivity toPlannedActivity({
    CheckStatus status = CheckStatus.none,
    bool locked = false,
  }) {
    return PlannedActivity(
      activity: Activity(
        id: 'manual_$id',
        title: title,
        category: category,
        durationMinutes: durationMinutes,
        preferredTime: 'anytime',
        difficulty: difficulty,
        energy: energy,
        social: social,
        maxPerWeek: 1,
        allowedWeekdays: const [1],
        noConsecutiveDays: false,
        enabled: false,
      ),
      timeSlot: timeSlot,
      status: status,
      locked: locked,
      manualItemId: id,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dateKey': dateKey,
      'title': title,
      'timeSlot': timeSlot,
      'category': category,
      'durationMinutes': durationMinutes,
      'difficulty': difficulty,
      'energy': energy,
      'social': social,
      if (sourceActivityId != null) 'sourceActivityId': sourceActivityId,
    };
  }

  factory ManualPlanItem.fromMap(Map<String, dynamic> map) {
    return ManualPlanItem(
      id: map['id'] is String ? map['id'] as String : '',
      dateKey: map['dateKey'] is String ? map['dateKey'] as String : '',
      title: map['title'] is String ? map['title'] as String : 'Untitled',
      timeSlot:
          map['timeSlot'] is String ? map['timeSlot'] as String : '9:00 AM',
      category: Activity.categories.contains(map['category'])
          ? map['category'] as String
          : 'Outside',
      durationMinutes: _readDurationMinutes(map['durationMinutes']),
      difficulty: _readDifficulty(map['difficulty']),
      energy: _readEnergy(map['energy']),
      social: _readSocial(map['social']),
      sourceActivityId: map['sourceActivityId'] is String
          ? map['sourceActivityId'] as String
          : null,
    );
  }

  static int _readDifficulty(Object? value) {
    if (value is int) return value.clamp(1, 5).toInt();
    if (value is num) return value.toInt().clamp(1, 5).toInt();
    return 3;
  }

  static String _readEnergy(Object? value) {
    final normalized = (value is String ? value : '').trim().toLowerCase();
    return Activity.energyLevels.contains(normalized) ? normalized : 'medium';
  }

  static String _readSocial(Object? value) {
    final normalized = (value is String ? value : '').trim().toLowerCase();
    return Activity.socialLevels.contains(normalized) ? normalized : 'either';
  }

  static int _readDurationMinutes(Object? value) {
    if (value is int && value > 0) return value.clamp(5, 720).toInt();
    if (value is num && value > 0) return value.toInt().clamp(5, 720).toInt();
    return 45;
  }
}
