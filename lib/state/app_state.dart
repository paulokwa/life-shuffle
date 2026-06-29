import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/day_plan.dart';
import '../models/export_print_options.dart';
import '../models/generated_plan_range.dart';
import '../models/manual_plan_item.dart';
import '../models/event_suggestion.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/plan_history_entry.dart';
import '../models/range_type.dart';
import '../models/sync_message.dart';
import '../models/source_list_snapshot.dart';
import '../models/user_event_source.dart';
import '../services/curated_rss_feed_registry.dart';
import '../services/event_dedupe_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/ics_calendar_service.dart';
import '../services/outside_event_adapters.dart';
import '../services/outside_event_discovery_service.dart';
import '../services/outside_event_organizer_service.dart';
import '../services/outside_event_source_adapter.dart';
import '../services/persistence_service.dart';
import '../services/planner_service.dart' show PlannerService, PlanStyle;
import '../services/range_planner_service.dart'
    show RangePlannerGenerationResult, RangePlannerService;

/// Which sync operation a recorded sync failure came from, used only to
/// pick the right plain-language wording in [AppState._buildSyncMessage].
enum _SyncOperation { load, save, profile }

/// Outcome of [AppState.refreshPublishedFeedNow], used by the Settings
/// "Refresh published feed" action to show an accurate message.
/// [syncFailed] is distinct from [unavailable] on purpose: the local
/// device's plan *did* refresh, but the public feed (served from
/// Firestore, not this device) did not, so callers must not report that
/// case as success.
enum FeedRefreshResult { unavailable, success, syncFailed }

typedef LoadDefaultCalendar = Future<FirestoreCalendar?> Function(
    String userId);
typedef LoadAccessibleCalendars = Future<List<FirestoreCalendar>> Function(
  String userId,
);
typedef SaveFirestoreState = Future<FirestoreSyncResult> Function(
  String userId,
  SavedState state,
);
typedef SaveSelectedFirestoreState = Future<FirestoreSyncResult> Function(
  String userId,
  String calendarId,
  SavedState state,
);
typedef UpsertUserProfile = Future<FirestoreSyncResult> Function({
  required String userId,
  String? email,
  String? displayName,
});
typedef AddCalendarMember = Future<AddCalendarMemberResult> Function({
  required String calendarId,
  required String email,
});
typedef CreateCalendar = Future<CreateCalendarResult> Function({
  required String userId,
  required String title,
  SavedState? initialState,
  String? calendarId,
});
typedef LeaveCalendar = Future<LeaveCalendarResult> Function({
  required String calendarId,
  required String userId,
});
typedef DeleteCalendar = Future<DeleteCalendarResult> Function({
  required String calendarId,
  required String currentUserId,
});
typedef LoadUserProfiles = Future<List<UserProfile>> Function(
  List<String> userIds,
);

/// Holds all mutable in-session state: activity pool, current week plan.
/// Persists changes to [PersistenceService] and [FirestoreSyncService] (if signed in) on every mutation.
/// Screens read from it via [AppStateScope.of(context)].
class AppState extends ChangeNotifier {
  final List<Activity> activities;
  late List<DayPlan> _generatedDays;
  int _selectedRangeWeekIndex = 0;
  int _seed = 0;
  int _updatedAtMillis = 0;
  PlanStyle _planStyle = PlanStyle.balanced;

  /// What was actually generated: the planning horizon's shape. Distinct
  /// from [_viewMode], which is just how the Plan screen currently looks at
  /// it. See [weekPlan] and [hasSufficientRangeForView].
  RangeType _rangeType = RangeType.week;

  /// How the Plan screen currently displays [generatedRange]. Switching
  /// this never regenerates or discards [_generatedDays]; see
  /// [setViewMode].
  RangeType _viewMode = RangeType.week;

  /// The day [_generatedDays] starts from. Persisted so reloading the app
  /// reconstructs the exact same range deterministically rather than
  /// re-anchoring to a new "today" (and reshuffling everything) on every
  /// load; only [generateRange] deliberately moves this forward.
  late DateTime _rangeStart;

  /// Occurrence-keyed (`yyyy-MM-dd:activityId`) "Remove from this plan"
  /// choices, applied to a freshly built [_generatedDays] by
  /// [_applyRemovals]. Cleared on [regenerate], [generateRange], and
  /// [setPlanStyle] since those already discard every other non-locked
  /// customization; keeping a stale entry around would otherwise risk
  /// silently re-deleting an occurrence the user just got back via one of
  /// those actions on the next reload. See [removeFromPlan].
  Map<String, bool> _removedOccurrences = {};

  /// Occurrence-keyed (`yyyy-MM-dd:activityId`) per-occurrence edits (actual
  /// scheduled time, category, and enabled planning dimensions; see
  /// [editPlannedOccurrence]), applied to a freshly built [_generatedDays]
  /// by [_applyOccurrenceOverrides]. Cleared on [regenerate],
  /// [generateRange], and [setPlanStyle] for the same reason as
  /// [_removedOccurrences]: those already discard every other non-locked
  /// customization, and keeping a stale override around would silently
  /// reapply an edit that belonged to a previous generated plan.
  Map<String, OccurrenceOverride> _occurrenceOverrides = {};

  /// Stable-id-keyed user-added manual plan items. These survive
  /// [regenerate], [generateRange], and [setPlanStyle] because they are
  /// pinned user content, not generated-occurrence customizations. See
  /// [addManualPlanItem] and [removeManualPlanItem].
  Map<String, ManualPlanItem> _manualPlanItems = {};

  /// Occurrence-keyed (`yyyy-MM-dd:activityId`) archive of dated planned
  /// occurrence snapshots. Unlike [_removedOccurrences]/
  /// [_occurrenceOverrides]/[_manualPlanItems], this is never cleared by
  /// [regenerate], [generateRange], or [setPlanStyle] - it only ever grows
  /// or has individual entries updated. See [_archiveCurrentRange] and
  /// [_upsertArchiveEntry] for how entries are captured and frozen once
  /// their date has passed.
  Map<String, PlanHistoryEntry> _planHistory = {};
  List<UserEventSource> _outsideEventSources = const [];
  List<SourceListSnapshot> _outsideEventSourceSnapshots = const [];
  List<EventSuggestion> _cachedOutsideEvents = const [];
  int? _cachedOutsideEventsFetchedAtMillis;
  bool _isRefreshingOutsideEvents = false;
  String? _refreshingOutsideEventSourceId;
  String? _refreshingOutsideEventSourceName;
  int? _refreshSourceIndex;
  int? _refreshSourceTotal;
  OutsideEventRefreshSummary? _lastOutsideEventRefreshSummary;
  bool? _lastWebpageAiConfigured;
  SavedState? _lastRegenerationSnapshot;
  String? _plannerConflictMessage;
  String? _displayName;
  bool _displayNameConfirmed = false;
  bool _calendarNameConfirmed = false;
  bool _introOnboardingCompleted = false;
  bool _checkInPromptDismissed = false;
  String? _userId;
  String? _calendarId;
  String? _preferredCalendarId;
  String _calendarTitle = FirestoreSyncService.defaultCalendarTitle;
  String? _calendarOwnerUserId;
  List<String> _calendarMemberUserIds = const [];
  Map<String, UserProfile> _memberProfiles = const {};
  List<FirestoreCalendar> _accessibleCalendars = const [];
  bool _difficultyEnabled = false;
  bool _energyEnabled = false;
  bool _socialEnabled = false;
  int _defaultDifficulty = 3;
  String _defaultEnergy = 'medium';
  String _defaultSocial = 'either';
  bool _feedEnabled = false;
  String? _feedToken;
  int? _feedCreatedAtMillis;
  int? _feedUpdatedAtMillis;
  int? _feedRevokedAtMillis;
  String? _cachedIcsText;
  int? _cachedIcsUpdatedAtMillis;
  ExportPrintOptions _exportPrintOptions = const ExportPrintOptions();
  String _lastSyncStatus = 'Sync pending';
  String? _lastSyncErrorMessage;
  _SyncOperation? _lastSyncOperation;
  int? _lastSyncAttemptAtMillis;
  bool _remoteUpdatedElsewhere = false;
  bool _isInitialSyncComplete = true;
  bool _isSyncingInitialState = false;
  final LoadAccessibleCalendars _loadAccessibleCalendars;
  final SaveSelectedFirestoreState _saveSelectedFirestoreState;
  final UpsertUserProfile _upsertUserProfile;
  final AddCalendarMember _addCalendarMember;
  final CreateCalendar _createCalendar;
  final LeaveCalendar _leaveCalendar;
  final DeleteCalendar _deleteCalendar;
  final LoadUserProfiles _loadUserProfiles;

  AppState({
    required List<Activity> activities,
    SavedState? savedState,
    LoadDefaultCalendar? loadDefaultCalendar,
    LoadAccessibleCalendars? loadAccessibleCalendars,
    SaveFirestoreState? saveFirestoreState,
    SaveSelectedFirestoreState? saveSelectedFirestoreState,
    UpsertUserProfile? upsertUserProfile,
    AddCalendarMember? addCalendarMember,
    CreateCalendar? createCalendar,
    LeaveCalendar? leaveCalendar,
    DeleteCalendar? deleteCalendar,
    LoadUserProfiles? loadUserProfiles,
  })  : activities = activities.map((activity) => activity.copy()).toList(),
        _loadAccessibleCalendars = loadAccessibleCalendars ??
            (loadDefaultCalendar == null
                ? FirestoreSyncService.loadAccessibleCalendars
                : ((userId) async {
                    final calendar = await loadDefaultCalendar(userId);
                    return calendar == null ? const [] : [calendar];
                  })),
        _saveSelectedFirestoreState = saveSelectedFirestoreState ??
            ((userId, calendarId, state) {
              if (saveFirestoreState != null) {
                return saveFirestoreState(userId, state);
              }
              return FirestoreSyncService.saveState(
                userId,
                state,
                calendarId: calendarId,
              );
            }),
        _upsertUserProfile =
            upsertUserProfile ?? FirestoreSyncService.upsertUserProfile,
        _addCalendarMember =
            addCalendarMember ?? FirestoreSyncService.addMemberByEmail,
        _createCalendar = createCalendar ?? FirestoreSyncService.createCalendar,
        _leaveCalendar = leaveCalendar ?? FirestoreSyncService.leaveCalendar,
        _deleteCalendar = deleteCalendar ?? FirestoreSyncService.deleteCalendar,
        _loadUserProfiles =
            loadUserProfiles ?? FirestoreSyncService.loadUserProfilesByIds {
    if (savedState != null) {
      _preferredCalendarId =
          _normalizeNullableId(savedState.selectedCalendarId);
      _applySavedState(savedState, persistLocal: false);
    } else {
      _rangeStart = _dateOnly(DateTime.now());
      _generatedDays = _buildPlan();
      _archiveCurrentRange();
    }
    // _calendarId is still null here (Firestore sync hasn't run yet), so
    // this reads the device-local/"before sign-in" cache scope; switching to
    // a synced calendar reloads the right scope via _applyCalendarMetadata.
    _cachedOutsideEvents = PersistenceService.loadCachedOutsideEvents(
      _calendarId,
    );
    _cachedOutsideEventsFetchedAtMillis =
        PersistenceService.loadCachedOutsideEventsFetchedAtMillis(
      _calendarId,
    );
  }

  /// The 7-day slice of [generatedRange] that Today/Progress/print/ICS use,
  /// and that the Plan screen shows for [RangeType.week]/[RangeType.twoWeek]
  /// views. For [RangeType.week] this is the first 7 generated days; for
  /// [RangeType.twoWeek] it is whichever week [selectedRangeWeekIndex]
  /// points at; for [RangeType.month] it is the 7-day window containing
  /// today (clamped to the generated range), since the month view itself is
  /// a read-only grid rather than a paged 7-day window. Falls back to the
  /// first available 7 days if [generatedRange] is shorter than the current
  /// [viewMode] needs (see [hasSufficientRangeForView]). Switching views
  /// never regenerates anything.
  List<DayPlan> get weekPlan {
    if (_generatedDays.isEmpty) return _generatedDays;
    switch (_viewMode) {
      case RangeType.week:
        return _take7(0);
      case RangeType.twoWeek:
        if (_generatedDays.length < 14) return _take7(0);
        return _take7(_selectedRangeWeekIndex * 7);
      case RangeType.month:
        return _weekContainingToday();
    }
  }

  /// Returns the same [_generatedDays] instance, not a copy, when the
  /// 7-day window happens to be the whole list (the common case: a plain
  /// [RangeType.week] range). Tests rely on this to mutate a fresh
  /// [AppState]'s visible days in place via `weekPlan..clear()..addAll(…)`.
  List<DayPlan> _take7(int start) {
    final end = (start + 7).clamp(0, _generatedDays.length);
    final clampedStart = (end - 7).clamp(0, _generatedDays.length);
    if (clampedStart == 0 && end == _generatedDays.length) {
      return _generatedDays;
    }
    return _generatedDays.sublist(clampedStart, end);
  }

