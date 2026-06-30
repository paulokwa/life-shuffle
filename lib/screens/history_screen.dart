import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/mock_data.dart' show CheckStatus;
import '../models/plan_history_entry.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/ls_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.appState, this.now});

  final AppState appState;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      state: appState,
      child: _HistoryView(history: appState.planHistory, now: now),
    );
  }
}

enum _HistoryMode { today, week, month }

class _HistoryView extends StatefulWidget {
  const _HistoryView({required this.history, this.now});

  final List<PlanHistoryEntry> history;
  final DateTime? now;

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  late final DateTime _today;
  late final DateTime _currentWeekStart;
  late final DateTime _currentMonth;
  late final Map<DateTime, List<PlanHistoryEntry>> _historyByDate;
  _HistoryMode _mode = _HistoryMode.today;
  late DateTime _selectedWeekStart;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(widget.now ?? DateTime.now());
    _currentWeekStart = _startOfWeek(_today);
    _currentMonth = DateTime(_today.year, _today.month);
    _selectedWeekStart = _currentWeekStart;
    _selectedMonth = _currentMonth;
    _historyByDate = _indexPastEntries(widget.history, _today);
  }

  void _setMode(_HistoryMode mode) {
    setState(() {
      _mode = mode;
      if (mode == _HistoryMode.week) _selectedWeekStart = _currentWeekStart;
      if (mode == _HistoryMode.month) _selectedMonth = _currentMonth;
    });
  }

  void _showPreviousPeriod() {
    setState(() {
      if (_mode == _HistoryMode.week) {
        _selectedWeekStart =
            _selectedWeekStart.subtract(const Duration(days: 7));
      } else if (_mode == _HistoryMode.month) {
        _selectedMonth =
            DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      }
    });
  }

  void _showNextPeriod() {
    if (!_canShowNextPeriod) return;
    setState(() {
      if (_mode == _HistoryMode.week) {
        _selectedWeekStart = _selectedWeekStart.add(const Duration(days: 7));
      } else if (_mode == _HistoryMode.month) {
        _selectedMonth =
            DateTime(_selectedMonth.year, _selectedMonth.month + 1);
      }
    });
  }

  bool get _canShowNextPeriod => switch (_mode) {
        _HistoryMode.today => false,
        _HistoryMode.week => _selectedWeekStart.isBefore(_currentWeekStart),
        _HistoryMode.month => _selectedMonth.isBefore(_currentMonth),
      };

  List<PlanHistoryEntry> get _previousPeriodEntries {
    if (_mode == _HistoryMode.today) return const [];
    if (_mode == _HistoryMode.week) {
      final prevStart = _selectedWeekStart.subtract(const Duration(days: 7));
      final prevEnd = _selectedWeekStart.subtract(const Duration(days: 1));
      return _daysInRange(_historyByDate, prevStart, prevEnd)
          .expand((d) => d.entries)
          .toList();
    }
    final prevMonthStart =
        DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final prevMonthEnd = _selectedMonth.subtract(const Duration(days: 1));
    return _daysInRange(_historyByDate, prevMonthStart, prevMonthEnd)
        .expand((d) => d.entries)
        .toList();
  }

  List<_HistoryDay> get _visibleDays {
    if (_mode == _HistoryMode.today) {
      return _daysFromIndex(_historyByDate);
    }
    final (start, end) = _selectedPeriod;
    return _daysInRange(_historyByDate, start, end);
  }

  (DateTime, DateTime) get _selectedPeriod {
    if (_mode == _HistoryMode.week) {
      return (
        _selectedWeekStart,
        _selectedWeekStart.add(const Duration(days: 6)),
      );
    }
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1)
        .subtract(const Duration(days: 1));
    return (_selectedMonth, end);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _visibleDays;
    final periodEntries = grouped.expand((day) => day.entries).toList();
    final insights = _mode != _HistoryMode.today
        ? _HistoryInsights.fromPeriod(
            periodEntries: periodEntries,
            previousEntries: _previousPeriodEntries,
            allHistory: widget.history,
            mode: _mode,
            today: _today,
          )
        : const <String>[];

    return Scaffold(
      key: const ValueKey('history-screen'),
      backgroundColor: backgroundCream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('history-back'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: textPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'History',
                    style: GoogleFonts.lora(
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'A quiet look back at what was planned.',
                style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<_HistoryMode>(
                  key: const ValueKey('history-mode-control'),
                  segments: const [
                    ButtonSegment(
                      value: _HistoryMode.today,
                      label: Text('Recent'),
                    ),
                    ButtonSegment(
                      value: _HistoryMode.week,
                      label: Text('Week'),
                    ),
                    ButtonSegment(
                      value: _HistoryMode.month,
                      label: Text('Month'),
                    ),
                  ],
                  selected: {_mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) => _setMode(selection.first),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_mode != _HistoryMode.today) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PeriodNavigation(
                  label: _periodLabel,
                  onPrevious: _showPreviousPeriod,
                  onNext: _canShowNextPeriod ? _showNextPeriod : null,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PeriodSummary(entries: periodEntries),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StreakCard(history: widget.history, today: _today),
              ),
              const SizedBox(height: 14),
            ],
            Expanded(
              child: grouped.isEmpty
                  ? _HistoryEmptyState(mode: _mode)
                  : _HistoryList(
                      grouped: grouped,
                      categoryEntries: _mode != _HistoryMode.today
                          ? periodEntries
                          : const [],
                      insights: insights,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String get _periodLabel => _mode == _HistoryMode.week
      ? _weekLabel(_selectedWeekStart)
      : _monthLabel(_selectedMonth);
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({this.mode = _HistoryMode.today});

  final _HistoryMode mode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: LsCard(
          key: const ValueKey('history-empty'),
          color: const Color(0xFFF5FAF7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history_rounded, color: accentSage, size: 28),
              const SizedBox(height: 10),
              Text(
                switch (mode) {
                  _HistoryMode.today => 'No recent days yet',
                  _HistoryMode.week => 'No archived days in this week',
                  _HistoryMode.month => 'No archived days in this month',
                },
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mode == _HistoryMode.today
                    ? 'Days will appear here as your plans build a little history.'
                    : 'You can keep browsing older periods whenever you like.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodNavigation extends StatelessWidget {
  const _PeriodNavigation({
    required this.label,
    required this.onPrevious,
    this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          key: const ValueKey('history-previous-period'),
          tooltip: 'Previous period',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          color: primaryTerracotta,
        ),
        Expanded(
          child: Text(
            label,
            key: const ValueKey('history-period-label'),
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('history-next-period'),
          tooltip: 'Next period',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          color: onNext == null ? textMuted : primaryTerracotta,
        ),
      ],
    );
  }
}

class _PeriodSummary extends StatelessWidget {
  const _PeriodSummary({required this.entries});

  final List<PlanHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final summary = _HistorySummary.fromEntries(entries);
    return LsCard(
      key: const ValueKey('history-period-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Period summary',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '${summary.completionPercent}% complete',
                key: const ValueKey('history-completion-percent'),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: accentSage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryCount(label: 'Planned', value: summary.planned),
              _SummaryCount(label: 'Done', value: summary.done),
              _SummaryCount(label: 'Partly', value: summary.partly),
              _SummaryCount(label: 'Skipped', value: summary.skipped),
              _SummaryCount(
                label: 'Not checked in',
                value: summary.unchecked,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('history-summary-$label-$value'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: warmBeige.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$value $label',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}

class _HistorySummary {
  const _HistorySummary({
    required this.planned,
    required this.done,
    required this.partly,
    required this.skipped,
    required this.unchecked,
  });

  factory _HistorySummary.fromEntries(List<PlanHistoryEntry> entries) {
    var done = 0;
    var partly = 0;
    var skipped = 0;
    var unchecked = 0;
    for (final entry in entries) {
      switch (entry.status) {
        case CheckStatus.done:
          done++;
        case CheckStatus.partly:
          partly++;
        case CheckStatus.skipped:
          skipped++;
        case CheckStatus.none:
          unchecked++;
      }
    }
    return _HistorySummary(
      planned: entries.length,
      done: done,
      partly: partly,
      skipped: skipped,
      unchecked: unchecked,
    );
  }

  final int planned;
  final int done;
  final int partly;
  final int skipped;
  final int unchecked;

  int get completionPercent =>
      planned == 0 ? 0 : (((done + partly * 0.5) / planned) * 100).round();
}

class _HistoryDayCard extends StatelessWidget {
  const _HistoryDayCard({required this.date, required this.entries});

  final DateTime date;
  final List<PlanHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('history-day-${_dateKey(date)}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showHistoryDaySheet(context, date, entries),
      child: LsCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A6A9E88),
              ),
              alignment: Alignment.center,
              child: Text(
                '${date.day}',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: accentSage,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fullDate(date),
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _dailySummary(entries),
                    style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: textMuted),
          ],
        ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.grouped,
    required this.categoryEntries,
    required this.insights,
  });

  final List<_HistoryDay> grouped;

  /// Non-empty only in week/month mode; drives the category breakdown and
  /// insights cards.
  final List<PlanHistoryEntry> categoryEntries;

  /// Pre-computed insight strings for this period; empty list triggers the
  /// "Patterns will appear" placeholder in [_InsightsCard].
  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final showExtras = categoryEntries.isNotEmpty;
    final offset = showExtras ? 1 : 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: grouped.length + offset,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (showExtras && index == 0) {
          // Both extra cards are bundled into a single list item so they are
          // always inflated (this item starts at y=0 and is never lazy-skipped).
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HistoryStatusChart(entries: categoryEntries),
              const SizedBox(height: 10),
              _CategoryBreakdown(entries: categoryEntries),
              const SizedBox(height: 10),
              _InsightsCard(insights: insights),
            ],
          );
        }
        final day = grouped[index - offset];
        return _HistoryDayCard(date: day.date, entries: day.entries);
      },
    );
  }
}

