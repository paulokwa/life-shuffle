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
                      label: Text('Today'),
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
                  _HistoryMode.today => 'No past days yet',
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
              _SummaryCount(label: 'Unchecked', value: summary.unchecked),
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
  });

  final List<_HistoryDay> grouped;

  /// Non-empty only in week/month mode; drives the category breakdown header.
  final List<PlanHistoryEntry> categoryEntries;

  @override
  Widget build(BuildContext context) {
    final showCategory = categoryEntries.isNotEmpty;
    final offset = showCategory ? 1 : 0;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: grouped.length + offset,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (showCategory && index == 0) {
          return _CategoryBreakdown(entries: categoryEntries);
        }
        final day = grouped[index - offset];
        return _HistoryDayCard(date: day.date, entries: day.entries);
      },
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
