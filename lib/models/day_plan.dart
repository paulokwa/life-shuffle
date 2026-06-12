import 'activity.dart';
import 'mock_data.dart' show CheckStatus;

class PlannedActivity {
  final Activity activity;
  final String timeSlot;
  CheckStatus status;
  bool locked;

  PlannedActivity({
    required this.activity,
    required this.timeSlot,
    this.status = CheckStatus.none,
    this.locked = false,
  });

  String get id => activity.id;
  String get title => activity.title;
  String get category => activity.category;
  String get time => timeSlot;
}

class DayPlan {
  final DateTime date;
  final List<PlannedActivity> activities;

  DayPlan({required this.date, required this.activities});

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
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[date.weekday - 1]} · ${date.day} ${months[date.month - 1]}';
  }
}
