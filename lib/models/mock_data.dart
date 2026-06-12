enum CheckStatus { none, done, partly, skipped }

class ActivityMock {
  final String id;
  final String title;
  final String time;
  final String category;
  CheckStatus status;

  ActivityMock({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    this.status = CheckStatus.none,
  });
}

final List<ActivityMock> todayActivities = [
  ActivityMock(
    id: '1',
    title: 'Cafe reading',
    time: '11:00 AM',
    category: 'Creative',
    status: CheckStatus.done,
  ),
  ActivityMock(
    id: '2',
    title: 'Walk waterfront',
    time: '6:30 PM',
    category: 'Outside',
    status: CheckStatus.none,
  ),
  ActivityMock(
    id: '3',
    title: 'Cook together',
    time: '8:00 PM',
    category: 'Couple time',
    status: CheckStatus.none,
  ),
];

const String calendarName = 'Kwame and Laura';
const String profileInitial = 'K';
const String todayDate = 'Thursday, 12 June';
const String nextUpTitle = 'Walk waterfront';
const String nextUpTime = '6:30 PM';
const int weekPlanned = 5;
const int weekDone = 2;
const int weekPartly = 1;
