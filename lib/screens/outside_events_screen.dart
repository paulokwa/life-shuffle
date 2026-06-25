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
  Future<OutsideEventDiscoveryResult>? _future;
  final Set<OutsideEventSourceType> _selectedSources = {};
  final Set<String> _selectedTags = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<OutsideEventDiscoveryResult> _load() {
    final state = AppStateScope.of(context);
    final cached = state.cachedOutsideEventDiscoveryResult();
    if (cached.events.isNotEmpty) return Future.value(cached);
    return state.refreshOutsideEventSources();
  }

  void _refresh() {
    setState(() {
      _future = AppStateScope.of(context).refreshOutsideEventSources();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LifeShuffleHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Outside events',
                          style: GoogleFonts.lora(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            color: textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('outside-events-refresh'),
                        onPressed: _refresh,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: primaryTerracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Browse sourced events for the current plan range, then '
                    'add the ones you actually want.',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<OutsideEventDiscoveryResult>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const _LoadingList();
                      }
                      if (snapshot.hasError) {
                        return const _MessageCard(
                          icon: Icons.error_outline_rounded,
                          title: 'Events could not load',
                          body: 'Try refresh. The rest of the planner is '
                              'unchanged.',
                          color: Color(0xFFFFF3EC),
                        );
                      }
                      final result = snapshot.data!;
                      final events = _filteredEvents(result.events);
                      final allTags = _allTags(result.events);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SourceStatusCard(result: result),
                          if (AppStateScope.of(context)
                                  .cachedOutsideEventsFetchedAtMillis !=
                              null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Last fetched: ${_shortTimestamp(AppStateScope.of(context).cachedOutsideEventsFetchedAtMillis!)}',
                              key: const ValueKey(
                                'outside-events-last-fetched',
                              ),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _FilterSection(
                            sources: result.sources,
                            selectedSources: _selectedSources,
                            onToggleSource: _toggleSource,
                            allTags: allTags,
                            selectedTags: _selectedTags,
                            onToggleTag: _toggleTag,
                          ),
                          const SizedBox(height: 14),
                          if (result.warnings.isNotEmpty) ...[
                            _WarningsCard(warnings: result.warnings),
                            const SizedBox(height: 14),
                          ],
                          if (events.isEmpty)
                            const _MessageCard(
                              icon: Icons.search_off_rounded,
                              title: 'No matching outside events',
                              body: 'Try clearing filters or refresh later. '
                                  'No event is added unless you tap Add.',
                              color: surfaceWhite,
                            )
                          else
                            ...events.map(
                              (event) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _EventSuggestionCard(
                                  event: event,
                                  added: _isAdded(event),
                                  onAdd: () => _addEvent(event),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<EventSuggestion> _filteredEvents(List<EventSuggestion> events) {
    return events.where((event) {
      final sourceMatch = _selectedSources.isEmpty ||
          _selectedSources.contains(event.sourceType);
      final tagMatch =
          _selectedTags.isEmpty || event.tags.any(_selectedTags.contains);
      return sourceMatch && tagMatch;
    }).toList();
  }

  List<String> _allTags(List<EventSuggestion> events) {
    final tags = events.expand((event) => event.tags).toSet().toList()..sort();
    return tags;
  }

  void _toggleSource(OutsideEventSourceType sourceType) {
    setState(() {
      if (_selectedSources.contains(sourceType)) {
        _selectedSources.remove(sourceType);
      } else {
        _selectedSources.add(sourceType);
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

class _SourceStatusCard extends StatelessWidget {
  const _SourceStatusCard({required this.result});

  final OutsideEventDiscoveryResult result;

  @override
  Widget build(BuildContext context) {
    final configured =
        result.sources.where((source) => source.configured).length;
    return LsCard(
      color: const Color(0xFFEEF6F2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1A6A9E88),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  size: 18,
                  color: accentSage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${result.events.length} suggestions from $configured '
                  'configured sources',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.aiStatusMessage,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: textMuted,
              height: 1.35,
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
    required this.selectedSources,
    required this.onToggleSource,
    required this.allTags,
    required this.selectedTags,
    required this.onToggleTag,
  });

  final List<OutsideEventSourceConfig> sources;
  final Set<OutsideEventSourceType> selectedSources;
  final ValueChanged<OutsideEventSourceType> onToggleSource;
  final List<String> allTags;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggleTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SOURCES',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sources.map((source) {
            final selected = selectedSources.contains(source.type);
            return _FilterChip(
              label: source.displayName,
              selected: selected,
              muted: !source.canFetch,
              onTap: () => onToggleSource(source.type),
            );
          }).toList(),
        ),
        if (allTags.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'TAGS',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
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
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.muted = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool muted;

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
            color: selected
                ? Colors.white
                : (muted ? textMuted.withValues(alpha: 0.7) : textPrimary),
          ),
        ),
      ),
    );
  }
}

class _WarningsCard extends StatelessWidget {
  const _WarningsCard({required this.warnings});

  final List<OutsideEventSourceWarning> warnings;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      color: const Color(0xFFFFF7E8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Source notes',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(top: 5),
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
                icon: Icons.source_rounded,
                label: event.sourceType.label,
              ),
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
          if (event.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: event.tags.take(5).map((tag) {
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
          if (event.missingFields.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Uncertain: ${event.missingFields.join(', ')}',
              key: ValueKey('outside-event-uncertain-${event.id}'),
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: textMuted,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  event.displaySourceSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (event.sourceUrl?.trim().isNotEmpty == true) ...[
                _LinkButton(
                  buttonKey: ValueKey('outside-event-source-${event.id}'),
                  label: 'Details',
                  url: event.sourceUrl!.trim(),
                ),
                const SizedBox(width: 8),
              ],
              if (event.ticketUrl?.trim().isNotEmpty == true &&
                  event.ticketUrl!.trim() != event.sourceUrl?.trim()) ...[
                _LinkButton(
                  buttonKey: ValueKey('outside-event-tickets-${event.id}'),
                  label: 'Tickets',
                  url: event.ticketUrl!.trim(),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                key: ValueKey('outside-event-add-${event.id}'),
                onTap: added ? null : onAdd,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: added ? warmBeige : primaryTerracotta,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: added ? borderWarmStrong : primaryTerracotta,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    added ? 'Added' : 'Add to plan',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: added ? textMuted : Colors.white,
                    ),
                  ),
                ),
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