  List<DayPlan> _weekContainingToday() {
    final today = _dateOnly(DateTime.now());
    var idx = _generatedDays.indexWhere((d) => _isSameDate(d.date, today));
    if (idx < 0) {
      idx = _generatedDays.indexWhere((d) => !d.date.isBefore(today));
    }
    if (idx < 0) idx = _generatedDays.length - 1;
    return _take7(idx);
  }

  RangeType get rangeType => _rangeType;
  GeneratedPlanRange get generatedRange =>
      GeneratedPlanRange(type: _rangeType, days: _generatedDays);

  /// How the Plan screen currently displays [generatedRange]. See
  /// [setViewMode].
  RangeType get viewMode => _viewMode;

  /// Whether [generatedRange] has enough days to actually show [viewMode].
  /// When false, the Plan screen shows a CTA to [generateRange] rather than
  /// a partial or wiped-out view.
  bool get hasSufficientRangeForView =>
      _generatedDays.length >= _viewMode.horizonDays(_rangeStart);

  /// Days copy text/print should export for the current [viewMode]. Week
  /// always exports the visible [weekPlan]. Two weeks exports the full
  /// generated range only when [_rangeType] is itself [RangeType.twoWeek]
  /// (a true two-week horizon was generated) - [hasSufficientRangeForView]
  /// alone isn't enough, since a generated month also satisfies the
  /// two-week length check; otherwise it falls back to the visible week,
  /// same as the on-screen view. Month returns `null` when
  /// [hasSufficientRangeForView] is false so callers show a "generate
  /// first" message instead of silently exporting a stale or partial
  /// range.
  List<DayPlan>? get exportDays {
    switch (_viewMode) {
      case RangeType.week:
        return weekPlan;
      case RangeType.twoWeek:
        return _rangeType == RangeType.twoWeek && hasSufficientRangeForView
            ? generatedRange.days
            : weekPlan;
      case RangeType.month:
        return hasSufficientRangeForView ? generatedRange.days : null;
    }
  }

  int get selectedRangeWeekIndex => _selectedRangeWeekIndex;
  PlanStyle get planStyle => _planStyle;
  bool get canUndoLastRegeneration => _lastRegenerationSnapshot != null;
  String? get plannerConflictMessage => _plannerConflictMessage;
  String? get displayName => _displayName;
  bool get displayNameConfirmed => _displayNameConfirmed;
  bool get checkInPromptDismissed => _checkInPromptDismissed;
  String? get userId => _userId;
  String? get calendarId => _calendarId;
  String get calendarTitle => _calendarTitle;
  bool get calendarNameConfirmed => _calendarNameConfirmed;
  bool get introOnboardingCompleted => _introOnboardingCompleted;
  String? get calendarOwnerUserId => _calendarOwnerUserId;

  /// Friendly label for [calendarOwnerUserId]: "You", a known display
  /// name/email, or a shortened UID as a last resort when no profile info
  /// is loaded for that user. Null when there is no owner (local-only).
  String? get calendarOwnerDisplayLabel => _calendarOwnerUserId == null
      ? null
      : _memberDisplayLabel(_calendarOwnerUserId!);
  List<String> get calendarMemberUserIds =>
      List.unmodifiable(_calendarMemberUserIds);
  List<String> get calendarMemberDisplayLabels => List.unmodifiable(
        _calendarMemberUserIds.map(_memberDisplayLabel),
      );
  List<CalendarMetadata> get accessibleCalendars => List.unmodifiable(
        _accessibleCalendars.map((calendar) => calendar.metadata),
      );
  bool get hasMultipleAccessibleCalendars => _accessibleCalendars.length > 1;
  bool get canCreateCalendars => _userId != null;
  bool get canAddCalendarMembers =>
      _userId != null && _calendarOwnerUserId == _userId && _calendarId != null;
  bool get canDeleteCurrentCalendar =>
      _userId != null && _calendarOwnerUserId == _userId && _calendarId != null;
  bool get canLeaveCurrentCalendar {
    final uid = _userId;
    return uid != null &&
        _calendarId != null &&
        _calendarOwnerUserId != uid &&
        _calendarMemberUserIds.contains(uid) &&
        _calendarMemberUserIds.length > 1;
  }

  bool get difficultyEnabled => _difficultyEnabled;
  bool get energyEnabled => _energyEnabled;
  bool get socialEnabled => _socialEnabled;
  int get defaultDifficulty => _defaultDifficulty;
  String get defaultEnergy => _defaultEnergy;
  String get defaultSocial => _defaultSocial;
  String get defaultEnergyLabel => _capitalize(_defaultEnergy);
  String get defaultSocialLabel => _capitalize(_defaultSocial);
  bool get feedEnabled => _feedEnabled;
  bool get isPublished => _feedEnabled;
  String? get feedToken => _feedToken;
  int? get feedCreatedAtMillis => _feedCreatedAtMillis;
  int? get feedUpdatedAtMillis => _feedUpdatedAtMillis;
  int? get feedRevokedAtMillis => _feedRevokedAtMillis;
  String? get cachedIcsText => _cachedIcsText;
  int? get cachedIcsUpdatedAtMillis => _cachedIcsUpdatedAtMillis;
  ExportPrintOptions get exportPrintOptions => _exportPrintOptions;
  String get lastSyncStatus => _lastSyncStatus;
  String? get lastSyncErrorMessage => _lastSyncErrorMessage;
  int? get lastSyncAttemptAtMillis => _lastSyncAttemptAtMillis;
  bool get remoteUpdatedElsewhere => _remoteUpdatedElsewhere;

  /// User-added manual plan items pinned to specific dates. Exposed mainly
  /// for tests; screens should read the merged [DayPlan.activities].
  List<ManualPlanItem> get manualPlanItems =>
      List.unmodifiable(_manualPlanItems.values);

  /// The full dated-occurrence archive, in no particular order. Exposed
  /// mainly for tests and future history/trend UI; current screens
  /// (Today/Plan/Progress) still read live [DayPlan]s.
  List<PlanHistoryEntry> get planHistory =>
      List.unmodifiable(_planHistory.values);

  /// The archived snapshot for one occurrence, or `null` if it was never
  /// captured (e.g. an occurrence date that hasn't been generated yet).
  PlanHistoryEntry? planHistoryEntryFor(DateTime date, String activityId) =>
      _planHistory[_occurrenceKey(date, activityId)];
  List<UserEventSource> get outsideEventSources =>
      List.unmodifiable(_outsideEventSources);
  List<SourceListSnapshot> get outsideEventSourceSnapshots =>
      List.unmodifiable(_outsideEventSourceSnapshots);
  List<EventSuggestion> get cachedOutsideEvents =>
      List.unmodifiable(_cachedOutsideEvents);
  int? get cachedOutsideEventsFetchedAtMillis =>
      _cachedOutsideEventsFetchedAtMillis;

  /// Whether [refreshOutsideEventSources] is currently running, so Settings
  /// and the Outside events screen can disable their fetch/refresh
  /// controls and show progress instead of allowing repeated taps.
  bool get isRefreshingOutsideEvents => _isRefreshingOutsideEvents;

  /// The source id currently being fetched during a refresh, or null
  /// between sources (or when not refreshing). Sources run sequentially, so
  /// at most one id is ever "fetching" at a time.
  String? get refreshingOutsideEventSourceId => _refreshingOutsideEventSourceId;

  /// Display name of the source currently being fetched, for progress text
  /// like "Fetching 3 of 10: HalifaxEvents.ca". Null whenever
  /// [refreshingOutsideEventSourceId] is null.
  String? get refreshingOutsideEventSourceName =>
      _refreshingOutsideEventSourceName;

  /// 1-based position of the source currently being fetched among
  /// [refreshSourceTotal] sources this refresh will check, advancing even
  /// for disabled sources that are skipped rather than fetched. Null when
  /// not refreshing.
  int? get refreshSourceIndex => _refreshSourceIndex;

  /// Total number of sources this refresh will check (fetched or skipped).
  /// Null when not refreshing.
  int? get refreshSourceTotal => _refreshSourceTotal;

  /// Human-readable progress for the in-flight refresh, e.g. "Fetching 3 of
  /// 10: HalifaxEvents.ca", shared by Settings and the Outside events
  /// screen so both show identical wording next to their spinners.
  /// Meaningless (but harmless) when [isRefreshingOutsideEvents] is false.
  String get refreshProgressLabel {
    final total = _refreshSourceTotal;
    final index = _refreshSourceIndex;
    if (total == null || index == null) return 'Fetching outside events...';
    final name = _refreshingOutsideEventSourceName;
    if (name == null || name.trim().isEmpty) {
      return 'Checking source $index of $total...';
    }
    return 'Fetching $index of $total: $name';
  }

  /// Tally from the most recently completed refresh, or null before the
  /// first manual refresh this session.
  OutsideEventRefreshSummary? get lastOutsideEventRefreshSummary =>
      _lastOutsideEventRefreshSummary;

  /// Whether the server-side AI organizer was configured, from the most
  /// recent webpage-source fetch. Null until a webpage source has been
  /// fetched at least once this session.
  bool? get lastWebpageAiConfigured => _lastWebpageAiConfigured;

