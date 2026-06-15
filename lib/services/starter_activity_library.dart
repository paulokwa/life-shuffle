import '../models/activity.dart';

class StarterActivityGroup {
  const StarterActivityGroup({
    required this.category,
    required this.activities,
  });

  final String category;
  final List<Activity> activities;
}

class StarterActivityLibrary {
  StarterActivityLibrary._();

  static final List<StarterActivityGroup> groups = [
    StarterActivityGroup(
      category: 'At home',
      activities: [
        _starter(
          id: 'at_home_reset_one_room',
          title: 'Reset one room',
          category: 'At home',
          durationMinutes: 30,
          preferredTime: 'afternoon',
          maxPerWeek: 2,
        ),
        _starter(
          id: 'at_home_read_on_the_couch',
          title: 'Read on the couch',
          category: 'At home',
          durationMinutes: 45,
          preferredTime: 'evening',
          maxPerWeek: 3,
        ),
        _starter(
          id: 'at_home_music_and_tidy',
          title: 'Music and tidy',
          category: 'At home',
          durationMinutes: 25,
          preferredTime: 'anytime',
          maxPerWeek: 2,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Outside',
      activities: [
        _starter(
          id: 'outside_neighbourhood_walk',
          title: 'Neighbourhood walk',
          category: 'Outside',
          durationMinutes: 30,
          preferredTime: 'morning',
          maxPerWeek: 3,
          noConsecutiveDays: true,
        ),
        _starter(
          id: 'outside_waterfront_walk',
          title: 'Walk waterfront',
          category: 'Outside',
          durationMinutes: 45,
          preferredTime: 'morning',
          maxPerWeek: 2,
        ),
        _starter(
          id: 'outside_farmers_market',
          title: 'Farmers market',
          category: 'Outside',
          durationMinutes: 60,
          preferredTime: 'morning',
          allowedWeekdays: [6, 7],
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Health / movement',
      activities: [
        _starter(
          id: 'health_stretch_session',
          title: 'Stretch session',
          category: 'Health / movement',
          durationMinutes: 20,
          preferredTime: 'morning',
          maxPerWeek: 3,
          noConsecutiveDays: true,
        ),
        _starter(
          id: 'health_gentle_yoga',
          title: 'Gentle yoga',
          category: 'Health / movement',
          durationMinutes: 30,
          preferredTime: 'morning',
          maxPerWeek: 2,
          noConsecutiveDays: true,
        ),
        _starter(
          id: 'health_bodyweight_basics',
          title: 'Bodyweight basics',
          category: 'Health / movement',
          durationMinutes: 25,
          preferredTime: 'afternoon',
          maxPerWeek: 2,
          noConsecutiveDays: true,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Social',
      activities: [
        _starter(
          id: 'social_call_a_friend',
          title: 'Call a friend',
          category: 'Social',
          durationMinutes: 30,
          preferredTime: 'evening',
          maxPerWeek: 2,
          noConsecutiveDays: true,
        ),
        _starter(
          id: 'social_coffee_with_someone',
          title: 'Coffee with someone',
          category: 'Social',
          durationMinutes: 60,
          preferredTime: 'afternoon',
          maxPerWeek: 1,
        ),
        _starter(
          id: 'social_board_games',
          title: 'Board games night',
          category: 'Social',
          durationMinutes: 120,
          preferredTime: 'evening',
          allowedWeekdays: [5, 6, 7],
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Creative',
      activities: [
        _starter(
          id: 'creative_sketch_or_journal',
          title: 'Sketch or journal',
          category: 'Creative',
          durationMinutes: 45,
          preferredTime: 'afternoon',
          maxPerWeek: 2,
        ),
        _starter(
          id: 'creative_cafe_reading',
          title: 'Cafe reading',
          category: 'Creative',
          durationMinutes: 90,
          preferredTime: 'morning',
          maxPerWeek: 1,
        ),
        _starter(
          id: 'creative_photo_walk',
          title: 'Photo walk',
          category: 'Creative',
          durationMinutes: 45,
          preferredTime: 'afternoon',
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Rest',
      activities: [
        _starter(
          id: 'rest_nap_or_quiet_time',
          title: 'Nap or quiet time',
          category: 'Rest',
          durationMinutes: 30,
          preferredTime: 'afternoon',
          maxPerWeek: 3,
        ),
        _starter(
          id: 'rest_tea_and_no_phone',
          title: 'Tea and no phone',
          category: 'Rest',
          durationMinutes: 20,
          preferredTime: 'evening',
          maxPerWeek: 3,
        ),
        _starter(
          id: 'rest_slow_morning',
          title: 'Slow morning',
          category: 'Rest',
          durationMinutes: 60,
          preferredTime: 'morning',
          allowedWeekdays: [6, 7],
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Food',
      activities: [
        _starter(
          id: 'food_cook_together',
          title: 'Cook together',
          category: 'Food',
          durationMinutes: 60,
          preferredTime: 'evening',
          maxPerWeek: 2,
        ),
        _starter(
          id: 'food_try_new_recipe',
          title: 'Try a new recipe',
          category: 'Food',
          durationMinutes: 75,
          preferredTime: 'evening',
          allowedWeekdays: [5, 6, 7],
          maxPerWeek: 1,
        ),
        _starter(
          id: 'food_easy_brunch',
          title: 'Easy brunch',
          category: 'Food',
          durationMinutes: 60,
          preferredTime: 'morning',
          allowedWeekdays: [6, 7],
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Chores / life admin',
      activities: [
        _starter(
          id: 'chores_laundry_reset',
          title: 'Laundry reset',
          category: 'Chores / life admin',
          durationMinutes: 45,
          preferredTime: 'afternoon',
          maxPerWeek: 2,
        ),
        _starter(
          id: 'chores_paperwork_sprint',
          title: 'Paperwork sprint',
          category: 'Chores / life admin',
          durationMinutes: 30,
          preferredTime: 'morning',
          maxPerWeek: 1,
        ),
        _starter(
          id: 'chores_grocery_plan',
          title: 'Grocery plan',
          category: 'Chores / life admin',
          durationMinutes: 25,
          preferredTime: 'anytime',
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Couple time',
      activities: [
        _starter(
          id: 'couple_movie_night_in',
          title: 'Movie night in',
          category: 'Couple time',
          durationMinutes: 120,
          preferredTime: 'evening',
          allowedWeekdays: [5, 6, 7],
          maxPerWeek: 1,
        ),
        _starter(
          id: 'couple_walk_and_talk',
          title: 'Walk and talk',
          category: 'Couple time',
          durationMinutes: 45,
          preferredTime: 'evening',
          maxPerWeek: 2,
          noConsecutiveDays: true,
        ),
        _starter(
          id: 'couple_plan_a_date',
          title: 'Plan a date',
          category: 'Couple time',
          durationMinutes: 30,
          preferredTime: 'evening',
          maxPerWeek: 1,
        ),
      ],
    ),
    StarterActivityGroup(
      category: 'Low-energy ideas',
      activities: [
        _starter(
          id: 'low_energy_short_drive',
          title: 'Short scenic drive',
          category: 'Low-energy ideas',
          durationMinutes: 45,
          preferredTime: 'afternoon',
          maxPerWeek: 1,
        ),
        _starter(
          id: 'low_energy_watch_comfort_show',
          title: 'Comfort show',
          category: 'Low-energy ideas',
          durationMinutes: 45,
          preferredTime: 'evening',
          maxPerWeek: 2,
        ),
        _starter(
          id: 'low_energy_sit_outside',
          title: 'Sit outside',
          category: 'Low-energy ideas',
          durationMinutes: 20,
          preferredTime: 'afternoon',
          maxPerWeek: 3,
        ),
      ],
    ),
  ];

  static Activity _starter({
    required String id,
    required String title,
    required String category,
    required int durationMinutes,
    required String preferredTime,
    int maxPerWeek = 1,
    List<int>? allowedWeekdays,
    bool noConsecutiveDays = false,
  }) {
    return Activity(
      id: 'starter_$id',
      title: title,
      category: category,
      durationMinutes: durationMinutes,
      preferredTime: preferredTime,
      maxPerWeek: maxPerWeek,
      allowedWeekdays: allowedWeekdays ?? Activity.allWeekdays,
      noConsecutiveDays: noConsecutiveDays,
      enabled: true,
    );
  }
}