class _HistoryStatusChart extends StatelessWidget {
  const _HistoryStatusChart({required this.entries});

  final List<PlanHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final summary = _HistorySummary.fromEntries(entries);
    final statuses = [
      ('Done', summary.done, accentSage),
      ('Partly', summary.partly, sand),
      ('Skipped', summary.skipped, textMuted),
      ('Unchecked', summary.unchecked, primaryTerracotta),
    ];
    final semanticsLabel = 'Status chart: ${summary.done} done, '
        '${summary.partly} partly, ${summary.skipped} skipped, '
        '${summary.unchecked} unchecked.';

    return Semantics(
      key: const ValueKey('history-status-chart'),
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: LsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  height: 10,
                  child: Row(
                    children: [
                      for (final status in statuses)
                        if (status.$2 > 0)
                          Expanded(
                            key: ValueKey(
                              'history-status-segment-${status.$1}-${status.$2}',
                            ),
                            flex: status.$2,
                            child: ColoredBox(color: status.$3),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 7,
                children: [
                  for (final status in statuses)
                    _StatusLegendItem(
                      label: status.$1,
                      value: status.$2,
                      color: status.$3,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLegendItem extends StatelessWidget {
  const _StatusLegendItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $value',
          key: ValueKey('history-status-$label-$value'),
          style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
        ),
      ],
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.entries});

  final List<PlanHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final stats = _CategoryStat.fromEntries(entries);
    return LsCard(
      key: const ValueKey('history-category-breakdown'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'By category',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _CategoryStatRow(stat: stats[i]),
          ],
        ],
      ),
    );
  }
}