  /// Calm, plain-language description of the current sync problem or
  /// notice, or `null` when sync is healthy. Never exposes raw Firebase
  /// exception text.
  SyncMessage? get syncMessage => _buildSyncMessage();
  bool get isInitialSyncComplete => _isInitialSyncComplete;
  bool get isSyncingInitialState => _isSyncingInitialState;
  bool get shouldWaitForInitialSync =>
      _userId != null && !_isInitialSyncComplete;
  String get feedTokenPreview {
    final token = _feedToken;
    if (token == null || token.isEmpty) return 'No token yet';
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}...${token.substring(token.length - 6)}';
  }

  void setUserId(String? uid, {String? email, String? displayName}) {
    if (_userId == uid) {
      if (uid != null) {
        _upsertSignedInProfile(uid, email: email, displayName: displayName);
      }
      return;
    }
    _userId = uid;
    if (uid != null) {
      _isInitialSyncComplete = false;
      _isSyncingInitialState = true;
      _applyCalendarMetadata(FirestoreSyncService.defaultMetadata(uid));
      notifyListeners();
      _upsertSignedInProfile(uid, email: email, displayName: displayName);
      unawaited(syncWithFirestore());
    } else {
      _isInitialSyncComplete = true;
      _isSyncingInitialState = false;
      _accessibleCalendars = const [];
      _memberProfiles = const {};
      _clearCalendarMetadata();
      notifyListeners();
    }
  }

  void _upsertSignedInProfile(
    String uid, {
    String? email,
    String? displayName,
  }) {
    final hasEmail = email?.trim().isNotEmpty == true;
    final hasDisplayName = displayName?.trim().isNotEmpty == true;
    if (!hasEmail && !hasDisplayName) return;
    unawaited(
      _upsertUserProfile(
        userId: uid,
        email: email,
        displayName: displayName,
      ),
    );
  }

  Future<void> syncWithFirestore() async {
    final uid = _userId;
    if (uid == null) return;
    final wasInitialSync = !_isInitialSyncComplete;
    if (wasInitialSync && !_isSyncingInitialState) {
      _isSyncingInitialState = true;
      notifyListeners();
    }

    try {
      _remoteUpdatedElsewhere = false;
      final remoteCalendars = await _loadAccessibleCalendars(uid);
      if (_userId != uid) return;
      final profileWarning = await _refreshMemberProfiles(remoteCalendars);
      if (_userId != uid) return;

      final local = _currentSavedState();
      final localSelectedCalendarId = _preferredCalendarId ??
          _normalizeNullableId(local.selectedCalendarId);
      var metadataChanged = false;
      final remote = _chooseCalendar(remoteCalendars, uid);
      _accessibleCalendars = List.unmodifiable(remoteCalendars);
      if (remote != null) {
        final selectedCalendarIsStillAccessible =
            localSelectedCalendarId == null ||
                remoteCalendars.any(
                  (calendar) =>
                      calendar.metadata.calendarId == localSelectedCalendarId,
                );
        final selectedCalendarChangedBecauseMissing =
            localSelectedCalendarId != null &&
                remote.metadata.calendarId != localSelectedCalendarId &&
                !selectedCalendarIsStillAccessible;
        metadataChanged = _applyCalendarMetadata(
          remote.metadata,
          rememberSelection: true,
        );

        if (selectedCalendarChangedBecauseMissing) {
          _applySavedState(remote.state, persistLocal: false);
          _persistLocal(_currentSavedState());
          _applySyncResult(FirestoreSyncResult.success());
          notifyListeners();
        } else if (remote.state.updatedAtMillis > local.updatedAtMillis) {
          // A previous local sync already happened (updatedAtMillis > 0) and
          // the remote copy is newer, so another device/session changed this
          // calendar in between; note that for the UI rather than treating it
          // as the normal first-load case below.
          if (local.updatedAtMillis > 0) {
            _remoteUpdatedElsewhere = true;
          }
          _applySavedState(remote.state, persistLocal: false);
          _persistLocal(_currentSavedState());
          // Re-derive rather than re-save remote.state verbatim:
          // _applySavedState just rebuilt _generatedDays against "now", which
          // may be a different calendar week than the cached ICS in
          // remote.state.
          await _saveStateToFirestore(uid, _calendarId!, _currentSavedState());
          notifyListeners();
        } else {
          _persistLocal(_currentSavedState());
          final stateToSave = local.updatedAtMillis == 0
              ? _currentSavedState(
                  updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
                )
              : local;
          if (stateToSave.updatedAtMillis != _updatedAtMillis) {
            _updatedAtMillis = stateToSave.updatedAtMillis;
            _persistLocal(stateToSave);
          }
          await _saveStateToFirestore(uid, _calendarId!, stateToSave);
          if (metadataChanged) {
            notifyListeners();
          }
        }
      } else {
        final defaultCalendarId = FirestoreSyncService.defaultCalendarId(uid);
        final useBlankDefault = localSelectedCalendarId != null &&
            localSelectedCalendarId != defaultCalendarId;
        final stateToSave = useBlankDefault
            ? _newCalendarSavedState(
                title: FirestoreSyncService.defaultCalendarTitle,
                updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
              )
            : local.updatedAtMillis == 0
                ? _currentSavedState(
                    updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
                  )
                : local;
        _applyCalendarMetadata(
          FirestoreSyncService.defaultMetadata(uid).copyWith(
            title: stateToSave.calendarTitle ??
                FirestoreSyncService.defaultCalendarTitle,
            updatedAtMillis: stateToSave.updatedAtMillis,
          ),
          rememberSelection: true,
        );
        if (stateToSave.updatedAtMillis != _updatedAtMillis) {
          _updatedAtMillis = stateToSave.updatedAtMillis;
        }
        if (useBlankDefault) {
          _applySavedState(stateToSave, persistLocal: false);
        }
        _persistLocal(_currentSavedState());
        await _saveStateToFirestore(
            uid, defaultCalendarId, _currentSavedState());
      }
      if (profileWarning != null) {
        _applySyncResult(
          FirestoreSyncResult.failure(profileWarning),
          operation: _SyncOperation.profile,
        );
      }
    } on FirestoreSyncException catch (e) {
      _applySyncResult(
        FirestoreSyncResult.failure(e.safeMessage),
        operation: _SyncOperation.load,
      );
    } catch (_) {
      _applySyncResult(
        FirestoreSyncResult.failure('Unknown sync error'),
        operation: _SyncOperation.load,
      );
    } finally {
      if (_userId == uid && wasInitialSync) {
        _isInitialSyncComplete = true;
        _isSyncingInitialState = false;
        notifyListeners();
      }
    }
  }

  /// Dismisses the "updated elsewhere" notice without waiting for the next
  /// sync to naturally clear it.
  void dismissRemoteUpdateNotice() {
    if (!_remoteUpdatedElsewhere) return;
    _remoteUpdatedElsewhere = false;
    notifyListeners();
  }

  // ─── Activities ───────────────────────────────────────────────────────────

  bool selectCalendar(String calendarId) {
    FirestoreCalendar? selected;
    for (final calendar in _accessibleCalendars) {
      if (calendar.metadata.calendarId == calendarId) {
        selected = calendar;
        break;
      }
    }
    if (selected == null) return false;
    if (_calendarId == selected.metadata.calendarId) return true;

    _applyCalendarMetadata(selected.metadata, rememberSelection: true);
    _applySavedState(selected.state, persistLocal: false);
    _persistLocal(_currentSavedState());
    notifyListeners();
    return true;
  }

  Future<CreateCalendarResult> createCalendar(String title) async {
    final trimmed = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) {
      return CreateCalendarResult.failure('Enter a calendar name.');
    }
    final uid = _userId;
    if (uid == null) {
      return CreateCalendarResult.failure(
        'Sign in before creating a calendar.',
      );
    }

    final initialState = _newCalendarSavedState(
      title: trimmed,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final result = await _createCalendar(
      userId: uid,
      title: trimmed,
      initialState: initialState,
    );
    final calendar = result.calendar;
    if (!result.succeeded || calendar == null) {
      return result;
    }

    _accessibleCalendars = List.unmodifiable(
      _sortCalendars(
        [
          ..._accessibleCalendars.where(
            (existing) =>
                existing.metadata.calendarId != calendar.metadata.calendarId,
          ),
          calendar,
        ],
        uid,
      ),
    );
    _applyCalendarMetadata(calendar.metadata, rememberSelection: true);
    _applySavedState(calendar.state, persistLocal: false);
    _persistLocal(_currentSavedState());
    _applySyncResult(FirestoreSyncResult.success());
    notifyListeners();
    return result;
  }

  Future<AddCalendarMemberResult> addMemberByEmail(String email) async {
    final calendarId = _calendarId;
    if (_userId == null || calendarId == null) {
      return AddCalendarMemberResult.failure(
        'Sign in before adding a member.',
      );
    }

    final locallyKnownProfile = _memberProfileByEmail(email);
    if (locallyKnownProfile != null &&
        _calendarMemberUserIds.contains(locallyKnownProfile.uid)) {
      return AddCalendarMemberResult.alreadyMember(locallyKnownProfile);
    }

    final result = await _addCalendarMember(
      calendarId: calendarId,
      email: email,
    );
    final profile = result.profile;
    if (profile != null) {
      _memberProfiles = Map.unmodifiable({
        ..._memberProfiles,
        profile.uid: profile,
      });
    }
    if (result.succeeded && profile != null && !result.alreadyMember) {
      final nextMembers = [..._calendarMemberUserIds];
      if (!nextMembers.contains(profile.uid)) {
        nextMembers.add(profile.uid);
      }
      _calendarMemberUserIds = List.unmodifiable(nextMembers);
      _accessibleCalendars = List.unmodifiable(
        _accessibleCalendars.map((calendar) {
          if (calendar.metadata.calendarId != calendarId) return calendar;
          return FirestoreCalendar(
            state: calendar.state,
            metadata: calendar.metadata.copyWith(
              memberUserIds: _calendarMemberUserIds,
            ),
          );
        }),
      );
      notifyListeners();
      await syncWithFirestore();
    }
    return result;
  }

  Future<LeaveCalendarResult> leaveCurrentCalendar() async {
    final uid = _userId;
    final calendarId = _calendarId;
    if (uid == null || calendarId == null) {
      return LeaveCalendarResult.failure(
        'Sign in before leaving a calendar.',
      );
    }
    if (_calendarOwnerUserId == uid) {
      return LeaveCalendarResult.failure(
        "Owners can't leave their own calendar.",
      );
    }
    if (!_calendarMemberUserIds.contains(uid) ||
        _calendarMemberUserIds.length <= 1) {
      return LeaveCalendarResult.failure(
        "You can't leave this calendar.",
      );
    }

    final result = await _leaveCalendar(
      calendarId: calendarId,
      userId: uid,
    );
    if (!result.succeeded) {
      return result;
    }

    await syncWithFirestore();
    final selectedCalendarId = _calendarId;
    if (selectedCalendarId != null) {
      _persistLocal(_currentSavedState());
    }
    _applySyncResult(FirestoreSyncResult.success());
    notifyListeners();
    return result;
  }

  Future<DeleteCalendarResult> deleteCurrentCalendar() async {
    final uid = _userId;
    final calendarId = _calendarId;
    if (uid == null || calendarId == null) {
      return DeleteCalendarResult.failure(
        'Sign in before deleting a calendar.',
      );
    }
    if (_calendarOwnerUserId != uid) {
      return DeleteCalendarResult.failure(
        'Only the owner can delete this calendar.',
      );
    }

    final result = await _deleteCalendar(
      calendarId: calendarId,
      currentUserId: uid,
    );
    if (!result.succeeded) {
      return result;
    }

    await _selectSafeFallbackAfterCalendarRemoval(uid, calendarId);
    notifyListeners();
    return result;
  }

  void setActivityEnabled(String id, {required bool enabled}) {
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    activities[idx].enabled = enabled;
    _persist();
    notifyListeners();
  }

  String addActivity({
    required String title,
    required String category,
    required int durationMinutes,
    required String preferredTime,
    int? difficulty,
    String? energy,
    String? social,
    required int maxPerWeek,
    required List<int> allowedWeekdays,
    required bool noConsecutiveDays,
    required bool enabled,
    bool mustIncludeInPlans = false,
  }) {
    final id = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    activities.add(
      Activity(
        id: id,
        title: title,
        category: category,
        durationMinutes: durationMinutes,
        preferredTime: preferredTime,
        difficulty: difficulty ?? _defaultDifficulty,
        energy: energy ?? _defaultEnergy,
        social: social ?? _defaultSocial,
        maxPerWeek: maxPerWeek,
        allowedWeekdays: allowedWeekdays,
        noConsecutiveDays: noConsecutiveDays,
        enabled: enabled,
        mustIncludeInPlans: mustIncludeInPlans,
      ),
    );
    _persist();
    notifyListeners();
    return id;
  }

  bool hasActivityTitle(String title) {
    final normalized = _normalizeActivityTitle(title);
    return activities.any(
      (activity) => _normalizeActivityTitle(activity.title) == normalized,
    );
  }

  bool addStarterActivity(Activity starter) {
    if (hasActivityTitle(starter.title)) return false;
    activities.add(
      Activity(
        id: '${starter.id}_${DateTime.now().microsecondsSinceEpoch}',
        title: starter.title,
        category: starter.category,
        durationMinutes: starter.durationMinutes,
        preferredTime: starter.preferredTime,
        difficulty: starter.difficulty,
        energy: starter.energy,
        social: starter.social,
        maxPerWeek: starter.maxPerWeek,
        allowedWeekdays: starter.allowedWeekdays,
        noConsecutiveDays: starter.noConsecutiveDays,
        enabled: starter.enabled,
        mustIncludeInPlans: starter.mustIncludeInPlans,
      ),
    );
    _persist();
    notifyListeners();
    return true;
  }

  void updateActivity(
    String id, {
    required String title,
    required String category,
    required int durationMinutes,
    required String preferredTime,
    int? difficulty,
    String? energy,
    String? social,
    required int maxPerWeek,
    required List<int> allowedWeekdays,
    required bool noConsecutiveDays,
    required bool enabled,
    bool mustIncludeInPlans = false,
  }) {
    final idx = activities.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    final activity = activities[idx];
    activity
      ..title = title
      ..category = category
      ..durationMinutes = durationMinutes
      ..preferredTime = preferredTime
      ..difficulty = (difficulty ?? activity.difficulty).clamp(1, 5).toInt()
      ..energy = _normalizeOption(
        energy ?? activity.energy,
        fallback: activity.energy,
        allowed: const ['low', 'medium', 'high'],
      )
      ..social = _normalizeOption(
        social ?? activity.social,
        fallback: activity.social,
        allowed: const ['solo', 'together', 'group', 'either'],
      )
      ..maxPerWeek = maxPerWeek
      ..allowedWeekdays = List<int>.from(allowedWeekdays)
      ..noConsecutiveDays = noConsecutiveDays
      ..enabled = enabled
      ..mustIncludeInPlans = mustIncludeInPlans;
    _persist();
    notifyListeners();
  }

  // ─── Plan ─────────────────────────────────────────────────────────────────

  bool confirmDisplayName(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return false;
    _displayName = trimmed;
    _displayNameConfirmed = true;
    _persist();
    notifyListeners();
    return true;
  }

  bool confirmCalendarTitle(String value) {
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return false;
    _calendarTitle = trimmed;
    _calendarNameConfirmed = true;
    _persist();
    notifyListeners();
    return true;
  }

  bool renameCalendarTitle(String value) {
    return confirmCalendarTitle(value);
  }

  void completeIntroOnboarding() {
    if (_introOnboardingCompleted) return;
    _introOnboardingCompleted = true;
    _persist();
    notifyListeners();
  }

  /// Reshuffles unlocked activities within the currently generated range
  /// (same [rangeType], same start date) — locked items stay exactly where
  /// they are. Does not change the planning horizon; see [generateRange]
  /// for that. If [_rangeStart] has fallen into the past (e.g. the plan was
  /// generated late last night and the user regenerates after midnight),
  /// it's advanced to today first so the stale day is never re-generated.
  void regenerate() {
    _lastRegenerationSnapshot = _currentSavedState();
    _seed++;
    _advanceRangeStartToTodayIfStale();
    _removedOccurrences = {};
    _occurrenceOverrides = {};
    _generatedDays = _buildPlan(lockedItems: _collectLocked());
    _applyManualItems();
    _archiveCurrentRange();
    _persist();
    notifyListeners();
  }

  /// Deliberately (re)generates a fresh [type] planning horizon starting
  /// today, replacing [generatedRange] entirely (no carried-over locked
  /// items, since they belonged to a different-shaped plan) and switching
  /// [viewMode] to [type] (generating a shape implies wanting to look at
  /// it). This is the only thing that changes what's actually generated;
  /// [setViewMode] never does. Used when [hasSufficientRangeForView] is
  /// false for the user's chosen [viewMode], or when the user wants a fresh
  /// horizon.
  void generateRange(RangeType type) {
    _lastRegenerationSnapshot = _currentSavedState();
    _seed++;
    _rangeType = type;
    _viewMode = type;
    _rangeStart = _dateOnly(DateTime.now());
    _selectedRangeWeekIndex = 0;
    _removedOccurrences = {};
    _occurrenceOverrides = {};
    _generatedDays = _buildPlan();
    _applyManualItems();
    _archiveCurrentRange();
    _persist();
    notifyListeners();
  }

  void undoLastRegeneration() {
    final snapshot = _lastRegenerationSnapshot;
    if (snapshot == null) return;
    _lastRegenerationSnapshot = null;
    _applySavedState(snapshot, persistLocal: false);
    _persist();
    notifyListeners();
  }

  void dismissCheckInPrompt() {
    if (_checkInPromptDismissed) return;
    _checkInPromptDismissed = true;
    notifyListeners();
  }

  void setPlanStyle(PlanStyle style) {
    if (_planStyle == style) return;
    _planStyle = style;
    _advanceRangeStartToTodayIfStale();
    _removedOccurrences = {};
    _occurrenceOverrides = {};
    _generatedDays = _buildPlan(lockedItems: _collectLocked());
    _applyManualItems();
    _archiveCurrentRange();
    _persist();
    notifyListeners();
  }

  /// Switches which 7-day week of a [RangeType.twoWeek] view [weekPlan]
  /// shows, without regenerating anything. No-op outside [RangeType.twoWeek]
  /// view mode.
  void selectRangeWeekIndex(int index) {
    if (_viewMode != RangeType.twoWeek) return;
    final clamped = index.clamp(0, 1);
    if (_selectedRangeWeekIndex == clamped) return;
    _selectedRangeWeekIndex = clamped;
    notifyListeners();
  }

  /// Switches how the Plan screen displays [generatedRange]. This is a
  /// harmless, free view switch: it never regenerates or discards
  /// [generatedRange]. If [generatedRange] doesn't have enough days for
  /// [mode] yet, [hasSufficientRangeForView] reports that so the Plan
  /// screen can show a generate/expand CTA instead of silently
  /// regenerating.
  void setViewMode(RangeType mode) {
    if (_viewMode == mode) return;
    _viewMode = mode;
    _selectedRangeWeekIndex = 0;
    _persist();
    notifyListeners();
  }

  void setDifficultyEnabled(bool value) {
    if (_difficultyEnabled == value) return;
    _difficultyEnabled = value;
    _persist();
    notifyListeners();
  }

  void setEnergyEnabled(bool value) {
    if (_energyEnabled == value) return;
    _energyEnabled = value;
    _persist();
    notifyListeners();
  }

  void setExportPrintOptions(ExportPrintOptions value) {
    _exportPrintOptions = value;
    _persist();
    notifyListeners();
  }

  void setSocialEnabled(bool value) {
    if (_socialEnabled == value) return;
    _socialEnabled = value;
    _persist();
    notifyListeners();
  }

  void setDefaultDifficulty(int value) {
    final normalized = value.clamp(1, 5).toInt();
    if (_defaultDifficulty == normalized) return;
    _defaultDifficulty = normalized;
    _persist();
    notifyListeners();
  }

  void setDefaultEnergy(String value) {
    final normalized = _normalizeOption(
      value,
      fallback: _defaultEnergy,
      allowed: const ['low', 'medium', 'high'],
    );
    if (_defaultEnergy == normalized) return;
    _defaultEnergy = normalized;
    _persist();
    notifyListeners();
  }

  void setDefaultSocial(String value) {
    final normalized = _normalizeOption(
      value,
      fallback: _defaultSocial,
      allowed: const ['solo', 'together', 'group', 'either'],
    );
    if (_defaultSocial == normalized) return;
    _defaultSocial = normalized;
    _persist();
    notifyListeners();
  }

  void setFeedEnabled(bool value) {
    if (value) {
      _enableFeed();
      return;
    }
    _disableFeed();
  }

  void regenerateFeedToken() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final hadToken = _feedToken != null && _feedToken!.isNotEmpty;
    _feedToken = _generateFeedToken();
    _feedEnabled = true;
    _feedCreatedAtMillis ??= now;
    _feedUpdatedAtMillis = now;
    if (hadToken) {
      _feedRevokedAtMillis = now;
    }
    _persist();
    notifyListeners();
  }

  void revokeFeedToken() {
    if (!_feedEnabled && _feedToken == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _feedEnabled = false;
    _feedToken = null;
    _feedUpdatedAtMillis = now;
    _feedRevokedAtMillis = now;
    _persist();
    notifyListeners();
  }

  /// Manually forces the cached ICS feed to be rebuilt from the current
  /// generated plan and persisted, for the Settings "Refresh published
  /// feed" action - giving the user an explicit way to confirm their
  /// latest plan reached the *public* feed, not just this device.
  ///
  /// Deliberately does not call `_persist()`: that method fires the
  /// Firestore save via `unawaited(...)`, so a caller could report success
  /// before the save lands (or even if it fails) - exactly the bug this
  /// method exists to avoid, since the Netlify feed endpoint only ever
  /// reads `cachedIcsText` from Firestore, never from this device. Instead
  /// this awaits the same Firestore save path directly so the returned
  /// result reflects what's actually visible to the public feed.
  Future<FeedRefreshResult> refreshPublishedFeedNow() async {
    if (!_feedEnabled || _feedToken == null || _feedToken!.isEmpty) {
      return FeedRefreshResult.unavailable;
    }
    _updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    final state = _currentSavedState(updatedAtMillis: _updatedAtMillis);
    _persistLocal(state);
    notifyListeners();

    final uid = _userId;
    final calendarId = _calendarId;
    if (uid == null || calendarId == null) {
      return FeedRefreshResult.success;
    }

    final result = await _saveStateToFirestore(uid, calendarId, state);
    return result.succeeded
        ? FeedRefreshResult.success
        : FeedRefreshResult.syncFailed;
  }

  void toggleLock(PlannedActivity activity) {
    activity.locked = !activity.locked;
    _archiveLiveOccurrence(activity);
    _persist();
    notifyListeners();
  }

  void notifyCheckIn(PlannedActivity activity) {
    _archiveLiveOccurrence(activity);
    _persist();
    notifyListeners();
  }

  /// Updates the archive entry for [activity]'s current day/occurrence
  /// without forcing a snapshot refresh - used by [toggleLock] and
  /// [notifyCheckIn], where only [PlanHistoryEntry.locked]/[status] should
  /// change. No-op if [activity] isn't found in [_generatedDays] (shouldn't
  /// normally happen, since callers always pass a live planned occurrence).
  void _archiveLiveOccurrence(PlannedActivity activity) {
    final day = _dayContaining(activity);
    if (day == null) return;
    _archiveOccurrence(day, activity, forceSnapshotUpdate: false);
  }

  DayPlan? _dayContaining(PlannedActivity activity) {
    for (final day in _generatedDays) {
      if (day.activities.contains(activity)) return day;
    }
    return null;
  }

  /// Removes only [activity]'s occurrence on [day] from the current
  /// generated plan. Does not touch [activities] (the activity library), so
  /// the source activity stays in the library and enabled for future
  /// regeneration — see [updateActivity] to edit it instead, or
  /// [setActivityEnabled] to stop generating it going forward. Persisted by
  /// occurrence key (see [_applyRemovals]) so the removal survives reload
  /// and view switching until the next deliberate [regenerate],
  /// [generateRange], or [setPlanStyle].
  ///
  /// For manual plan items ([PlannedActivity.manualItemId] is set), this
  /// deletes the manual item entirely (there is no library source to keep).
  void removeFromPlan(DayPlan day, PlannedActivity activity) {
    final manualId = activity.manualItemId;
    if (manualId != null) {
      // Archive before deleting the manual item so the archive pass can
      // still see whether it was an outside event (see
      // ManualPlanItem.isOutsideEvent) and its library link.
      _archiveOccurrence(day, activity,
          forceSnapshotUpdate: false, removed: true);
      _manualPlanItems.remove(manualId);
      day.activities.remove(activity);
      _persist();
      notifyListeners();
      return;
    }
    if (!day.activities.remove(activity)) return;
    _removedOccurrences[_occurrenceKey(day.date, activity.activity.id)] = true;
    _archiveOccurrence(day, activity,
        forceSnapshotUpdate: false, removed: true);
    _persist();
    notifyListeners();
  }

  /// Edits [activity]'s occurrence on [day] only: the actual scheduled
  /// time, category, and (when their app-settings dimension toggle is on)
  /// difficulty/energy/social for this one generated instance - never the
  /// source [Activity] template; see [updateActivity] to edit that instead.
  /// [difficulty]/[energy]/[social] should be passed `null` when their
  /// dimension is disabled, meaning "no occurrence override for this
  /// field" rather than an explicit value. Persisted by occurrence key
  /// (see [_applyOccurrenceOverrides]) so the edit survives reload and view
  /// switching until the next deliberate [regenerate], [generateRange], or
  /// [setPlanStyle] - those discard the generated plan this override
  /// belonged to, the same as [removeFromPlan].
  ///
  /// For manual plan items ([PlannedActivity.manualItemId] is set), the edit
  /// updates the underlying [ManualPlanItem] directly so the change survives
  /// regeneration and remains a pinned user addition.
  void editPlannedOccurrence(
    DayPlan day,
    PlannedActivity activity, {
    required String timeSlot,
    required String category,
    int? difficulty,
    String? energy,
    String? social,
  }) {
    final manualId = activity.manualItemId;
    if (manualId != null) {
      final item = _manualPlanItems[manualId];
      if (item != null) {
        item.timeSlot = timeSlot;
        item.category = category;
        if (difficulty != null) item.difficulty = difficulty;
        if (energy != null) item.energy = energy;
        if (social != null) item.social = social;

        // Keep the synthetic backing activity in sync so the current
        // PlannedActivity reflects the edit immediately.
        activity.activity
          ..title = item.title
          ..category = item.category
          ..durationMinutes = item.durationMinutes
          ..difficulty = item.difficulty
          ..energy = item.energy
          ..social = item.social;
      }
      activity.timeSlot = timeSlot;
      activity.categoryOverride = null;
      activity.difficultyOverride = difficulty;
      activity.energyOverride = energy;
      activity.socialOverride = social;
    } else {
      activity.timeSlot = timeSlot;
      activity.categoryOverride = category;
      activity.difficultyOverride = difficulty;
      activity.energyOverride = energy;
      activity.socialOverride = social;
      _occurrenceOverrides[_occurrenceKey(day.date, activity.activity.id)] =
          OccurrenceOverride(
        timeSlot: timeSlot,
        category: category,
        difficulty: difficulty,
        energy: energy,
        social: social,
      );
    }
    day.activities.sort(
      (a, b) => PlannerService.timeRank(a.timeSlot)
          .compareTo(PlannerService.timeRank(b.timeSlot)),
    );
    // A deliberate per-occurrence edit always refreshes the archive
    // snapshot, even for a past/today date - unlike passive rebuilds, this
    // is the user explicitly changing what this occurrence actually is.
    _archiveOccurrence(day, activity, forceSnapshotUpdate: true);
    _persist();
    notifyListeners();
  }

  /// Adds a user-created manual plan item to the current generated range.
  /// It is pinned to [item.dateKey] and survives regeneration, view
  /// switches, and reload/sync by default.
  void addManualPlanItem(ManualPlanItem item) {
    _manualPlanItems[item.id] = item;
    _applyManualItems();
    _archiveCurrentRange();
    _persist();
    notifyListeners();
  }

  /// Removes a manual plan item by id. Used by tests; the UI path goes
  /// through [removeFromPlan] on the live occurrence.
  void removeManualPlanItem(String id) {
    if (!_manualPlanItems.containsKey(id)) return;
    _manualPlanItems.remove(id);
    _generatedDays = _buildPlan(lockedItems: _collectLocked());
    _applyRemovals();
    _applyOccurrenceOverrides();
    _applyManualItems();
    _archiveCurrentRange();
    _persist();
    notifyListeners();
  }

  void addOutsideEventSource({
    required String displayName,
    required String url,
    required UserEventSourceKind kind,
  }) {
    final normalizedUrl = url.trim();
    final normalizedName = displayName.trim().isEmpty
        ? _sourceNameFromUrl(normalizedUrl)
        : displayName.trim();
    final source = UserEventSource(
      id: 'user_src_${DateTime.now().microsecondsSinceEpoch}',
      displayName: normalizedName,
      url: normalizedUrl,
      kind: kind,
    );
    _outsideEventSources = [..._outsideEventSources, source];
    _persist();
    notifyListeners();
  }

  /// Merges [drafts] (parsed from an exported source-list JSON paste - see
  /// `UserEventSource.fromExportMap`) into this calendar's outside event
  /// sources, matching by normalized URL so re-importing the same list, or
  /// one that overlaps with existing sources, never creates duplicates.
  /// Each [drafts] entry's own `id` is ignored; a fresh one is generated
  /// here. Returns how many sources were actually added.
  int importOutsideEventSources(List<UserEventSource> drafts) {
    final seenUrls = _outsideEventSources
        .map((source) => _normalizedSourceUrl(source.url))
        .toSet();
    final next = [..._outsideEventSources];
    var added = 0;
    for (final draft in drafts) {
      final normalized = _normalizedSourceUrl(draft.url);
      if (normalized.isEmpty || seenUrls.contains(normalized)) continue;
      seenUrls.add(normalized);
      next.add(UserEventSource(
        id: 'user_src_${DateTime.now().microsecondsSinceEpoch}_$added',
        displayName: draft.displayName,
        url: draft.url,
        kind: draft.kind,
        enabled: draft.enabled,
      ));
      added += 1;
    }
    if (added == 0) return 0;
    _outsideEventSources = next;
    _persist();
    notifyListeners();
    return added;
  }

  static String _normalizedSourceUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.toLowerCase().replaceAll(RegExp(r'/+$'), '');
  }

  void updateOutsideEventSource(UserEventSource source) {
    var changed = false;
    _outsideEventSources = _outsideEventSources.map((existing) {
      if (existing.id != source.id) return existing;
      changed = true;
      return source;
    }).toList();
    if (!changed) return;
    _persist();
    notifyListeners();
  }

  void setOutsideEventSourceEnabled(String id, bool enabled) {
    _outsideEventSources = _outsideEventSources.map((source) {
      return source.id == id ? source.copyWith(enabled: enabled) : source;
    }).toList();
    _persist();
    notifyListeners();
  }

  void deleteOutsideEventSource(String id) {
    final filtered =
        _outsideEventSources.where((source) => source.id != id).toList();
    if (filtered.length == _outsideEventSources.length) return;
    _outsideEventSources = filtered;
    _cachedOutsideEvents = _cachedOutsideEvents
        .where((event) => !event.contributingSourceIds.contains(id))
        .toList();
    _persist();
    _persistCachedOutsideEvents();
    notifyListeners();
  }

  SourceListSnapshot? saveCurrentOutsideEventSources({int? nowMillis}) {
    if (_outsideEventSources.isEmpty) return null;
    final snapshot = SourceListSnapshot.capture(
      createdAtMillis: nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      sources: _outsideEventSources,
    );
    _outsideEventSourceSnapshots = [
      snapshot,
      ..._outsideEventSourceSnapshots.where((item) => item.id != snapshot.id),
    ].take(10).toList(growable: false);
    _persist();
    notifyListeners();
    return snapshot;
  }

  bool restoreOutsideEventSourceSnapshot(String snapshotId) {
    final index = _outsideEventSourceSnapshots.indexWhere(
      (snapshot) => snapshot.id == snapshotId,
    );
    if (index < 0) return false;
    final snapshot = _outsideEventSourceSnapshots[index];
    _outsideEventSources = snapshot.sources
        .map(
          (source) => UserEventSource(
            id: source.id,
            displayName: source.displayName,
            url: source.url,
            kind: source.kind,
            enabled: source.enabled,
          ),
        )
        .toList(growable: false);
    _cachedOutsideEvents = const [];
    _cachedOutsideEventsFetchedAtMillis = null;
    _persist();
    _persistCachedOutsideEvents();
    notifyListeners();
    return true;
  }

  bool deleteOutsideEventSourceSnapshot(String snapshotId) {
    final filtered = _outsideEventSourceSnapshots
        .where((snapshot) => snapshot.id != snapshotId)
        .toList(growable: false);
    if (filtered.length == _outsideEventSourceSnapshots.length) return false;
    _outsideEventSourceSnapshots = filtered;
    _persist();
    notifyListeners();
    return true;
  }

  /// Runs a manual outside-events refresh across curated, user-managed, and
  /// built-in API sources. Never called automatically (not on app open,
  /// login, calendar switch, or background sync) - only from the Settings
  /// "Fetch latest events" action and the Outside events screen's refresh
  /// action, to avoid spending AI/API credits the user didn't ask to spend.
  /// [isRefreshingOutsideEvents] and [refreshingOutsideEventSourceId] track
  /// progress for those screens; [lastOutsideEventRefreshSummary] holds the
  /// final tally once this completes.
  Future<OutsideEventDiscoveryResult> refreshOutsideEventSources() async {
    if (_isRefreshingOutsideEvents) return cachedOutsideEventDiscoveryResult();
    _isRefreshingOutsideEvents = true;
    _refreshingOutsideEventSourceId = null;
    _refreshingOutsideEventSourceName = null;
    _refreshSourceIndex = null;
    _refreshSourceTotal = null;
    notifyListeners();

    try {
      final days = generatedRange.days;
      final start = days.isNotEmpty ? days.first.date : DateTime.now();
      final end = days.isNotEmpty
          ? days.last.date
          : DateTime.now().add(const Duration(days: 6));
      final adapters = <OutsideEventSourceAdapter>[
        CuratedRssOutsideEventAdapter(),
        ..._outsideEventSources.map(_adapterForSource),
        TicketmasterOutsideEventAdapter(),
        EventbriteOutsideEventAdapter(),
        BandsintownOutsideEventAdapter(),
      ];
      final service = OutsideEventDiscoveryService(
        adapters: adapters,
        organizer: const OutsideEventOrganizerService(),
      );
      final result = await service.discover(
        OutsideEventQuery(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(end.year, end.month, end.day, 23, 59),
          city: 'Halifax',
        ),
        onProgress: (index, total) {
          _refreshSourceIndex = index;
          _refreshSourceTotal = total;
          notifyListeners();
        },
        onSourceStart: (config) {
          _refreshingOutsideEventSourceId = config.id;
          _refreshingOutsideEventSourceName = config.displayName;
          notifyListeners();
        },
        onSourceResult: (_) {
          _refreshingOutsideEventSourceId = null;
          _refreshingOutsideEventSourceName = null;
          notifyListeners();
        },
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      _cachedOutsideEvents = result.events;
      _cachedOutsideEventsFetchedAtMillis = now;
      if (result.webpageAiConfigured != null) {
        _lastWebpageAiConfigured = result.webpageAiConfigured;
      }
      _outsideEventSources = _outsideEventSources.map((source) {
        if (!result.attemptedSourceIds.contains(source.id)) return source;
        final warning = _firstSourceWarningFor(result.warnings, source.id);
        final eventCount = result.sourceEventCounts[source.id] ?? 0;
        return source.copyWith(
          lastFetchedAtMillis: now,
          lastError: warning?.message,
          clearLastError: warning == null,
          lastEventCount: eventCount,
          lastSuccessAtMillis:
              warning == null ? now : source.lastSuccessAtMillis,
          lastErrorCategory: warning?.category.name,
          clearLastErrorCategory: warning == null,
          lastErrorHttpStatusCode: warning?.httpStatusCode,
          clearLastErrorHttpStatusCode: warning == null,
        );
      }).toList();
      _lastOutsideEventRefreshSummary = OutsideEventRefreshSummary(
        sourcesChecked: result.attemptedSourceIds.length,
        sourcesSucceeded: result.attemptedSourceIds
            .where(
              (id) => _firstSourceWarningFor(result.warnings, id) == null,
            )
            .length,
        sourcesFailed: result.attemptedSourceIds
            .where(
              (id) => _firstSourceWarningFor(result.warnings, id) != null,
            )
            .length,
        eventsFound: result.events.length,
      );
      _persist();
      _persistCachedOutsideEvents();
      return result;
    } finally {
      _isRefreshingOutsideEvents = false;
      _refreshingOutsideEventSourceId = null;
      _refreshingOutsideEventSourceName = null;
      _refreshSourceIndex = null;
      _refreshSourceTotal = null;
      notifyListeners();
    }
  }

  /// Refetches exactly one user-managed outside-event source (Settings'
  /// per-source "Fetch" action), leaving every other source's cached events
  /// and health untouched. Useful for retrying a single failing source -
  /// e.g. after fixing its URL - without re-spending AI/API credits on every
  /// other source. No-op if a refresh (full or single-source) is already
  /// running, or if [sourceId] isn't a known user-managed source.
  Future<void> refreshOutsideEventSource(String sourceId) async {
    if (_isRefreshingOutsideEvents) return;
    UserEventSource? source;
    for (final candidate in _outsideEventSources) {
      if (candidate.id == sourceId) {
        source = candidate;
        break;
      }
    }
    if (source == null) return;

    _isRefreshingOutsideEvents = true;
    _refreshingOutsideEventSourceId = sourceId;
    _refreshingOutsideEventSourceName = source.displayName;
    _refreshSourceIndex = 1;
    _refreshSourceTotal = 1;
    notifyListeners();

    try {
      final days = generatedRange.days;
      final start = days.isNotEmpty ? days.first.date : DateTime.now();
      final end = days.isNotEmpty
          ? days.last.date
          : DateTime.now().add(const Duration(days: 6));
      final service = OutsideEventDiscoveryService(
        adapters: [_adapterForSource(source)],
        organizer: const OutsideEventOrganizerService(),
      );
      final result = await service.discover(
        OutsideEventQuery(
          start: DateTime(start.year, start.month, start.day),
          end: DateTime(end.year, end.month, end.day, 23, 59),
          city: 'Halifax',
        ),
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      if (result.webpageAiConfigured != null) {
        _lastWebpageAiConfigured = result.webpageAiConfigured;
      }
      final warning = _firstSourceWarningFor(result.warnings, sourceId);
      final eventCount = result.sourceEventCounts[sourceId] ?? 0;
      _outsideEventSources = _outsideEventSources.map((existing) {
        if (existing.id != sourceId) return existing;
        return existing.copyWith(
          lastFetchedAtMillis: now,
          lastError: warning?.message,
          clearLastError: warning == null,
          lastEventCount: eventCount,
          lastSuccessAtMillis:
              warning == null ? now : existing.lastSuccessAtMillis,
          lastErrorCategory: warning?.category.name,
          clearLastErrorCategory: warning == null,
          lastErrorHttpStatusCode: warning?.httpStatusCode,
          clearLastErrorHttpStatusCode: warning == null,
        );
      }).toList();
      final otherEvents = _cachedOutsideEvents
          .where((event) => !event.contributingSourceIds.contains(sourceId))
          .toList();
      final merged = EventDedupeService.mergeSimilar([
        ...otherEvents,
        ...result.events,
      ])
        ..sort((a, b) {
          final byDate = a.startDateTime.compareTo(b.startDateTime);
          if (byDate != 0) return byDate;
          return a.displayTitle.compareTo(b.displayTitle);
        });
      _cachedOutsideEvents = merged;
      _cachedOutsideEventsFetchedAtMillis = now;
      _persist();
      _persistCachedOutsideEvents();
    } finally {
      _isRefreshingOutsideEvents = false;
      _refreshingOutsideEventSourceId = null;
      _refreshingOutsideEventSourceName = null;
      _refreshSourceIndex = null;
      _refreshSourceTotal = null;
      notifyListeners();
    }
  }

  OutsideEventDiscoveryResult cachedOutsideEventDiscoveryResult() {
    final adapters = <OutsideEventSourceAdapter>[
      CuratedRssOutsideEventAdapter(),
      ..._outsideEventSources.map(_adapterForSource),
      TicketmasterOutsideEventAdapter(),
      EventbriteOutsideEventAdapter(),
      BandsintownOutsideEventAdapter(),
    ];
    return OutsideEventDiscoveryResult(
      events: _cachedOutsideEvents.where(_isActiveOutsideEvent).toList(),
      sources: adapters.map((adapter) => adapter.config).toList(),
      warnings: [
        for (final source in _outsideEventSources)
          if (source.lastError?.trim().isNotEmpty == true)
            OutsideEventSourceWarning(
              sourceId: source.id,
              sourceName: source.displayName,
              message: source.lastError!,
              httpStatusCode: source.lastErrorHttpStatusCode,
              category: _failureCategoryFromName(source.lastErrorCategory),
            ),
      ],
      aiStatusMessage:
          'Webpage AI organizer runs server-side when configured. Without '
          'an AI key, webpage sources use deterministic date/title fallback.',
      webpageAiConfigured: _lastWebpageAiConfigured,
    );
  }

  static bool _isActiveOutsideEvent(EventSuggestion event) {
    if (event.sourceId != 'curated-rss' ||
        event.contributingSourceIds.length > 1) {
      return true;
    }
    final feedSourceId = event.raw['feedSourceId'];
    if (feedSourceId is! String) return true;
    return curatedRssFeedSources.any((source) => source.id == feedSourceId);
  }

  OutsideEventSourceAdapter _adapterForSource(UserEventSource source) {
    return switch (source.kind) {
      UserEventSourceKind.rssAtom => UserRssAtomOutsideEventAdapter(
          source: source,
        ),
      UserEventSourceKind.webPage => WebPageEventSourceAdapter(source: source),
      UserEventSourceKind.icsCalendar => UserIcsOutsideEventAdapter(
          source: source,
        ),
      UserEventSourceKind.autoDetect => _looksLikeIcs(source.url)
          ? UserIcsOutsideEventAdapter(source: source)
          : _looksLikeFeed(source.url)
              ? UserRssAtomOutsideEventAdapter(source: source)
              : WebPageEventSourceAdapter(source: source),
    };
  }

  void _persistCachedOutsideEvents() {
    PersistenceService.saveCachedOutsideEvents(
        _calendarId, _cachedOutsideEvents);
    PersistenceService.saveCachedOutsideEventsFetchedAtMillis(
      _calendarId,
      _cachedOutsideEventsFetchedAtMillis,
    );
  }

  static OutsideEventSourceWarning? _firstSourceWarningFor(
    List<OutsideEventSourceWarning> warnings,
    String sourceId,
  ) {
    for (final warning in warnings) {
      if (warning.sourceId == sourceId) return warning;
    }
    return null;
  }

  static OutsideEventFailureCategory _failureCategoryFromName(String? name) {
    return OutsideEventFailureCategory.values.firstWhere(
      (category) => category.name == name,
      orElse: () => OutsideEventFailureCategory.unknown,
    );
  }

  static String _occurrenceKey(DateTime date, String activityId) =>
      '${DayPlan.dateKey(date)}:$activityId';

  /// Past (strictly before [now], defaulting to [DateTime.now]), unchecked
  /// activities in [plans], grouped by day. A pure function of its inputs so
  /// it can be unit tested with synthetic days regardless of which real
  /// weekday the test happens to run on.
  static List<(DayPlan, List<PlannedActivity>)> pastUncheckedFrom(
    List<DayPlan> plans, {
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final result = <(DayPlan, List<PlannedActivity>)>[];
    for (final day in plans) {
      if (!day.date.isBefore(today)) continue;
      final unchecked =
          day.activities.where((a) => a.status == CheckStatus.none).toList();
      if (unchecked.isNotEmpty) result.add((day, unchecked));
    }
    return result;
  }

  List<(DayPlan, List<PlannedActivity>)> pastUncheckedByDay({DateTime? now}) =>
      pastUncheckedFrom(weekPlan, now: now);

  bool hasPastUnchecked({DateTime? now}) =>
      pastUncheckedByDay(now: now).isNotEmpty;

  /// Whether a Done/Partly/Skipped check-in is allowed for [date]: today and
  /// past dates only, never a future date. A pure function of its inputs so
  /// it can be unit tested regardless of which real day it runs on.
  static bool canCheckIn(DateTime date, {DateTime? now}) =>
      !_dateOnly(date).isAfter(_dateOnly(now ?? DateTime.now()));

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Advances [_rangeStart] to today if it has fallen into the past, so a
  /// deliberate (re)generation never reuses a stale start date from before
  /// today (e.g. generating late at night, then regenerating after
  /// midnight). Only called from explicit (re)generation actions -
  /// reloading previously persisted/generated state intentionally keeps its
  /// original [_rangeStart] so past days remain visible for catch-up
  /// check-ins (see [_applySavedState]).
  void _advanceRangeStartToTodayIfStale() {
    final today = _dateOnly(DateTime.now());
    if (_rangeStart.isBefore(today)) {
      _rangeStart = today;
    }
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  FirestoreCalendar? _chooseCalendar(
    List<FirestoreCalendar> calendars,
    String userId,
  ) {
    if (calendars.isEmpty) return null;

    final preferredCalendarId = _preferredCalendarId;
    if (preferredCalendarId != null) {
      for (final calendar in calendars) {
        if (calendar.metadata.calendarId == preferredCalendarId) {
          return calendar;
        }
      }
    }

    final defaultId = FirestoreSyncService.defaultCalendarId(userId);
    if (preferredCalendarId == null) {
      for (final calendar in calendars) {
        if (calendar.metadata.calendarId == _calendarId) {
          if (calendar.metadata.calendarId == defaultId) {
            break;
          }
          return calendar;
        }
      }
    }

    final sharedCalendars = calendars
        .where((calendar) => calendar.metadata.memberUserIds.length > 1)
        .toList()
      ..sort((a, b) {
        final memberComparison = b.metadata.memberUserIds.length
            .compareTo(a.metadata.memberUserIds.length);
        if (memberComparison != 0) return memberComparison;
        return b.metadata.updatedAtMillis.compareTo(a.metadata.updatedAtMillis);
      });
    if (sharedCalendars.isNotEmpty) return sharedCalendars.first;

    for (final calendar in calendars) {
      if (calendar.metadata.calendarId == defaultId) {
        return calendar;
      }
    }

    return calendars.first;
  }

  List<FirestoreCalendar> _sortCalendars(
    List<FirestoreCalendar> calendars,
    String userId,
  ) {
    final sorted = [...calendars];
    sorted.sort((a, b) {
      final defaultId = FirestoreSyncService.defaultCalendarId(userId);
      if (a.metadata.calendarId == defaultId) return -1;
      if (b.metadata.calendarId == defaultId) return 1;
      return a.metadata.title
          .toLowerCase()
          .compareTo(b.metadata.title.toLowerCase());
    });
    return sorted;
  }

  Future<String?> _refreshMemberProfiles(
    List<FirestoreCalendar> calendars,
  ) async {
    final memberIds = calendars
        .expand((calendar) => calendar.metadata.memberUserIds)
        .toSet()
        .toList();
    if (memberIds.isEmpty) {
      _memberProfiles = const {};
      return null;
    }
    try {
      final profiles = await _loadUserProfiles(memberIds);
      _memberProfiles = Map.unmodifiable({
        for (final profile in profiles) profile.uid: profile,
      });
      return null;
    } on FirestoreSyncException catch (e) {
      _memberProfiles = const {};
      return e.safeMessage;
    } catch (_) {
      _memberProfiles = const {};
      return 'Member profile lookup failed';
    }
  }

  Future<void> _selectSafeFallbackAfterCalendarRemoval(
    String uid,
    String removedCalendarId,
  ) async {
    final remoteCalendars = await _loadAccessibleCalendars(uid);
    if (_userId != uid) return;
    final remainingCalendars = remoteCalendars
        .where(
          (calendar) => calendar.metadata.calendarId != removedCalendarId,
        )
        .toList();
    await _refreshMemberProfiles(remainingCalendars);
    if (_userId != uid) return;
    _accessibleCalendars = List.unmodifiable(remainingCalendars);
    _preferredCalendarId = null;

    if (remainingCalendars.isNotEmpty) {
      final fallback = _chooseCalendar(remainingCalendars, uid)!;
      _applyCalendarMetadata(fallback.metadata, rememberSelection: true);
      _applySavedState(fallback.state, persistLocal: false);
      _persistLocal(_currentSavedState());
      await _saveStateToFirestore(uid, _calendarId!, _currentSavedState());
      return;
    }

    final defaultCalendarId = FirestoreSyncService.defaultCalendarId(uid);
    final fallbackState = _newCalendarSavedState(
      title: FirestoreSyncService.defaultCalendarTitle,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    _applyCalendarMetadata(
      FirestoreSyncService.defaultMetadata(uid).copyWith(
        updatedAtMillis: fallbackState.updatedAtMillis,
      ),
      rememberSelection: true,
    );
    _applySavedState(fallbackState, persistLocal: false);
    _persistLocal(_currentSavedState());
    await _saveStateToFirestore(uid, defaultCalendarId, _currentSavedState());
  }

  UserProfile? _memberProfileByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final profile in _memberProfiles.values) {
      if (profile.emailLower == normalized) return profile;
    }
    return null;
  }

  String _memberDisplayLabel(String userId) {
    if (userId == _userId) return 'You';
    final profile = _memberProfiles[userId];
    if (profile != null && profile.displayLabel.isNotEmpty) {
      return profile.displayLabel;
    }
    return _shortId(userId);
  }

  void _applySavedState(SavedState saved, {bool persistLocal = true}) {
    _lastRegenerationSnapshot = null;
    activities
      ..clear()
      ..addAll(saved.activities.map((activity) => activity.copy()));
    _seed = saved.seed;
    _updatedAtMillis = saved.updatedAtMillis;
    _planStyle = _parsePlanStyle(saved.planStyle);
    _rangeType = saved.rangeType;
    // SavedState defaults a missing viewMode to rangeType, so old saves
    // (which never separated view from generated type) keep their Plan
    // screen looking the same as before this version shipped.
    _viewMode = saved.viewMode;
    // Old saves never recorded a range start since the range was always
    // re-anchored to "now" on load; defaulting to today gives them a clean,
    // future-facing range under the new anchoring instead of reusing a
    // start date that was never actually saved.
    _rangeStart = saved.rangeStart ?? _dateOnly(DateTime.now());
    _displayName = saved.displayName;
    _displayNameConfirmed =
        saved.displayNameConfirmed && saved.displayName != null;
    final savedCalendarTitle = saved.calendarTitle;
    if (savedCalendarTitle != null) {
      _calendarTitle = savedCalendarTitle;
    }
    _calendarNameConfirmed = saved.calendarNameConfirmed &&
        (savedCalendarTitle != null || _calendarTitle.trim().isNotEmpty);
    _introOnboardingCompleted = saved.introOnboardingCompleted;
    _difficultyEnabled = saved.difficultyEnabled;
    _energyEnabled = saved.energyEnabled;
    _socialEnabled = saved.socialEnabled;
    _defaultDifficulty = saved.defaultDifficulty.clamp(1, 5).toInt();
    _defaultEnergy = _normalizeOption(
      saved.defaultEnergy,
      fallback: 'medium',
      allowed: const ['low', 'medium', 'high'],
    );
    _defaultSocial = _normalizeOption(
      saved.defaultSocial,
      fallback: 'either',
      allowed: const ['solo', 'together', 'group', 'either'],
    );
    _exportPrintOptions = ExportPrintOptions(
      showTime: saved.exportShowTime,
      showDuration: saved.exportShowDuration,
      showCategory: saved.exportShowCategory,
      showCheckInStatus: saved.exportShowCheckInStatus,
      showLockedStatus: saved.exportShowLockedStatus,
      showEnabledDimensions: saved.exportShowEnabledDimensions,
    );
    _feedEnabled = saved.feedEnabled;
    _feedToken = saved.feedToken;
    _feedCreatedAtMillis = saved.feedCreatedAtMillis;
    _feedUpdatedAtMillis = saved.feedUpdatedAtMillis;
    _feedRevokedAtMillis = saved.feedRevokedAtMillis;
    for (final entry in saved.enabledMap.entries) {
      final idx = activities.indexWhere((a) => a.id == entry.key);
      if (idx >= 0) activities[idx].enabled = entry.value;
    }
    _selectedRangeWeekIndex = 0;
    _removedOccurrences = Map<String, bool>.from(saved.removedMap);
    _occurrenceOverrides =
        Map<String, OccurrenceOverride>.from(saved.occurrenceOverrides);
    _manualPlanItems = Map<String, ManualPlanItem>.from(
      saved.manualPlanItems.map((id, item) => MapEntry(id, item.copy())),
    );
    _outsideEventSources = List<UserEventSource>.from(
      saved.outsideEventSources,
    );
    _outsideEventSourceSnapshots =
        saved.outsideEventSourceSnapshots.take(10).toList(growable: false);
    // Loaded before rebuilding _generatedDays so the archive pass below
    // upserts into (rather than replaces) whatever history already exists -
    // see _archiveCurrentRange.
    _planHistory = Map<String, PlanHistoryEntry>.from(saved.planHistory);
    _generatedDays = _buildPlan();
    _applyRemovals();
    _applyManualItems();
    _applyOverlays(saved);
    _applyOccurrenceOverrides();
    _archiveCurrentRange();
    _refreshCachedIcs();

    if (persistLocal) {
      _persistLocal(saved);
    }
  }

  void _persist() {
    _updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    final state = _currentSavedState(updatedAtMillis: _updatedAtMillis);
    _persistLocal(state);
    final uid = _userId;
    final calendarId = _calendarId;
    if (uid != null && calendarId != null) {
      unawaited(_saveStateToFirestore(uid, calendarId, state));
    }
  }

  Future<FirestoreSyncResult> _saveStateToFirestore(
    String uid,
    String calendarId,
    SavedState state,
  ) async {
    _markSyncPending();
    final result = await _saveSelectedFirestoreState(uid, calendarId, state);
    _applySyncResult(result, operation: _SyncOperation.save);
    return result;
  }

  void _markSyncPending() {
    _lastSyncStatus = 'Sync pending';
    _lastSyncErrorMessage = null;
    _lastSyncOperation = null;
    _lastSyncAttemptAtMillis = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  void _applySyncResult(FirestoreSyncResult result,
      {_SyncOperation? operation}) {
    _lastSyncStatus = result.status;
    _lastSyncErrorMessage = result.errorMessage;
    _lastSyncOperation = result.errorMessage != null ? operation : null;
    notifyListeners();
  }

  /// Translates the current safe sync status into a calm, plain-language
  /// [SyncMessage] for the UI. Returns `null` when sync is healthy and no
  /// notice is pending.
  SyncMessage? _buildSyncMessage() {
    if (_remoteUpdatedElsewhere) {
      return const SyncMessage(
        severity: SyncMessageSeverity.info,
        title: 'Updated elsewhere',
        body:
            'This calendar was updated elsewhere. Showing the latest version.',
      );
    }
    final error = _lastSyncErrorMessage;
    if (error == null) return null;
    if (error.toLowerCase().contains('permission denied')) {
      return const SyncMessage(
        severity: SyncMessageSeverity.warning,
        title: "Can't access this calendar",
        body: 'You may not have access to this calendar anymore. '
            'Ask the calendar owner to check sharing.',
      );
    }
    switch (_lastSyncOperation) {
      case _SyncOperation.save:
        return const SyncMessage(
          severity: SyncMessageSeverity.warning,
          title: "Couldn't save",
          body:
              "Couldn't save just now. Your changes are still on this device.",
          actionLabel: 'Retry',
        );
      case _SyncOperation.profile:
        return const SyncMessage(
          severity: SyncMessageSeverity.info,
          title: 'Member names unavailable',
          body: "Couldn't load member names for this calendar right now.",
          actionLabel: 'Retry',
        );
      case _SyncOperation.load:
      case null:
        return const SyncMessage(
          severity: SyncMessageSeverity.warning,
          title: 'Sync issue',
          body: "Couldn't load the latest shared calendar. "
              'Check your connection and try again.',
          actionLabel: 'Retry',
        );
    }
  }

  @visibleForTesting
  void setSyncDiagnosticForTesting({
    required String status,
    String? errorMessage,
    int? attemptedAtMillis,
  }) {
    _lastSyncStatus = status;
    _lastSyncErrorMessage = errorMessage;
    _lastSyncAttemptAtMillis = attemptedAtMillis;
    notifyListeners();
  }

  void _persistLocal(SavedState state) {
    PersistenceService.saveActivities(state.activities);
    PersistenceService.saveSeed(state.seed);
    PersistenceService.saveUpdatedAtMillis(state.updatedAtMillis);
    PersistenceService.savePlanStyle(state.planStyle);
    PersistenceService.saveRangeType(state.rangeType);
    PersistenceService.saveViewMode(state.viewMode);
    PersistenceService.saveRangeStartMillis(
        state.rangeStart?.millisecondsSinceEpoch);
    PersistenceService.saveDisplayName(state.displayName);
    PersistenceService.saveDisplayNameConfirmed(state.displayNameConfirmed);
    PersistenceService.saveCalendarTitle(state.calendarTitle);
    PersistenceService.saveSelectedCalendarId(state.selectedCalendarId);
    PersistenceService.saveCalendarNameConfirmed(state.calendarNameConfirmed);
    PersistenceService.saveIntroOnboardingCompleted(
      state.introOnboardingCompleted,
    );
    PersistenceService.saveDifficultyEnabled(state.difficultyEnabled);
    PersistenceService.saveEnergyEnabled(state.energyEnabled);
    PersistenceService.saveSocialEnabled(state.socialEnabled);
    PersistenceService.saveDefaultDifficulty(state.defaultDifficulty);
    PersistenceService.saveDefaultEnergy(state.defaultEnergy);
    PersistenceService.saveDefaultSocial(state.defaultSocial);
    PersistenceService.saveExportShowTime(state.exportShowTime);
    PersistenceService.saveExportShowDuration(state.exportShowDuration);
    PersistenceService.saveExportShowCategory(state.exportShowCategory);
    PersistenceService.saveExportShowCheckInStatus(
      state.exportShowCheckInStatus,
    );
    PersistenceService.saveExportShowLockedStatus(
      state.exportShowLockedStatus,
    );
    PersistenceService.saveExportShowEnabledDimensions(
      state.exportShowEnabledDimensions,
    );
    PersistenceService.saveFeedEnabled(state.feedEnabled);
    PersistenceService.saveFeedToken(state.feedToken);
    PersistenceService.saveFeedCreatedAtMillis(state.feedCreatedAtMillis);
    PersistenceService.saveFeedUpdatedAtMillis(state.feedUpdatedAtMillis);
    PersistenceService.saveFeedRevokedAtMillis(state.feedRevokedAtMillis);
    PersistenceService.saveCachedIcsText(state.cachedIcsText);
    PersistenceService.saveCachedIcsUpdatedAtMillis(
      state.cachedIcsUpdatedAtMillis,
    );
    for (final entry in state.enabledMap.entries) {
      PersistenceService.saveEnabled(entry.key, entry.value);
    }
    PersistenceService.saveCheckinMap(state.checkinMap);
    PersistenceService.saveLockedMap(state.lockedMap);
    PersistenceService.saveRemovedMap(state.removedMap);
    PersistenceService.saveOccurrenceOverridesMap(state.occurrenceOverrides);
    PersistenceService.saveManualPlanItems(state.manualPlanItems);
    PersistenceService.savePlanHistoryMap(state.planHistory);
    PersistenceService.saveOutsideEventSources(state.outsideEventSources);
    PersistenceService.saveOutsideEventSourceSnapshots(
      state.outsideEventSourceSnapshots,
    );
  }

  bool _applyCalendarMetadata(
    CalendarMetadata metadata, {
    bool rememberSelection = false,
  }) {
    final calendarIdChanged = _calendarId != metadata.calendarId;
    final changed = calendarIdChanged ||
        _calendarTitle != metadata.title ||
        _calendarOwnerUserId != metadata.ownerUserId ||
        _calendarMemberUserIds.join('|') != metadata.memberUserIds.join('|');

    _calendarId = metadata.calendarId;
    if (rememberSelection) {
      _preferredCalendarId = metadata.calendarId;
    }
    _calendarTitle = metadata.title;
    _calendarOwnerUserId = metadata.ownerUserId;
    _calendarMemberUserIds = List.unmodifiable(metadata.memberUserIds);
    if (calendarIdChanged) _reloadCachedOutsideEventsForCurrentCalendar();
    return changed;
  }

  void _clearCalendarMetadata() {
    final calendarIdChanged = _calendarId != null;
    _calendarId = null;
    _preferredCalendarId = null;
    if (!_calendarNameConfirmed) {
      _calendarTitle = FirestoreSyncService.defaultCalendarTitle;
    }
    _calendarOwnerUserId = null;
    _calendarMemberUserIds = const [];
    if (calendarIdChanged) _reloadCachedOutsideEventsForCurrentCalendar();
  }

  /// Cached outside-event results are device-local (never synced; see
  /// [SavedState.outsideEventSources] for the part that does sync), but kept
  /// scoped to [_calendarId] so switching calendars never shows another
  /// calendar's fetched events under the newly-selected calendar's sources.
  void _reloadCachedOutsideEventsForCurrentCalendar() {
    _cachedOutsideEvents = PersistenceService.loadCachedOutsideEvents(
      _calendarId,
    );
    _cachedOutsideEventsFetchedAtMillis =
        PersistenceService.loadCachedOutsideEventsFetchedAtMillis(
      _calendarId,
    );
  }

  SavedState _newCalendarSavedState({
    required String title,
    required int updatedAtMillis,
  }) {
    return SavedState(
      activities: PlannerService.defaultActivities
          .map((activity) => activity.copy())
          .toList(),
      seed: 0,
      updatedAtMillis: updatedAtMillis,
      displayName: _displayName,
      displayNameConfirmed: _displayNameConfirmed,
      calendarTitle: title,
      calendarNameConfirmed: true,
      introOnboardingCompleted: _introOnboardingCompleted,
      outsideEventSources: const [],
      outsideEventSourceSnapshots: const [],
      enabledMap: const {},
      checkinMap: const {},
      lockedMap: const {},
    );
  }

  SavedState _currentSavedState({int? updatedAtMillis}) {
    _refreshCachedIcs();
    final enabledMap = <String, bool>{};
    for (final a in activities) {
      enabledMap[a.id] = a.enabled;
    }

    final checkinMap = <String, int>{};
    final lockedMap = <String, bool>{};
    // Save check-ins/locks for the whole generated range, not just the
    // visible week, so the non-visible week of a twoWeek range survives.
    for (final day in _generatedDays) {
      final dateKey = DayPlan.dateKey(day.date);
      for (final pa in day.activities) {
        final occurrenceKey = '$dateKey:${pa.activity.id}';
        checkinMap[occurrenceKey] = pa.status.index;
        lockedMap[occurrenceKey] = pa.locked;
      }
    }

    return SavedState(
      activities: activities.map((activity) => activity.copy()).toList(),
      seed: _seed,
      updatedAtMillis: updatedAtMillis ?? _updatedAtMillis,
      planStyle: _planStyle.name,
      viewMode: _viewMode,
      rangeStart: _rangeStart,
      rangeType: _rangeType,
      displayName: _displayName,
      displayNameConfirmed: _displayNameConfirmed,
      calendarTitle: _calendarTitle,
      selectedCalendarId: _calendarId,
      calendarNameConfirmed: _calendarNameConfirmed,
      introOnboardingCompleted: _introOnboardingCompleted,
      difficultyEnabled: _difficultyEnabled,
      energyEnabled: _energyEnabled,
      socialEnabled: _socialEnabled,
      defaultDifficulty: _defaultDifficulty,
      defaultEnergy: _defaultEnergy,
      defaultSocial: _defaultSocial,
      feedEnabled: _feedEnabled,
      feedToken: _feedToken,
      feedCreatedAtMillis: _feedCreatedAtMillis,
      feedUpdatedAtMillis: _feedUpdatedAtMillis,
      feedRevokedAtMillis: _feedRevokedAtMillis,
      cachedIcsText: _cachedIcsText,
      cachedIcsUpdatedAtMillis: _cachedIcsUpdatedAtMillis,
      exportShowTime: _exportPrintOptions.showTime,
      exportShowDuration: _exportPrintOptions.showDuration,
      exportShowCategory: _exportPrintOptions.showCategory,
      exportShowCheckInStatus: _exportPrintOptions.showCheckInStatus,
      exportShowLockedStatus: _exportPrintOptions.showLockedStatus,
      exportShowEnabledDimensions: _exportPrintOptions.showEnabledDimensions,
      enabledMap: enabledMap,
      checkinMap: checkinMap,
      lockedMap: lockedMap,
      removedMap: Map<String, bool>.from(_removedOccurrences),
      occurrenceOverrides:
          Map<String, OccurrenceOverride>.from(_occurrenceOverrides),
      manualPlanItems: Map<String, ManualPlanItem>.from(
        _manualPlanItems.map((id, item) => MapEntry(id, item.copy())),
      ),
      planHistory: Map<String, PlanHistoryEntry>.from(_planHistory),
      outsideEventSources: List<UserEventSource>.from(_outsideEventSources),
      outsideEventSourceSnapshots:
          List<SourceListSnapshot>.from(_outsideEventSourceSnapshots),
    );
  }

  /// Locked items across the whole generated range, keyed by exact date
  /// (not array position or day offset), so regeneration preserves locks
  /// regardless of which day is currently visible or where [_rangeStart]
  /// ends up moving to.
  Map<DateTime, List<PlannedActivity>> _collectLocked() {
    final result = <DateTime, List<PlannedActivity>>{};
    for (final day in _generatedDays) {
      // Manual items are pinned user additions, not generated occurrences;
      // they are re-applied separately by [_applyManualItems].
      final locked = day.activities
          .where((a) => a.locked && a.manualItemId == null)
          .toList();
      if (locked.isNotEmpty) result[_dateOnly(day.date)] = locked;
    }
    return result;
  }

  List<DayPlan> _buildPlan(
      {Map<DateTime, List<PlannedActivity>>? lockedItems}) {
    final start = _rangeStart;
    final periodIndex = start.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
    final seed = periodIndex + _seed * 1000;

    final lockedIds = lockedItems == null
        ? <String>{}
        : lockedItems.values.expand((l) => l).map((a) => a.activity.id).toSet();

    final pool = activities
        .where((a) => a.enabled && !lockedIds.contains(a.id))
        .toList();

    final scheduledContext = <int, List<PlannedActivity>>{
      if (lockedItems != null)
        for (final entry in lockedItems.entries)
          entry.key.difference(start).inDays: entry.value,
    };

    final generation = RangePlannerService.generateWithDiagnostics(
      type: _rangeType,
      start: start,
      pool: pool,
      seed: seed,
      planStyle: _planStyle,
      difficultyAware: _difficultyEnabled,
      scheduledContext: scheduledContext,
    );
    _plannerConflictMessage = _buildPlannerConflictMessage(generation);
    final plan = generation.range.days;

    if (lockedItems != null) {
      for (final day in plan) {
        final dayLocked = lockedItems[_dateOnly(day.date)] ?? const [];
        if (dayLocked.isNotEmpty) {
          day.activities.addAll(dayLocked);
          day.activities.sort(
            (a, b) => PlannerService.timeRank(a.timeSlot)
                .compareTo(PlannerService.timeRank(b.timeSlot)),
          );
        }
      }
    }

    return plan;
  }

  String? _buildPlannerConflictMessage(
    RangePlannerGenerationResult generation,
  ) {
    final messages = <String>[];
    if (generation.hasBlockedActivitySlots) {
      final count = generation.unfilledActivityCount;
      final slotLabel = count == 1 ? 'slot was' : 'slots were';
      messages.add(
        'This plan is lighter than expected because $count activity '
        '$slotLabel blocked by rules. Try relaxing weekdays, increasing max '
        'per week, turning off no-consecutive-days, or choosing a lighter '
        'plan style.',
      );
    }
    if (generation.mustIncludeShortfallCount > 0) {
      messages.add(
        'A "Must include in plans" activity couldn\'t reach its max per '
        'week because it has fewer allowed days than that. Add more '
        'allowed days or lower its max per week.',
      );
    }
    if (messages.isEmpty) return null;
    return messages.join('\n\n');
  }

  /// Applies saved check-in/lock state to [_generatedDays] (the whole
  /// generated range, not just the visible week), preferring the
  /// occurrence key (`yyyy-MM-dd:activityId`) and falling back to the
  /// legacy bare activity-id key so saved data from before the occurrence
  /// key migration still applies. (Legacy bare-id entries only ever exist
  /// on a [RangeType.week] range, since any document new enough to have
  /// [RangeType.twoWeek] has already been saved at least once under
  /// occurrence keys.) The next [_persist] rewrites everything under
  /// occurrence keys (see [_currentSavedState]).
  void _applyOverlays(SavedState saved) {
    for (final day in _generatedDays) {
      final dateKey = DayPlan.dateKey(day.date);
      for (final pa in day.activities) {
        final id = pa.activity.id;
        final occurrenceKey = '$dateKey:$id';

        final statusIdx =
            saved.checkinMap[occurrenceKey] ?? saved.checkinMap[id];
        if (statusIdx != null && statusIdx < CheckStatus.values.length) {
          pa.status = CheckStatus.values[statusIdx];
        }

        final locked = saved.lockedMap[occurrenceKey] ?? saved.lockedMap[id];
        if (locked != null) pa.locked = locked;
      }
    }
  }

  /// Strips any [PlannedActivity] matching a previously removed occurrence
  /// key out of a freshly built [_generatedDays], so a "Remove from this
  /// plan" choice (see [removeFromPlan]) survives a reload/sync instead of
  /// only lasting until the in-memory list is rebuilt from scratch.
  void _applyRemovals() {
    if (_removedOccurrences.isEmpty) return;
    for (final day in _generatedDays) {
      day.activities.removeWhere(
        (pa) =>
            _removedOccurrences[_occurrenceKey(day.date, pa.activity.id)] ==
            true,
      );
    }
  }

  /// Applies saved occurrence-level edits (actual scheduled time, category,
  /// and planning dimensions; see [editPlannedOccurrence]) to a freshly
  /// built [_generatedDays], so an edit survives reload/sync the same way
  /// [_applyOverlays] does for check-ins and locks.
  void _applyOccurrenceOverrides() {
    if (_occurrenceOverrides.isEmpty) return;
    for (final day in _generatedDays) {
      var changedTimes = false;
      for (final pa in day.activities) {
        final override =
            _occurrenceOverrides[_occurrenceKey(day.date, pa.activity.id)];
        if (override == null) continue;
        if (override.timeSlot != null) {
          pa.timeSlot = override.timeSlot!;
          changedTimes = true;
        }
        pa.categoryOverride = override.category;
        pa.difficultyOverride = override.difficulty;
        pa.energyOverride = override.energy;
        pa.socialOverride = override.social;
      }
      if (changedTimes) {
        day.activities.sort(
          (a, b) => PlannerService.timeRank(a.timeSlot)
              .compareTo(PlannerService.timeRank(b.timeSlot)),
        );
      }
    }
  }

  /// Adds user-created manual plan items into [_generatedDays] so they
  /// appear in every plan view, export, print preview, and the ICS feed.
  /// Manual items are always sorted into the day's activity list by time.
  void _applyManualItems() {
    if (_manualPlanItems.isEmpty) return;
    final dayByKey = {
      for (final d in _generatedDays) DayPlan.dateKey(d.date): d,
    };
    var changedTimes = false;
    for (final item in _manualPlanItems.values) {
      final day = dayByKey[item.dateKey];
      if (day == null) continue;
      final existingIndex =
          day.activities.indexWhere((pa) => pa.manualItemId == item.id);
      if (existingIndex >= 0) {
        // Refresh the backing synthetic activity in case the manual item
        // was edited while another view held the old PlannedActivity.
        day.activities[existingIndex] = item.toPlannedActivity(
          status: day.activities[existingIndex].status,
          locked: day.activities[existingIndex].locked,
        );
      } else {
        day.activities.add(item.toPlannedActivity());
        changedTimes = true;
      }
    }
    if (changedTimes) {
      for (final day in _generatedDays) {
        day.activities.sort(
          (a, b) => PlannerService.timeRank(a.timeSlot)
              .compareTo(PlannerService.timeRank(b.timeSlot)),
        );
      }
    }
  }

  /// Passively archives every occurrence currently in [_generatedDays].
  /// Called after every build/rebuild ([regenerate], [generateRange],
  /// [setPlanStyle], [_applySavedState], [addManualPlanItem],
  /// [removeManualPlanItem], and the no-saved-state constructor path) so a
  /// dated occurrence is captured before it can fall out of
  /// [_generatedDays] (e.g. when [_rangeStart] advances past it). Never
  /// marks anything [PlanHistoryEntry.removed] - an occurrence present here
  /// is, by definition, currently in the live plan; see [removeFromPlan]
  /// for the only path that sets that flag.
  void _archiveCurrentRange() {
    for (final day in _generatedDays) {
      for (final pa in day.activities) {
        _archiveOccurrence(day, pa, forceSnapshotUpdate: false);
      }
    }
  }

  /// Resolves [pa]'s source/library-link metadata and upserts its archive
  /// entry. [forceSnapshotUpdate] is only ever `true` for a deliberate
  /// per-occurrence edit ([editPlannedOccurrence]); every other caller
  /// (passive rebuilds, check-in, lock, removal) passes `false` so an
  /// already-frozen past snapshot can't be quietly overwritten by a source
  /// [Activity] rename or a regeneration that happens to land a different
  /// occurrence on the same key. See [_upsertArchiveEntry].
  void _archiveOccurrence(
    DayPlan day,
    PlannedActivity pa, {
    required bool forceSnapshotUpdate,
    bool removed = false,
  }) {
    final manualId = pa.manualItemId;
    final manualItem = manualId == null ? null : _manualPlanItems[manualId];
    final source = manualItem == null
        ? PlanHistorySource.generated
        : manualItem.isOutsideEvent
            ? PlanHistorySource.outsideEvent
            : PlanHistorySource.manual;
    final sourceActivityId =
        manualItem == null ? pa.activity.id : manualItem.sourceActivityId;

    _upsertArchiveEntry(
      occurrenceKey: _occurrenceKey(day.date, pa.activity.id),
      date: day.date,
      sourceActivityId: sourceActivityId,
      title: pa.title,
      timeSlot: pa.timeSlot,
      durationMinutes: pa.activity.durationMinutes,
      category: pa.category,
      difficulty: pa.difficulty,
      energy: pa.energy,
      social: pa.social,
      source: source,
      status: pa.status,
      locked: pa.locked,
      removed: removed,
      forceSnapshotUpdate: forceSnapshotUpdate,
    );
  }

  /// Creates or updates one [PlanHistoryEntry]. [status]/[locked]/[removed]
  /// always reflect the latest call. The remaining "snapshot" fields
  /// (title/timeSlot/durationMinutes/category/dimensions/source/
  /// sourceActivityId) are frozen once an entry exists for a date that is
  /// today or earlier, unless [forceSnapshotUpdate] is true - this is what
  /// lets the archive answer "what did this day actually look like" even
  /// after the source [Activity] is renamed or the plan is regenerated.
  /// Future-dated entries keep refreshing freely, since nothing has
  /// happened there yet.
  void _upsertArchiveEntry({
    required String occurrenceKey,
    required DateTime date,
    String? sourceActivityId,
    required String title,
    required String timeSlot,
    required int durationMinutes,
    required String category,
    required int difficulty,
    required String energy,
    required String social,
    required PlanHistorySource source,
    required CheckStatus status,
    required bool locked,
    bool removed = false,
    required bool forceSnapshotUpdate,
  }) {
    final dateOnly = _dateOnly(date);
    final existing = _planHistory[occurrenceKey];
    final isPastOrToday = !dateOnly.isAfter(_dateOnly(DateTime.now()));
    final keepFrozenSnapshot =
        existing != null && isPastOrToday && !forceSnapshotUpdate;
    final now = DateTime.now().millisecondsSinceEpoch;

    _planHistory[occurrenceKey] = PlanHistoryEntry(
      occurrenceKey: occurrenceKey,
      date: dateOnly,
      sourceActivityId:
          keepFrozenSnapshot ? existing.sourceActivityId : sourceActivityId,
      title: keepFrozenSnapshot ? existing.title : title,
      timeSlot: keepFrozenSnapshot ? existing.timeSlot : timeSlot,
      durationMinutes:
          keepFrozenSnapshot ? existing.durationMinutes : durationMinutes,
      category: keepFrozenSnapshot ? existing.category : category,
      difficulty: keepFrozenSnapshot ? existing.difficulty : difficulty,
      energy: keepFrozenSnapshot ? existing.energy : energy,
      social: keepFrozenSnapshot ? existing.social : social,
      source: keepFrozenSnapshot ? existing.source : source,
      status: status,
      locked: locked,
      removed: removed,
      createdAtMillis: existing?.createdAtMillis ?? now,
      updatedAtMillis: now,
    );
  }

  static String _normalizeActivityTitle(String title) {
    return title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  static bool _looksLikeFeed(String url) {
    final lower = url.trim().toLowerCase();
    return lower.endsWith('.rss') ||
        lower.endsWith('.xml') ||
        lower.endsWith('/feed') ||
        lower.endsWith('/feed/') ||
        lower.contains('rss') ||
        lower.contains('atom');
  }

  static bool _looksLikeIcs(String url) {
    final lower = url.trim().toLowerCase();
    return lower.endsWith('.ics') ||
        lower.contains('ical=1') ||
        lower.contains('outlook-ical=1') ||
        lower.startsWith('webcal://') ||
        lower.contains('/ical/');
  }

  static String _sourceNameFromUrl(String url) {
    final parsed = Uri.tryParse(url);
    final host = parsed?.host;
    if (host == null || host.isEmpty) return 'Event source';
    return host.replaceFirst(RegExp(r'^www\.'), '');
  }

  void _enableFeed() {
    final hasToken = _feedToken != null && _feedToken!.isNotEmpty;
    if (_feedEnabled && hasToken) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _feedEnabled = true;
    if (!hasToken) {
      _feedToken = _generateFeedToken();
      _feedCreatedAtMillis ??= now;
    }
    _feedUpdatedAtMillis = now;
    _persist();
    notifyListeners();
  }

  void _disableFeed() {
    if (!_feedEnabled) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    _feedEnabled = false;
    _feedUpdatedAtMillis = now;
    _persist();
    notifyListeners();
  }

  void _refreshCachedIcs() {
    if (!_feedEnabled) {
      _cachedIcsText = null;
      _cachedIcsUpdatedAtMillis = null;
      return;
    }
    // Publishes the visible week slice only for now; the feed does not yet
    // publish a full twoWeek range.
    _cachedIcsText = IcsCalendarService.generate(
      calendarId: _calendarId ?? _feedToken ?? 'local-calendar',
      calendarTitle: _calendarTitle,
      plan: weekPlan,
      manualPlanItemsById: _manualPlanItems,
    );
    _cachedIcsUpdatedAtMillis = DateTime.now().millisecondsSinceEpoch;
  }

  static String _generateFeedToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static PlanStyle _parsePlanStyle(String value) {
    return PlanStyle.values.firstWhere(
      (s) => s.name == value,
      orElse: () => PlanStyle.balanced,
    );
  }

  static String _normalizeOption(
    String value, {
    required String fallback,
    required List<String> allowed,
  }) {
    final normalized = value.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : fallback;
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value.characters.first.toUpperCase()}${value.substring(1)}';
  }

  static String? _normalizeNullableId(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }
}

// ─── InheritedNotifier scope ──────────────────────────────────────────────────

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}
