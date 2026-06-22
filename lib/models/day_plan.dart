import 'activity.dart';
import 'mock_data.dart' show CheckStatus;

class PlannedActivity {
  final Activity activity;

  /// The actual scheduled display time for this occurrence (e.g. `7:30
  /// PM`), distinct from [Activity.preferredTime]'s morning/afternoon/
  /// evening/anytime *rule*. Mutable so [AppState.editPlannedOccurrence]
  /// (`../state/app_state.dart`) can set a real per-occurrence time without
  /// touching the source [activity], the same way [status] and [locked] are
  /// already mutated directly on this one-occurrence instance.
  String timeSlot;
  CheckStatus status;
  bool locked;

  /// Per-occurrence overrides set by `AppState.editPlannedOccurrence`.
  /// `null` means "use the source [activity]'s value" - see [category],
  /// [difficulty], [energy], [social].
  String? categoryOverride;
  int? difficultyOverride;
  String? energyOverride;
  String? socialOverride;

  PlannedActivity({
    required this.activity,
    required this.timeSlot,
    this.status = CheckStatus.none,
    this.locked = false,
    this.categoryOverride,
    this.difficultyOverride,
    this.energyOverride,
    this.socialOverride,
  });

  String get id => activity.id;
  String get title => activity.title;
  String get category => categoryOverride ?? activity.category;
  String get time => timeSlot;
  int get difficulty => difficultyOverride ?? activity.difficulty;
  String get energy => energyOverride ?? activity.energy;
  String get social => socialOverride ?? activity.social;
}

/// A per-occurrence edit made through the focused "Edit this plan item"
/// sheet (see `AppState.editPlannedOccurrence`): the actual scheduled time,
/// category, and enabled planning dimensions for one generated instance of
/// an activity, keyed by `yyyy-MM-dd:activityId` (see [DayPlan.dateKey]).
/// Never changes the source [Activity] template. `null` fields mean "no
/// override for this field" - [difficulty]/[energy]/[social] stay `null`
/// when their app-settings dimension toggle is off, since the editor
/// doesn't show or collect a value for a disabled dimension.
class OccurrenceOverride {
  const OccurrenceOverride({
    this.timeSlot,
    this.category,
    this.difficulty,
    this.energy,
    this.social,
  });

  final String? timeSlot;
  final String? category;
  final int? difficulty;
  final String? energy;
  final String? social;

  Map<String, dynamic> toMap() {
    return {
      if (timeSlot != null) 'timeSlot': timeSlot,
      if (category != null) 'category': category,
      if (difficulty != null) 'difficulty': difficulty,
      if (energy != null) 'energy': energy,
      if (social != null) 'social': social,
    };
  }

  factory OccurrenceOverride.fromMap(Map<String, dynamic> map) {
    final difficulty = map['difficulty'];
    return OccurrenceOverride(
      timeSlot: map['timeSlot'] is String ? map['timeSlot'] as String : null,
      category: map['category'] is String ? map['category'] as String : null,
      difficulty: difficulty is int
          ? difficulty
          : (difficulty is num ? difficulty.toInt() : null),
      energy: map['energy'] is String ? map['energy'] as String : null,
      social: map['social'] is String ? map['social'] as String : null,
    );
  }
}

class DayPlan {
  final DateTime date;
  final List<PlannedActivity> activities;

  DayPlan({required this.date, required this.activities});

  /// Stable `yyyy-MM-dd` key for [date], used to scope check-in/lock
  /// overlays to the exact occurrence date an activity was planned on.
  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String get weekdayShort {
    const d = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return d[date.weekday - 1];
  }

  String get dayOfMonth => '${date.day}';

  String get fullLabel {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[date.weekday - 1]} · ${date.day} ${months[date.month - 1]}';
  }
}
