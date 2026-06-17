class Activity {
  final String id;
  String title;
  String category;
  int durationMinutes;
  String preferredTime; // 'morning' | 'afternoon' | 'evening' | 'anytime'
  int difficulty;
  String energy;
  String social;
  int maxPerWeek;
  List<int>
      allowedWeekdays; // DateTime.weekday values: Monday 1 through Sunday 7
  bool noConsecutiveDays;
  bool enabled;

  static const categories = [
    'At home',
    'Outside',
    'Health / movement',
    'Social',
    'Creative',
    'Rest',
    'Food',
    'Chores / life admin',
    'Couple time',
    'Low-energy ideas',
  ];

  static const preferredTimes = [
    'anytime',
    'morning',
    'afternoon',
    'evening',
  ];

  static const energyLevels = [
    'low',
    'medium',
    'high',
  ];

  static const socialLevels = [
    'solo',
    'together',
    'group',
    'either',
  ];

  static const allWeekdays = [1, 2, 3, 4, 5, 6, 7];

  Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.durationMinutes,
    this.preferredTime = 'anytime',
    int? difficulty,
    String? energy,
    String? social,
    int? maxPerWeek,
    List<int>? allowedWeekdays,
    this.noConsecutiveDays = false,
    this.enabled = true,
  })  : difficulty = _normalizeDifficulty(difficulty),
        energy = _normalizeOption(
          energy,
          fallback: 'medium',
          allowed: energyLevels,
        ),
        social = _normalizeOption(
          social,
          fallback: 'either',
          allowed: socialLevels,
        ),
        maxPerWeek = _normalizeMaxPerWeek(maxPerWeek),
        allowedWeekdays = _normalizeAllowedWeekdays(allowedWeekdays);

  String get duration {
    if (durationMinutes < 60) return '$durationMinutes min';
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (mins == 0) return '$hours ${hours == 1 ? "hr" : "hrs"}';
    return '$hours hr $mins min';
  }

  Activity copy() {
    return Activity(
      id: id,
      title: title,
      category: category,
      durationMinutes: durationMinutes,
      preferredTime: preferredTime,
      difficulty: difficulty,
      energy: energy,
      social: social,
      maxPerWeek: maxPerWeek,
      allowedWeekdays: List<int>.from(allowedWeekdays),
      noConsecutiveDays: noConsecutiveDays,
      enabled: enabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'durationMinutes': durationMinutes,
      'preferredTime': preferredTime,
      'difficulty': difficulty,
      'energy': energy,
      'social': social,
      'maxPerWeek': maxPerWeek,
      'allowedWeekdays': allowedWeekdays,
      'noConsecutiveDays': noConsecutiveDays,
      'enabled': enabled,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    final id = _readString(
      map['id'],
      'activity_${DateTime.now().microsecondsSinceEpoch}',
    );
    return Activity(
      id: id,
      title: _readString(map['title'], 'Untitled activity'),
      category: _readCategory(map['category']),
      durationMinutes: _readDurationMinutes(
        map['durationMinutes'] ?? map['duration'],
      ),
      preferredTime: _readPreferredTime(map['preferredTime']),
      difficulty: _readDifficulty(map['difficulty']),
      energy: _readEnergy(map['energy']),
      social: _readSocial(map['social']),
      maxPerWeek: _readMaxPerWeek(map['maxPerWeek']),
      allowedWeekdays: _readAllowedWeekdays(map['allowedWeekdays']),
      noConsecutiveDays: map['noConsecutiveDays'] is bool
          ? map['noConsecutiveDays'] as bool
          : false,
      enabled: map['enabled'] is bool ? map['enabled'] as bool : true,
    );
  }

  static String _readString(Object? value, String fallback) {
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  static String _readCategory(Object? value) {
    final category = _readString(value, 'Outside');
    return categories.contains(category) ? category : 'Outside';
  }

  static String _readPreferredTime(Object? value) {
    final preferredTime = _readString(value, 'anytime');
    return preferredTimes.contains(preferredTime) ? preferredTime : 'anytime';
  }

  static int _readDurationMinutes(Object? value) {
    if (value is int && value > 0) return value.clamp(5, 720).toInt();
    if (value is num && value > 0) {
      return value.toInt().clamp(5, 720).toInt();
    }
    if (value is String) {
      final number = int.tryParse(
        RegExp(r'\d+').firstMatch(value)?.group(0) ?? '',
      );
      if (number != null && number > 0) {
        final lower = value.toLowerCase();
        if (lower.contains('hr') || lower.contains('hour')) {
          return (number * 60).clamp(5, 720).toInt();
        }
        return number.clamp(5, 720).toInt();
      }
    }
    return 45;
  }

  static int _readMaxPerWeek(Object? value) {
    if (value is int && value > 0) return _normalizeMaxPerWeek(value);
    if (value is num && value > 0) return _normalizeMaxPerWeek(value.toInt());
    return 1;
  }

  static int _readDifficulty(Object? value) {
    if (value is int) return _normalizeDifficulty(value);
    if (value is num) return _normalizeDifficulty(value.toInt());
    return 3;
  }

  static String _readEnergy(Object? value) {
    return _normalizeOption(
      value is String ? value : null,
      fallback: 'medium',
      allowed: energyLevels,
    );
  }

  static String _readSocial(Object? value) {
    return _normalizeOption(
      value is String ? value : null,
      fallback: 'either',
      allowed: socialLevels,
    );
  }

  static int _normalizeDifficulty(int? value) {
    if (value == null) return 3;
    return value.clamp(1, 5).toInt();
  }

  static List<int> _readAllowedWeekdays(Object? value) {
    if (value is Iterable) {
      return _normalizeAllowedWeekdays(
          value.whereType<num>().map((v) => v.toInt()));
    }
    return List<int>.from(allWeekdays);
  }

  static int _normalizeMaxPerWeek(int? value) {
    if (value == null || value < 1) return 1;
    return value.clamp(1, 7).toInt();
  }

  static List<int> _normalizeAllowedWeekdays(Iterable<int>? value) {
    final weekdays = (value ?? allWeekdays)
        .where((day) => day >= 1 && day <= 7)
        .toSet()
        .toList()
      ..sort();
    return weekdays.isEmpty ? List<int>.from(allWeekdays) : weekdays;
  }

  static String _normalizeOption(
    String? value, {
    required String fallback,
    required List<String> allowed,
  }) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return fallback;
    return allowed.contains(normalized) ? normalized : fallback;
  }

  static String optionLabel(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
