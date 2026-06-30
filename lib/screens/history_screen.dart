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
      child: _HistoryView(now: now),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(now ?? DateTime.now());
    final grouped = _groupPastEntries(
      AppStateScope.of(context).planHistory,
      today,
    );

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
            Expanded(
              child: grouped.isEmpty
                  ? const _HistoryEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      itemCount: grouped.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final day = grouped[index];
                        return _HistoryDayCard(
                          date: day.date,
                          entries: day.entries,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

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
                'No past days yet',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Days will appear here as your plans build a little history.',
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

List<_HistoryDay> _groupPastEntries(
  List<PlanHistoryEntry> history,
  DateTime today,
) {
  final byDate = <DateTime, List<PlanHistoryEntry>>{};
  for (final entry in history) {
    final date = _dateOnly(entry.date);
    if (date.isAfter(today)) continue;
    byDate.putIfAbsent(date, () => []).add(entry);
  }

  final days = byDate.entries.map((entry) {
    entry.value.sort((a, b) => _timeRank(a.timeSlot).compareTo(
          _timeRank(b.timeSlot),
        ));
    return _HistoryDay(date: entry.key, entries: entry.value);
  }).toList();
  days.sort((a, b) => b.date.compareTo(a.date));
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
