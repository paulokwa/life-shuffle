import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/day_plan.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static _WeekStats _compute(List<DayPlan> week) {
    final all = week.expand((d) => d.activities).toList();
    final planned = all.length;
    final done    = all.where((a) => a.status == CheckStatus.done).length;
    final partly  = all.where((a) => a.status == CheckStatus.partly).length;
    final skipped = all.where((a) => a.status == CheckStatus.skipped).length;
    final rate    = planned == 0 ? 0.0 : (done + partly * 0.5) / planned;

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
    // Registering via AppStateScope.of() ensures this screen rebuilds on
    // check-in changes so the completion rate updates in real time.
    final week = AppStateScope.of(context).weekPlan;
    final stats = _compute(week);

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
                  // ─── Summary tiles ─────────────────────────────────────────
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
                        Expanded(child: SizedBox.shrink()),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // ─── Category breakdown ────────────────────────────────────
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
                  // ─── Status callout ────────────────────────────────────────
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

// ─── Data holder ─────────────────────────────────────────────────────────────

class _WeekStats {
  final int planned;
  final int done;
  final int partly;
  final int skipped;
  final double rate;
  final List<MapEntry<String, int>> categories;

  const _WeekStats({
    required this.planned,
    required this.done,
    required this.partly,
    required this.skipped,
    required this.rate,
    required this.categories,
  });

  int get checked => done + partly;
}

// ─── Summary tile ─────────────────────────────────────────────────────────────

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

// ─── Category bar ─────────────────────────────────────────────────────────────

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

// ─── Status callout ───────────────────────────────────────────────────────────

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
      title = 'Great week!';
      body = '${stats.done} done and ${stats.partly} partly done — keep it up.';
    } else {
      icon = Icons.trending_up_rounded;
      bg = const Color(0xFFFFF8F5);
      iconColor = primaryTerracotta;
      title = '${stats.checked} of ${stats.planned} activities checked in';
      body = stats.planned - stats.checked > 0
          ? '${stats.planned - stats.checked} still to go this week.'
          : 'All checked in — great work!';
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
