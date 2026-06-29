import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/event_suggestion.dart';
import '../services/browser_open_url.dart';
import '../services/outside_event_discovery_service.dart';
import '../services/outside_event_source_adapter.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/category_chip.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

class OutsideEventsScreen extends StatefulWidget {
  const OutsideEventsScreen({super.key});

  @override
  State<OutsideEventsScreen> createState() => _OutsideEventsScreenState();
}

class _OutsideEventsScreenState extends State<OutsideEventsScreen> {
  String? _refreshErrorMessage;
  final Set<String> _selectedSources = {};
  final Set<String> _selectedTags = {};
  final ScrollController _scrollController = ScrollController();
  bool _sourcesExpanded = false;
  bool _tagsExpanded = false;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset > 560;
    if (shouldShow == _showScrollToTop || !mounted) return;
    setState(() => _showScrollToTop = shouldShow);
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  // Deliberately reads AppState's cache directly in build() below instead
  // of caching a Future in state - that one-shot-Future pattern is what
  // caused the list to stay stale until navigating away and back: a refresh
  // kicked off from Settings (or finishing while this screen was the
  // *previous*, still-mounted route) updated AppState's cache, but nothing
  // pointed this screen's Future at the new data until it was torn down and
  // rebuilt from scratch. Reading the cache fresh on every build reacts to
  // AppState.notifyListeners() like the rest of the app expects.
  //
  // Never fetches outside events automatically on open - only shows
  // whatever is already cached on this device. Fetching costs AI/API
  // credits, so it only happens when the user taps refresh below.

