import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../models/progress_summary.dart';
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static _WeekStats _compute(List<DayPlan> week) {
    final all = week.expand((d) => d.activities).toList();
    final planned = all.length;
    final done = all.where((a) => a.status == CheckStatus.done).length;
    final partly = all.where((a) => a.status == CheckStatus.partly).length;
    final skipped = all.where((a) => a.status == CheckStatus.skipped).length;
    final rate = planned == 0 ? 0.0 : (done + partly * 0.5) / planned;

    final catCounts = <String, int>{};
    for (final a in all) {
      catCounts[a.category] = (catCounts[a.category] ?? 0) + 1;
    }
    final cats = catCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _WeekStats(
      planned: planned,
      done: done,
      partly: partly,
      skipped: skipped,
      rate: rate,
      categories: cats,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final week = state.weekPlan;
    final stats = _compute(week);
    final past7 = ProgressSummaryCalculator.recent(week, days: 7);
    final past30 = ProgressSummaryCalculator.recent(week, days: 30);
    final hardPast7 = ProgressSummaryCalculator.recentHard(week, days: 7);
    final hardPast30 = ProgressSummaryCalculator.recentHard(week, days: 30);
    final rhythm = ProgressSummaryCalculator.rhythm(week);
    final rateLabel = '${(stats.rate * 100).round()}%';

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
                  Text(
                    'Progress',
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'This week',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 20),
                  _RecentSummarySection(
                    past7: past7,
                    past30: past30,
                  ),
                  const SizedBox(height: 20),
                  if (state.difficultyEnabled) ...[
                    _DifficultySummarySection(
                      past7: hardPast7,
                      past30: hardPast30,
                    ),
                    const SizedBox(height: 20),
                  ],
                  _RhythmSummarySection(rhythm: rhythm),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _SummaryTile(
                        value: '${stats.planned}',
                        label: 'Planned',
                        color: textPrimary,
                      ),
                      const SizedBox(width: 10),
                      _SummaryTile(
                        value: '${stats.done}',
                        label: 'Done',
                        color: accentSage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SummaryTile(
                        value: '${stats.partly}',
                        label: 'Partly done',
                        color: sand,
                      ),
                      const SizedBox(width: 10),
                      _SummaryTile(
                        value: rateLabel,
                        label: 'Completion',
                        color: primaryTerracotta,
                      ),
                    ],
                  ),
                  if (stats.skipped > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _SummaryTile(
                          value: '${stats.skipped}',
                          label: 'Skipped',
                          color: textMuted,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (stats.categories.isNotEmpty) ...[
                    Text(
                      'BY CATEGORY',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LsCard(
                      child: Column(
                        children: stats.categories
                            .map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CategoryBar(
                                  label: e.key,
                                  count: e.value,
                                  max: stats.categories.first.value,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  _StatusCallout(stats: stats),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStats {
  const _WeekStats({
    required this.planned,
    required this.done,
    required this.partly,
    required this.skipped,
    required this.rate,
    required this.categories,
  });

  final int planned;
  final int done;
  final int partly;
  final int skipped;
  final double rate;
  final List<MapEntry<String, int>> categories;

  int get checked => done + partly;
}

class _RecentSummarySection extends StatelessWidget {
  const _RecentSummarySection({
    required this.past7,
    required this.past30,
  });

  final ProgressSummary past7;
  final ProgressSummary past30;

  @override
  Widget build(BuildContext context) {
    if (!past7.hasHistory && !past30.hasHistory) {
      return LsCard(
        key: const ValueKey('progress-recent-empty'),
        color: const Color(0xFFF5FAF7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1A6A9E88),
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 18,
                color: accentSage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No recent history yet',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recent summaries will appear after planned days pass or '
                    'you check in for today.',
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 10),
        _RecentSummaryCard(
          key: const ValueKey('progress-summary-7'),
          title: 'Past 7 days',
          summary: past7,
        ),
        const SizedBox(height: 10),
        _RecentSummaryCard(
          key: const ValueKey('progress-summary-30'),
          title: 'Past 30 days',
          summary: past30,
        ),
      ],
    );
  }
}

class _RecentSummaryCard extends StatelessWidget {
  const _RecentSummaryCard({
    super.key,
    required this.title,
    required this.summary,
  });

  final String title;
  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Text(
                summary.hasHistory
                    ? '${summary.checked} checked in'
                    : 'No items yet',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RecentCount(
                value: summary.planned,
                label: 'Planned',
                color: textPrimary,
              ),
              _RecentCount(
                value: summary.done,
                label: 'Done',
                color: accentSage,
              ),
              _RecentCount(
                value: summary.partly,
                label: 'Partly',
                color: sand,
              ),
              _RecentCount(
                value: summary.skipped,
                label: 'Skipped',
                color: textMuted,
              ),
              _RecentCount(
                value: summary.unchecked,
                label: 'Unchecked',
                color: primaryTerracotta,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentCount extends StatelessWidget {
  const _RecentCount({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('recent-count-$label-$value'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warmBeige.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultySummarySection extends StatelessWidget {
  const _DifficultySummarySection({
    required this.past7,
    required this.past30,
  });

  final DifficultyProgressSummary past7;
  final DifficultyProgressSummary past30;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('progress-difficulty-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIFFICULTY',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 10),
        LsCard(
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
                      color: Color(0xFFFFF3EC),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      size: 17,
                      color: primaryTerracotta,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Higher effort activities',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Difficulty 4-5, spaced gently by the planner.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _DifficultyWindowRow(
                key: const ValueKey('difficulty-summary-7'),
                label: 'Past 7 days',
                summary: past7,
              ),
              const SizedBox(height: 10),
              _DifficultyWindowRow(
                key: const ValueKey('difficulty-summary-30'),
                label: 'Past 30 days',
                summary: past30,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyWindowRow extends StatelessWidget {
  const _DifficultyWindowRow({
    super.key,
    required this.label,
    required this.summary,
  });

  final String label;
  final DifficultyProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ),
            Text(
              summary.hasHardActivities
                  ? '${summary.planned} planned'
                  : 'None planned',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _RecentCount(
              value: summary.planned,
              label: 'Planned',
              color: textPrimary,
            ),
            _RecentCount(
              value: summary.done,
              label: 'Done',
              color: accentSage,
            ),
            _RecentCount(
              value: summary.partly,
              label: 'Partly',
              color: sand,
            ),
            _RecentCount(
              value: summary.skipped,
              label: 'Skipped',
              color: textMuted,
            ),
          ],
        ),
      ],
    );
  }
}

class _RhythmSummarySection extends StatelessWidget {
  const _RhythmSummarySection({required this.rhythm});

  final RhythmProgressSummary rhythm;

  @override
  Widget build(BuildContext context) {
    final hasStreak = rhythm.currentStreakDays > 0;

    return Column(
      key: const ValueKey('progress-rhythm-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT RHYTHM',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 10),
        LsCard(
          key: rhythm.hasAnyHistory
              ? const ValueKey('progress-rhythm-card')
              : const ValueKey('progress-rhythm-empty'),
          color: rhythm.hasAnyHistory ? surfaceWhite : const Color(0xFFF5FAF7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasStreak
                          ? const Color(0x1A6A9E88)
                          : warmBeige.withValues(alpha: 0.7),
                    ),
                    child: Icon(
                      hasStreak ? Icons.repeat_rounded : Icons.history_rounded,
                      size: 17,
                      color: hasStreak ? accentSage : textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rhythm.hasAnyHistory
                              ? 'A gentle pattern'
                              : 'No rhythm yet',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _streakCopy(rhythm.currentStreakDays),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (rhythm.hasAnyHistory) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RecentCount(
                      value: rhythm.currentStreakDays,
                      label: rhythm.currentStreakDays == 1
                          ? 'Streak day'
                          : 'Streak days',
                      color: accentSage,
                    ),
                    _RecentCount(
                      value: rhythm.past7DonePartly,
                      label: 'Past 7',
                      color: primaryTerracotta,
                    ),
                    _RecentCount(
                      value: rhythm.previous7DonePartly,
                      label: 'Previous 7',
                      color: textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _comparisonCopy(rhythm),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _streakCopy(int streakDays) {
    if (streakDays <= 0) {
      return 'A Done or Partly check-in can start a small streak.';
    }
    if (streakDays == 1) {
      return 'Today has at least one Done or Partly check-in.';
    }
    return '$streakDays days in a row have at least one Done or Partly '
        'check-in.';
  }

  static String _comparisonCopy(RhythmProgressSummary rhythm) {
    if (!rhythm.hasComparisonHistory) {
      return 'A 7-day comparison will appear after another week of planned '
          'check-ins.';
    }
    final delta = rhythm.comparisonDelta;
    if (delta > 0) {
      return 'Past 7 days has $delta more Done or Partly check-in'
          '${delta == 1 ? '' : 's'} than the previous 7.';
    }
    if (delta < 0) {
      final quieter = delta.abs();
      return 'Past 7 days has $quieter fewer Done or Partly check-in'
          '${quieter == 1 ? '' : 's'} than the previous 7. That can be useful '
          'to notice.';
    }
    return 'Past 7 days and the previous 7 have the same Done or Partly '
        'count.';
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderWarm, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.label,
    required this.count,
    required this.max,
  });

  final String label;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final fill = max == 0 ? 0.0 : count / max;
    final barColor = categoryChipText(label);
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Positioned.fill(child: Container(color: warmBeige)),
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: constraints.maxWidth * fill,
                        child: Container(color: barColor),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: barColor,
          ),
        ),
      ],
    );
  }
}

class _StatusCallout extends StatelessWidget {
  const _StatusCallout({required this.stats});

  final _WeekStats stats;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color bg;
    final Color iconColor;
    final String title;
    final String body;

    if (stats.planned == 0) {
      icon = Icons.calendar_today_rounded;
      bg = warmBeige;
      iconColor = textMuted;
      title = 'No activities planned yet';
      body = 'Go to the Plan tab and tap Regenerate to build your week.';
    } else if (stats.checked == 0) {
      icon = Icons.touch_app_rounded;
      bg = warmBeige;
      iconColor = textMuted;
      title = 'Nothing checked in yet';
      body = 'Tap a circle on Today to mark how activities went.';
    } else if (stats.rate >= 0.8) {
      icon = Icons.emoji_events_rounded;
      bg = const Color(0xFFF5FAF7);
      iconColor = accentSage;
      title = 'Nice progress';
      body = '${stats.done} done and ${stats.partly} partly done this week.';
    } else {
      icon = Icons.trending_up_rounded;
      bg = const Color(0xFFFFF8F5);
      iconColor = primaryTerracotta;
      title = '${stats.checked} of ${stats.planned} activities checked in';
      body = stats.planned - stats.checked > 0
          ? '${stats.planned - stats.checked} still unchecked this week.'
          : 'All planned items have a check-in.';
    }

    return LsCard(
      color: bg,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                Text(
                  body,
                  style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
