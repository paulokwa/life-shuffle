class Activity {
  final String id;
  String title;
  String category;
  int durationMinutes;
  String preferredTime; // 'morning' | 'afternoon' | 'evening' | 'anytime'
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

  Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.durationMinutes,
    this.preferredTime = 'anytime',
    this.enabled = true,
  });

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
}