  Future<void> _refresh() async {
    final state = AppStateScope.of(context);
    if (state.isRefreshingOutsideEvents) return;
    setState(() => _refreshErrorMessage = null);
    try {
      await state.refreshOutsideEventSources();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _refreshErrorMessage = 'Try refresh. The rest of the planner is '
            'unchanged.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final isRefreshing = state.isRefreshingOutsideEvents;
    final hasEverFetched = state.cachedOutsideEventsFetchedAtMillis != null;
    final result = state.cachedOutsideEventDiscoveryResult();
    final events = _filteredEvents(result.events);
    final allTags = _allTags(result.events);
    return Scaffold(
      backgroundColor: backgroundCream,
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              key: const ValueKey('outside-events-back-to-top'),
              tooltip: 'Back to top',
              onPressed: _scrollToTop,
              backgroundColor: surfaceWhite,
              foregroundColor: primaryTerracotta,
              elevation: 2,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LifeShuffleHeader(),
            _OutsideEventsTopBar(
              isRefreshing: isRefreshing,
              onBack: () => Navigator.of(context).pop(),
              onRefresh: () => unawaited(_refresh()),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: constraints.maxWidth >= 700,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 128),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Browse sourced events and add the ones you actually want. '
                            'Sources sync across your devices for this calendar; '
                            'fetched results are cached on this device only.',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (isRefreshing) ...[
                            _RefreshProgressBanner(state: state),
                            const SizedBox(height: 14),
                          ],
                          if (_refreshErrorMessage != null)
                            _MessageCard(
                              icon: Icons.error_outline_rounded,
                              title: 'Events could not load',
                              body: _refreshErrorMessage!,
                              color: const Color(0xFFFFF3EC),
                            )
                          else if (isRefreshing && !hasEverFetched)
                            const _LoadingList()
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FilterSection(
                                  sources: result.sources,
                                  events: result.events,
                                  selectedSources: _selectedSources,
                                  onToggleSource: _toggleSource,
                                  sourcesExpanded: _sourcesExpanded,
                                  onToggleSourcesExpanded: () => setState(
                                    () => _sourcesExpanded = !_sourcesExpanded,
                                  ),
                                  onClearSources: () => setState(
                                    _selectedSources.clear,
                                  ),
                                  allTags: allTags,
                                  selectedTags: _selectedTags,
                                  onToggleTag: _toggleTag,
                                  tagsExpanded: _tagsExpanded,
                                  onToggleTagsExpanded: () => setState(
                                    () => _tagsExpanded = !_tagsExpanded,
                                  ),
                                  onClearTags: () => setState(
                                    _selectedTags.clear,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (result.warnings.isNotEmpty ||
                                    result.aiStatusMessage.isNotEmpty) ...[
                                  _DiagnosticsSection(
                                    result: result,
                                    fetchedAtMillis: state
                                        .cachedOutsideEventsFetchedAtMillis,
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (events.isEmpty)
                                  !hasEverFetched
                                      ? const _MessageCard(
                                          icon: Icons.travel_explore_rounded,
                                          title: 'Nothing fetched yet',
                                          body: 'Tap refresh above to fetch '
                                              'outside events from your sources. '
                                              'No event is added unless you tap '
                                              'Add.',
                                          color: surfaceWhite,
                                        )
                                      : const _MessageCard(
                                          icon: Icons.search_off_rounded,
                                          title: 'No matching outside events',
                                          body: 'Try clearing filters or tap '
                                              'refresh above. No event is added '
                                              'unless you tap Add.',
                                          color: surfaceWhite,
                                        )
                                else
                                  ...events.map(
                                    (event) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _EventSuggestionCard(
                                        event: event,
                                        added: _isAdded(event),
                                        onAdd: () => _addEvent(event),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<EventSuggestion> _filteredEvents(List<EventSuggestion> events) {
    return events.where((event) {
      final sourceMatch = _selectedSources.isEmpty ||
          event.contributingSourceIds.any(_selectedSources.contains);
      final tagMatch =
          _selectedTags.isEmpty || event.tags.any(_selectedTags.contains);
      return sourceMatch && tagMatch;
    }).toList();
  }

  List<String> _allTags(List<EventSuggestion> events) {
    final tags = events.expand((event) => event.tags).toSet().toList()..sort();
    return tags;
  }

  void _toggleSource(String sourceId) {
    setState(() {
      if (_selectedSources.contains(sourceId)) {
        _selectedSources.remove(sourceId);
      } else {
        _selectedSources.add(sourceId);
      }
    });
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  bool _isAdded(EventSuggestion event) {
    final state = AppStateScope.of(context);
    return state.manualPlanItems.any(
      (item) => item.outsideEventId == event.id,
    );
  }

  void _addEvent(EventSuggestion event) {
    final state = AppStateScope.of(context);
    if (_isAdded(event)) return;
    final item = event.toManualPlanItem(
      id: 'outside_${event.id}_${DateTime.now().microsecondsSinceEpoch}',
    );
    state.addManualPlanItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${event.displayTitle} added to your plan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  static String _shortTimestamp(int millis) {
    final value = DateTime.fromMillisecondsSinceEpoch(millis);
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.year}-$month-$day $hour:$minute $period';
  }
}

class _OutsideEventsTopBar extends StatelessWidget {
  const _OutsideEventsTopBar({
    required this.isRefreshing,
    required this.onBack,
    required this.onRefresh,
  });

  final bool isRefreshing;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: backgroundCream,
        border: Border(bottom: BorderSide(color: borderWarm)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 8),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('outside-events-back'),
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: textMuted,
            ),
          ),
          Expanded(
            child: Text(
              'Outside events',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lora(
                fontSize: 27,
                fontWeight: FontWeight.w500,
                color: textPrimary,
                height: 1.2,
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('outside-events-refresh'),
            tooltip: 'Refresh events',
            onPressed: isRefreshing ? null : onRefresh,
            icon: isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryTerracotta,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: primaryTerracotta,
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 160,
                  height: 14,
                  decoration: BoxDecoration(
                    color: warmBeige,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EDE6),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown above the event list while a refresh is in flight: which source is
/// currently being checked and how far through the list the refresh is, so
/// a slow fetch (10+ sources, each a network round trip) doesn't look stuck.
class _RefreshProgressBanner extends StatelessWidget {
  const _RefreshProgressBanner({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('outside-events-refresh-progress'),
      color: const Color(0xFFEFF3FA),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.refreshProgressLabel,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.sources,
    required this.events,
    required this.selectedSources,
    required this.onToggleSource,
    required this.sourcesExpanded,
    required this.onToggleSourcesExpanded,
    required this.onClearSources,
    required this.allTags,
    required this.selectedTags,
    required this.onToggleTag,
    required this.tagsExpanded,
    required this.onToggleTagsExpanded,
    required this.onClearTags,
  });

  final List<OutsideEventSourceConfig> sources;
  final List<EventSuggestion> events;

  /// [OutsideEventSourceConfig.id] values, not [OutsideEventSourceType] -
  /// several user-added sources can share a type (RSS/Atom or web page), so
  /// filtering has to be per-source-id or every same-type pill would
  /// select/deselect together.
  final Set<String> selectedSources;
  final ValueChanged<String> onToggleSource;
  final bool sourcesExpanded;
  final VoidCallback onToggleSourcesExpanded;
  final VoidCallback onClearSources;
  final List<String> allTags;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggleTag;
  final bool tagsExpanded;
  final VoidCallback onToggleTagsExpanded;
  final VoidCallback onClearTags;

  @override
  Widget build(BuildContext context) {
    final fetchableSources =
        sources.where((source) => source.canFetch).toList();
    return LsCard(
      key: const ValueKey('outside-events-filters'),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CollapsibleFilterGroup(
            groupKey: const ValueKey('outside-events-sources-filter'),
            label: 'Sources',
            itemCount: fetchableSources.length,
            selectedCount: selectedSources.length,
            expanded: sourcesExpanded,
            onToggleExpanded: onToggleSourcesExpanded,
            onClear: onClearSources,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: fetchableSources.map((source) {
                final selected = selectedSources.contains(source.id);
                final count = events
                    .where((event) => event.contributingSourceIds.contains(
                          source.id,
                        ))
                    .length;
                return _FilterChip(
                  label: '${source.displayName} ($count)',
                  selected: selected,
                  onTap: () => onToggleSource(source.id),
                );
              }).toList(),
            ),
          ),
          if (allTags.isNotEmpty) ...[
            const Divider(height: 1, thickness: 1, color: borderWarm),
            _CollapsibleFilterGroup(
              groupKey: const ValueKey('outside-events-tags-filter'),
              label: 'Tags',
              itemCount: allTags.length,
              selectedCount: selectedTags.length,
              expanded: tagsExpanded,
              onToggleExpanded: onToggleTagsExpanded,
              onClear: onClearTags,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allTags.map((tag) {
                  return _FilterChip(
                    label: tag,
                    selected: selectedTags.contains(tag),
                    onTap: () => onToggleTag(tag),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CollapsibleFilterGroup extends StatelessWidget {
  const _CollapsibleFilterGroup({
    required this.groupKey,
    required this.label,
    required this.itemCount,
    required this.selectedCount,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onClear,
    required this.child,
  });

  final Key groupKey;
  final String label;
  final int itemCount;
  final int selectedCount;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onClear;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final summary = selectedCount == 0
        ? 'All $itemCount available'
        : '$selectedCount selected';
    return Material(
      key: groupKey,
      type: MaterialType.transparency,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onToggleExpanded,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          summary,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selectedCount == 0
                                ? textMuted
                                : primaryTerracotta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (selectedCount > 0)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
              IconButton(
                tooltip: expanded ? 'Hide $label' : 'Show $label',
                onPressed: onToggleExpanded,
                icon: Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: textMuted,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(alignment: Alignment.centerLeft, child: child),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? primaryTerracotta : surfaceWhite,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? primaryTerracotta : borderWarmStrong,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : textPrimary,
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsSection extends StatelessWidget {
  const _DiagnosticsSection({
    required this.result,
    required this.fetchedAtMillis,
  });

  final OutsideEventDiscoveryResult result;
  final int? fetchedAtMillis;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      color: const Color(0xFFFFF7E8),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const ValueKey('outside-events-diagnostics'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: textMuted,
        collapsedIconColor: textMuted,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          'Source status',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fetchedAtMillis != null) ...[
                  Text(
                    'Last fetched: ${_OutsideEventsScreenState._shortTimestamp(fetchedAtMillis!)}',
                    key: const ValueKey('outside-events-last-fetched'),
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  result.aiStatusMessage,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
                ...result.warnings.map(
                  (warning) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${warning.sourceName}: ${warning.message}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textMuted,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventSuggestionCard extends StatelessWidget {
  const _EventSuggestionCard({
    required this.event,
    required this.added,
    required this.onAdd,
  });

  final EventSuggestion event;
  final bool added;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final visibleTags = event.tags.where((tag) {
      final normalized = tag.trim().toLowerCase();
      return normalized != event.sourceName.trim().toLowerCase() &&
          normalized != event.sourceType.label.toLowerCase();
    }).toList();
    final visibleMissingFields = event.missingFields
        .where((field) => field.trim().toLowerCase() != 'price')
        .toList();
    final sourceUrl = event.sourceUrl?.trim();
    final ticketUrl = event.ticketUrl?.trim();

    return LsCard(
      key: ValueKey('outside-event-card-${event.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: categoryChipBg(event.category),
                ),
                child: Icon(
                  _iconFor(event),
                  size: 18,
                  color: categoryIconColor(event.category),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.displayTitle,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      event.displaySummary,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaPill(
                icon: Icons.schedule_rounded,
                label: _dateTimeLabel(event.startDateTime),
              ),
              _MetaPill(
                icon: Icons.place_outlined,
                label: event.displayLocation,
              ),
              if (event.address?.trim().isNotEmpty == true)
                _MetaPill(
                  icon: Icons.map_outlined,
                  label: event.address!.trim(),
                ),
              _MetaPill(
                icon: Icons.local_offer_outlined,
                label: event.displayPrice,
              ),
              CategoryChip(category: event.category),
            ],
          ),
          if (event.extractionMode != null || event.confidence != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ExtractionModeChip(event: event),
                if (event.confidence != null)
                  _MetaPill(
                    icon: Icons.verified_outlined,
                    label: '${(event.confidence! * 100).round()}% confidence',
                  ),
              ],
            ),
          ],
          if (visibleTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: visibleTags.take(5).map((tag) {
                return Text(
                  '#$tag',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                );
              }).toList(),
            ),
          ],
          if (visibleMissingFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Uncertain: ${visibleMissingFields.join(', ')}',
              key: ValueKey('outside-event-uncertain-${event.id}'),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: textMuted,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            event.displaySourceSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (sourceUrl?.isNotEmpty == true && sourceUrl != ticketUrl)
                _LinkButton(
                  buttonKey: ValueKey('outside-event-details-${event.id}'),
                  label: 'Details',
                  url: sourceUrl!,
                ),
              if (ticketUrl?.isNotEmpty == true)
                _LinkButton(
                  buttonKey: ValueKey('outside-event-tickets-${event.id}'),
                  label: 'Tickets',
                  url: ticketUrl!,
                ),
              _EventAction(
                actionKey: ValueKey('outside-event-add-${event.id}'),
                label: added ? 'Added' : 'Add to plan',
                onTap: added ? null : onAdd,
                primary: !added,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(EventSuggestion event) {
    final tags = event.tags.join(' ').toLowerCase();
    if (tags.contains('music')) return Icons.music_note_rounded;
    if (tags.contains('food')) return Icons.restaurant_rounded;
    if (tags.contains('market')) return Icons.storefront_rounded;
    if (tags.contains('outdoor')) return Icons.park_rounded;
    if (tags.contains('art') || tags.contains('film')) {
      return Icons.palette_rounded;
    }
    return Icons.event_rounded;
  }

  static String _dateTimeLabel(DateTime value) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} '
        '${value.day} at $hour:$minute $period';
  }
}

class _EventAction extends StatelessWidget {
  const _EventAction({
    required this.actionKey,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final Key actionKey;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      key: actionKey,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: primary
              ? primaryTerracotta
              : (disabled ? warmBeige : surfaceWhite),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: primary ? primaryTerracotta : borderWarmStrong,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: primary ? Colors.white : textMuted,
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundCream,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderWarm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({
    required this.buttonKey,
    required this.label,
    required this.url,
  });

  final Key buttonKey;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: buttonKey,
      onTap: () => triggerBrowserOpenUrl(url),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: borderWarmStrong),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textMuted,
          ),
        ),
      ),
    );
  }
}

/// Small chip noting whether AI or the deterministic regex fallback
/// organized [event] from its source webpage. Hidden for sources that
/// don't tag an extraction mode (RSS/Atom, mock, ticketing APIs).
class _ExtractionModeChip extends StatelessWidget {
  const _ExtractionModeChip({required this.event});

  final EventSuggestion event;

  @override
  Widget build(BuildContext context) {
    final mode = event.extractionMode;
    if (mode == null) return const SizedBox.shrink();
    final isAi = event.isAiOrganized;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isAi ? const Color(0xFFEEF6F2) : warmBeige,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAi ? Icons.auto_awesome_rounded : Icons.rule_rounded,
            size: 13,
            color: isAi ? accentSage : textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            isAi ? 'AI organized' : 'Auto-detected',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAi ? accentSage : textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      color: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryTerracotta, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