class _CategoryStatRow extends StatelessWidget {
  const _CategoryStatRow({required this.stat});

  final _CategoryStat stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('history-category-${stat.category}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stat.category,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                '${stat.completionPercent}%',
                key: ValueKey('history-category-pct-${stat.category}'),
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: accentSage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _CategoryStatChip(label: 'Planned', value: stat.planned),
              _CategoryStatChip(label: 'Done', value: stat.done),
              _CategoryStatChip(label: 'Partly', value: stat.partly),
              _CategoryStatChip(label: 'Skipped', value: stat.skipped),
              _CategoryStatChip(label: 'Unchecked', value: stat.unchecked),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryStatChip extends StatelessWidget {
  const _CategoryStatChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: warmBeige.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '$value $label',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}

class _CategoryStat {
  const _CategoryStat({
    required this.category,
    required this.planned,
    required this.done,
    required this.partly,
    required this.skipped,
    required this.unchecked,
  });

  final String category;
  final int planned;
  final int done;
  final int partly;
  final int skipped;
  final int unchecked;

  int get completionPercent =>
      planned == 0 ? 0 : (((done + partly * 0.5) / planned) * 100).round();

  static List<_CategoryStat> fromEntries(List<PlanHistoryEntry> entries) {
    final tallies = <String, _CategoryTally>{};
    for (final entry in entries) {
      final t = tallies.putIfAbsent(entry.category, _CategoryTally.new);
      t.planned++;
      switch (entry.status) {
        case CheckStatus.done:
          t.done++;
        case CheckStatus.partly:
          t.partly++;
        case CheckStatus.skipped:
          t.skipped++;
        case CheckStatus.none:
          t.unchecked++;
      }
    }
    return (tallies.entries
        .map(
          (e) => _CategoryStat(
            category: e.key,
            planned: e.value.planned,
            done: e.value.done,
            partly: e.value.partly,
            skipped: e.value.skipped,
            unchecked: e.value.unchecked,
          ),
        )
        .toList()
      ..sort((a, b) => b.planned.compareTo(a.planned)));
  }
}

class _CategoryTally {
  int planned = 0;
  int done = 0;
  int partly = 0;
  int skipped = 0;
  int unchecked = 0;
}

class _StreakSummary {
  const _StreakSummary({
    required this.currentStreak,
    required this.longestStreak,
  });

  final int currentStreak;
  final int longestStreak;

  static _StreakSummary fromEntries(
    List<PlanHistoryEntry> entries,
    DateTime today,
  ) {
    final qualifying = <DateTime>{};
    for (final entry in entries) {
      final date = _dateOnly(entry.date);
      if (date.isAfter(today)) continue;
      if (entry.status == CheckStatus.done ||
          entry.status == CheckStatus.partly) {
        qualifying.add(date);
      }
    }

    // Current streak: walk backwards from today (if qualifying) or from
    // yesterday (today still open). Past days without qualifying entries
    // break the chain.
    var currentStreak = 0;
    final start = qualifying.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var cursor = start;
    while (qualifying.contains(cursor)) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    if (qualifying.isEmpty) {
      return const _StreakSummary(currentStreak: 0, longestStreak: 0);
    }

    // Longest streak: longest consecutive qualifying-date run ever.
    final sorted = qualifying.toList()..sort();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    return _StreakSummary(currentStreak: currentStreak, longestStreak: longest);
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.history, required this.today});

  final List<PlanHistoryEntry> history;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final summary = _StreakSummary.fromEntries(history, today);

    return LsCard(
      key: const ValueKey('history-streak-card'),
      child: summary.longestStreak == 0
          ? Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: textMuted,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'No streaks yet.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: primaryTerracotta,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Current streak',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _streakDaysLabel(summary.currentStreak),
                        key: const ValueKey('history-streak-current'),
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: warmBeige,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Best',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _streakDaysLabel(summary.longestStreak),
                        key: const ValueKey('history-streak-best'),
                        style: GoogleFonts.dmSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
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

String _streakDaysLabel(int days) => days == 1 ? '1 day' : '$days days';

class _HistoryInsights {
  // Minimum planned entries a category must have before it qualifies for the
  // best-completion insight. Prevents "100%" from a single planned item.
  static const int _minCategoryPlanned = 3;

  // Minimum total entries a weekday must have (across all history) before it
  // qualifies for the strongest-weekday insight. Requires at least this many
  // occurrences across at least 3 distinct weekdays before showing anything.
  static const int _minWeekdayEntries = 2;

  static List<String> fromPeriod({
    required List<PlanHistoryEntry> periodEntries,
    required List<PlanHistoryEntry> previousEntries,
    required List<PlanHistoryEntry> allHistory,
    required _HistoryMode mode,
    required DateTime today,
  }) {
    if (periodEntries.isEmpty) return const [];

    final periodLabel = mode == _HistoryMode.week ? 'week' : 'month';
    final prevLabel = mode == _HistoryMode.week ? 'last week' : 'last month';
    final insights = <String>[];

    // 1. Active days: count distinct days with at least one Done or Partly.
    final activeDates = <DateTime>{};
    for (final e in periodEntries) {
      if (e.status == CheckStatus.done || e.status == CheckStatus.partly) {
        activeDates.add(_dateOnly(e.date));
      }
    }
    if (activeDates.isNotEmpty) {
      final n = activeDates.length;
      insights.add(
        'You had completed or partly completed activities on '
        '${n == 1 ? "1 day" : "$n days"} this $periodLabel.',
      );
    }

    // 2. Most planned category — only when the top category has at least 2
    //    planned entries so a single-activity period does not yield noise.
    final counts = <String, int>{};
    for (final e in periodEntries) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    if (counts.isNotEmpty) {
      final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      final n = top.value;
      if (n >= 2) {
        insights.add(
          'Your most planned category was ${top.key} with '
          '${n == 1 ? "1 activity" : "$n activities"}.',
        );
      }
    }

    // 3. Best completion category — only for categories with enough planned
    //    entries to make the percentage meaningful.
    final tallies = <String, _CategoryTally>{};
    for (final e in periodEntries) {
      final t = tallies.putIfAbsent(e.category, _CategoryTally.new);
      t.planned++;
      if (e.status == CheckStatus.done) t.done++;
      if (e.status == CheckStatus.partly) t.partly++;
      if (e.status == CheckStatus.skipped) t.skipped++;
      if (e.status == CheckStatus.none) t.unchecked++;
    }
    final eligible = tallies.entries
        .where((entry) => entry.value.planned >= _minCategoryPlanned)
        .toList();
    if (eligible.isNotEmpty) {
      final best = eligible
          .reduce((a, b) => _tallyPct(a.value) >= _tallyPct(b.value) ? a : b);
      final pct = _tallyPct(best.value);
      if (pct > 0) {
        insights.add(
          'Your most completed category was ${best.key} at $pct%.',
        );
      }
    }

    // 4. Period vs previous period comparison.
    if (previousEntries.isNotEmpty) {
      final currentDone = periodEntries
          .where(
            (e) =>
                e.status == CheckStatus.done || e.status == CheckStatus.partly,
          )
          .length;
      final prevDone = previousEntries
          .where(
            (e) =>
                e.status == CheckStatus.done || e.status == CheckStatus.partly,
          )
          .length;
      final cLabel =
          currentDone == 1 ? '1 activity' : '$currentDone activities';
      if (currentDone == prevDone) {
        insights.add(
          'You completed or partly completed $cLabel this $periodLabel, '
          'the same as $prevLabel.',
        );
      } else {
        insights.add(
          'You completed or partly completed $cLabel this $periodLabel, '
          'compared to $prevDone $prevLabel.',
        );
      }
    }

    // 5. Strongest day of week across global history (past entries only).
    final wdTotal = <int, int>{};
    final wdDonePartly = <int, int>{};
    for (final e in allHistory) {
      final date = _dateOnly(e.date);
      if (date.isAfter(today)) continue;
      final wd = date.weekday;
      wdTotal[wd] = (wdTotal[wd] ?? 0) + 1;
      if (e.status == CheckStatus.done || e.status == CheckStatus.partly) {
        wdDonePartly[wd] = (wdDonePartly[wd] ?? 0) + 1;
      }
    }
    final qualified = wdTotal.entries
        .where((entry) => entry.value >= _minWeekdayEntries)
        .toList();
    if (qualified.length >= 3) {
      final strongest = qualified.reduce((a, b) =>
          (wdDonePartly[a.key] ?? 0) >= (wdDonePartly[b.key] ?? 0) ? a : b);
      if ((wdDonePartly[strongest.key] ?? 0) > 0) {
        const weekdays = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ];
        insights.add(
          'Historically, ${weekdays[strongest.key - 1]} tends to be your '
          'most active day.',
        );
      }
    }

    return insights;
  }

  static int _tallyPct(_CategoryTally t) => t.planned == 0
      ? 0
      : (((t.done + t.partly * 0.5) / t.planned) * 100).round();
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('history-insights-card'),
      child: insights.isEmpty
          ? Row(
              children: [
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: textMuted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Patterns will appear once there is a little more history.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patterns',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < insights.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentSage,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insights[i],
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

Future<void> _showHistoryDaySheet(
  BuildContext context,
  DateTime date,
  List<PlanHistoryEntry> entries,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _HistoryDaySheet(date: date, entries: entries),
  );
}

class _HistoryDaySheet extends StatelessWidget {
  const _HistoryDaySheet({required this.date, required this.entries});

  final DateTime date;
  final List<PlanHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('history-day-sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: backgroundCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _fullDate(date),
                        style: GoogleFonts.lora(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dailySummary(entries),
                        style:
                            GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: textPrimary),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _HistoryEntryCard(entry: entries[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry});

  final PlanHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: ValueKey('history-entry-${entry.occurrenceKey}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              _HistoryChip(label: entry.timeSlot),
              _HistoryChip(
                label: entry.category,
                color: categoryChipText(entry.category),
                background: categoryChipBg(entry.category),
              ),
              _HistoryChip(
                key: ValueKey('history-status-${entry.occurrenceKey}'),
                label: _statusLabel(entry.status),
                color: _statusColor(entry.status),
              ),
              if (entry.removed)
                _HistoryChip(
                  key: ValueKey('history-removed-${entry.occurrenceKey}'),
                  label: 'Removed from plan',
                  color: textMuted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  const _HistoryChip({
    super.key,
    required this.label,
    this.color = textMuted,
    this.background = warmBeige,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

Map<DateTime, List<PlanHistoryEntry>> _indexPastEntries(
  List<PlanHistoryEntry> history,
  DateTime today,
) {
  final byDate = <DateTime, List<PlanHistoryEntry>>{};
  for (final entry in history) {
    final date = _dateOnly(entry.date);
    if (date.isAfter(today)) continue;
    byDate.putIfAbsent(date, () => []).add(entry);
  }

  for (final entries in byDate.values) {
    entries.sort((a, b) => _timeRank(a.timeSlot).compareTo(
          _timeRank(b.timeSlot),
        ));
  }
  return byDate;
}

List<_HistoryDay> _daysFromIndex(
  Map<DateTime, List<PlanHistoryEntry>> byDate,
) {
  final days = byDate.entries
      .map((entry) => _HistoryDay(date: entry.key, entries: entry.value))
      .toList();
  days.sort((a, b) => b.date.compareTo(a.date));
  return days;
}

List<_HistoryDay> _daysInRange(
  Map<DateTime, List<PlanHistoryEntry>> byDate,
  DateTime start,
  DateTime end,
) {
  final days = <_HistoryDay>[];
  for (var date = end;
      !date.isBefore(start);
      date = date.subtract(const Duration(days: 1))) {
    final entries = byDate[date];
    if (entries != null) days.add(_HistoryDay(date: date, entries: entries));
  }
  return days;
}

class _HistoryDay {
  const _HistoryDay({required this.date, required this.entries});

  final DateTime date;
  final List<PlanHistoryEntry> entries;
}

String _dailySummary(List<PlanHistoryEntry> entries) {
  final done =
      entries.where((entry) => entry.status == CheckStatus.done).length;
  final partly =
      entries.where((entry) => entry.status == CheckStatus.partly).length;
  final plannedLabel =
      entries.length == 1 ? '1 planned' : '${entries.length} planned';
  if (done == 0 && partly == 0) {
    return '$plannedLabel, no Done or Partly check-ins';
  }
  return '$plannedLabel, $done done, $partly partly';
}

String _statusLabel(CheckStatus status) => switch (status) {
      CheckStatus.done => 'Done',
      CheckStatus.partly => 'Partly done',
      CheckStatus.skipped => 'Skipped',
      CheckStatus.none => 'Unchecked',
    };

Color _statusColor(CheckStatus status) => switch (status) {
      CheckStatus.done => accentSage,
      CheckStatus.partly => sand,
      CheckStatus.skipped => textMuted,
      CheckStatus.none => primaryTerracotta,
    };

String _fullDate(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

String _weekLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  final startMonth = _monthName(start.month);
  if (start.month == end.month) {
    return 'Week of $startMonth ${start.day}–${end.day}';
  }
  return 'Week of $startMonth ${start.day}–${_monthName(end.month)} ${end.day}';
}

String _monthLabel(DateTime month) =>
    '${_monthName(month.month)} ${month.year}';

String _monthName(int month) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][month - 1];

DateTime _startOfWeek(DateTime date) =>
    date.subtract(Duration(days: date.weekday - DateTime.monday));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

int _timeRank(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
      .firstMatch(value.trim());
  if (match == null) return 24 * 60;
  var hour = int.tryParse(match.group(1) ?? '') ?? 0;
  final minute = int.tryParse(match.group(2) ?? '') ?? 0;
  final period = (match.group(3) ?? '').toUpperCase();
  if (period == 'AM' && hour == 12) hour = 0;
  if (period == 'PM' && hour != 12) hour += 12;
  return hour * 60 + minute;
}
