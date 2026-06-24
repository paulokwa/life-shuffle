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
    this.outsideEventId,
    this.outsideEventSourceName,
    this.outsideEventSourceUrl,
    this.outsideEventTicketUrl,
    this.outsideEventPriceLabel,
    this.outsideEventVenueName,
    this.outsideEventAddress,
    this.outsideEventSummary,
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

  /// Optional sourced-event metadata. These fields keep outside events
  /// separate from reusable [Activity] templates while still letting them
  /// reuse the fixed, regeneration-safe manual-plan-item path.
  String? outsideEventId;
  String? outsideEventSourceName;
  String? outsideEventSourceUrl;
  String? outsideEventTicketUrl;
  String? outsideEventPriceLabel;
  String? outsideEventVenueName;
  String? outsideEventAddress;
  String? outsideEventSummary;

  bool get isOutsideEvent => outsideEventId != null;

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
      outsideEventId: outsideEventId,
      outsideEventSourceName: outsideEventSourceName,
      outsideEventSourceUrl: outsideEventSourceUrl,
      outsideEventTicketUrl: outsideEventTicketUrl,
      outsideEventPriceLabel: outsideEventPriceLabel,
      outsideEventVenueName: outsideEventVenueName,
      outsideEventAddress: outsideEventAddress,
      outsideEventSummary: outsideEventSummary,
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
      if (outsideEventId != null) 'outsideEventId': outsideEventId,
      if (outsideEventSourceName != null)
        'outsideEventSourceName': outsideEventSourceName,
      if (outsideEventSourceUrl != null)
        'outsideEventSourceUrl': outsideEventSourceUrl,
      if (outsideEventTicketUrl != null)
        'outsideEventTicketUrl': outsideEventTicketUrl,
      if (outsideEventPriceLabel != null)
        'outsideEventPriceLabel': outsideEventPriceLabel,
      if (outsideEventVenueName != null)
        'outsideEventVenueName': outsideEventVenueName,
      if (outsideEventAddress != null)
        'outsideEventAddress': outsideEventAddress,
      if (outsideEventSummary != null)
        'outsideEventSummary': outsideEventSummary,
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
      outsideEventId: _readNullableString(map['outsideEventId']),
      outsideEventSourceName:
          _readNullableString(map['outsideEventSourceName']),
      outsideEventSourceUrl: _readNullableString(map['outsideEventSourceUrl']),
      outsideEventTicketUrl: _readNullableString(map['outsideEventTicketUrl']),
      outsideEventPriceLabel:
          _readNullableString(map['outsideEventPriceLabel']),
      outsideEventVenueName: _readNullableString(map['outsideEventVenueName']),
      outsideEventAddress: _readNullableString(map['outsideEventAddress']),
      outsideEventSummary: _readNullableString(map['outsideEventSummary']),
    );
  }

  static String? _readNullableString(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
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
