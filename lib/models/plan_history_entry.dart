import 'mock_data.dart' show CheckStatus;

/// Where a [PlanHistoryEntry] occurrence came from: the rule-based
/// generator, a user-added manual plan item, or an accepted outside event
/// (itself stored as a manual plan item; see
/// `ManualPlanItem.isOutsideEvent`).
enum PlanHistorySource { generated, manual, outsideEvent }

/// A point-in-time snapshot of one dated planned occurrence, captured by
/// `AppState` independently of the live `Activity`/`ManualPlanItem` it came
/// from. Once an occurrence's date is today or earlier, its snapshot fields
/// (`title`/`timeSlot`/`durationMinutes`/`category`/dimensions) stay frozen
/// on later passive rebuilds (regeneration, reload, a source activity
/// rename) - only an explicit per-occurrence edit, check-in, lock, or
/// removal updates an existing entry after that point. See
/// `AppState._upsertArchiveEntry`.
class PlanHistoryEntry {
  const PlanHistoryEntry({
    required this.occurrenceKey,
    required this.date,
    this.sourceActivityId,
    required this.title,
    required this.timeSlot,
    required this.durationMinutes,
    required this.category,
    required this.difficulty,
    required this.energy,
    required this.social,
    this.source = PlanHistorySource.generated,
    this.status = CheckStatus.none,
    this.locked = false,
    this.removed = false,
    required this.createdAtMillis,
    required this.updatedAtMillis,
  });

  /// Stable `yyyy-MM-dd:activityId` key shared with the live check-in/lock
  /// occurrence maps (see `DayPlan.dateKey`).
  final String occurrenceKey;
  final DateTime date;

  /// The reusable library `Activity.id` this occurrence came from, when one
  /// exists. Null for a one-off manual/outside-event item never saved to
  /// the activity library.
  final String? sourceActivityId;
  final String title;
  final String timeSlot;
  final int durationMinutes;
  final String category;
  final int difficulty;
  final String energy;
  final String social;
  final PlanHistorySource source;
  final CheckStatus status;
  final bool locked;
  final bool removed;
  final int createdAtMillis;
  final int updatedAtMillis;

  Map<String, dynamic> toMap() {
    return {
      'occurrenceKey': occurrenceKey,
      'dateMillis': date.millisecondsSinceEpoch,
      if (sourceActivityId != null) 'sourceActivityId': sourceActivityId,
      'title': title,
      'timeSlot': timeSlot,
      'durationMinutes': durationMinutes,
      'category': category,
      'difficulty': difficulty,
      'energy': energy,
      'social': social,
      'source': source.name,
      'status': status.index,
      'locked': locked,
      'removed': removed,
      'createdAtMillis': createdAtMillis,
      'updatedAtMillis': updatedAtMillis,
    };
  }

  factory PlanHistoryEntry.fromMap(Map<String, dynamic> map) {
    final rawDateMillis = map['dateMillis'];
    final dateMillis = rawDateMillis is int
        ? rawDateMillis
        : (rawDateMillis is num ? rawDateMillis.toInt() : null);
    final date = dateMillis == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(dateMillis);
    final statusIndex = map['status'];

    return PlanHistoryEntry(
      occurrenceKey:
          map['occurrenceKey'] is String ? map['occurrenceKey'] as String : '',
      date: DateTime(date.year, date.month, date.day),
      sourceActivityId: map['sourceActivityId'] is String
          ? map['sourceActivityId'] as String
          : null,
      title: map['title'] is String ? map['title'] as String : 'Untitled',
      timeSlot:
          map['timeSlot'] is String ? map['timeSlot'] as String : '9:00 AM',
      durationMinutes: _readInt(map['durationMinutes'], 45),
      category:
          map['category'] is String ? map['category'] as String : 'Outside',
      difficulty: _readInt(map['difficulty'], 3).clamp(1, 5),
      energy: map['energy'] is String ? map['energy'] as String : 'medium',
      social: map['social'] is String ? map['social'] as String : 'either',
      source: PlanHistorySource.values.firstWhere(
        (value) => value.name == map['source'],
        orElse: () => PlanHistorySource.generated,
      ),
      status: statusIndex is int &&
              statusIndex >= 0 &&
              statusIndex < CheckStatus.values.length
          ? CheckStatus.values[statusIndex]
          : CheckStatus.none,
      locked: map['locked'] is bool ? map['locked'] as bool : false,
      removed: map['removed'] is bool ? map['removed'] as bool : false,
      createdAtMillis: _readInt(map['createdAtMillis'], 0),
      updatedAtMillis: _readInt(map['updatedAtMillis'], 0),
    );
  }

  static int _readInt(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }
}
