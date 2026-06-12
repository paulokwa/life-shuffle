class Activity {
  final String id;
  final String title;
  final String category;
  final String duration;
  final String preferredTime; // 'morning' | 'afternoon' | 'evening' | 'anytime'
  bool enabled;

  Activity({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    this.preferredTime = 'anytime',
    this.enabled = true,
  });
}
