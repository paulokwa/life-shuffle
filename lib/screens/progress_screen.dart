import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  static const _weeks = [
    _WeekRow(label: 'This week', planned: 5, done: 2, partly: 1),
    _WeekRow(label: 'Last week', planned: 6, done: 5, partly: 0),
    _WeekRow(label: '2 weeks ago', planned: 4, done: 4, partly: 0),
    _WeekRow(label: '3 weeks ago', planned: 7, done: 3, partly: 2),
  ];

  static const _categories = [
    _CategoryStat(label: 'Outside', count: 6, color: accentSage),
    _CategoryStat(label: 'Creative', count: 4, color: primaryTerracotta),
    _CategoryStat(label: 'Couple time', count: 4, color: couplePink),
    _CategoryStat(label: 'Rest', count: 3, color: dustySky),
    _CategoryStat(label: 'Social', count: 2, color: mauve),
  ];

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
                    'Last 30 days',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 20),
                  // Summary tiles
                  Row(
                    children: [
                      _SummaryTile(
                        value: '19',
                        label: 'Activities done',
                        color: accentSage,
                      ),
                      const SizedBox(width: 10),
                      _SummaryTile(
                        value: '76%',
                        label: 'Completion rate',
                        color: primaryTerracotta,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SummaryTile(
                        value: '3',
                        label: 'Weeks planned',
                        color: dustySky,
                      ),
                      const SizedBox(width: 10),
                      _SummaryTile(
                        value: '5',
                        label: 'Categories tried',
                        color: mauve,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'WEEKLY HISTORY',
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
                      children: _weeks
                          .map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _WeekRowWidget(row: w),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                      children: _categories
                          .map(
                            (c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _CategoryBar(stat: c, max: 8),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  LsCard(
                    color: const Color(0xFFF5FAF7),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentSage.withOpacity(0.15),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: accentSage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Best week: 5 of 6 activities done',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Week of 2–8 June',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

class _WeekRow {
  final String label;
  final int planned;
  final int done;
  final int partly;

  const _WeekRow({
    required this.label,
    required this.planned,
    required this.done,
    required this.partly,
  });
}

class _WeekRowWidget extends StatelessWidget {
  const _WeekRowWidget({required this.row});

  final _WeekRow row;

  @override
  Widget build(BuildContext context) {
    final rate = row.planned == 0 ? 0.0 : (row.done + row.partly * 0.5) / row.planned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              row.label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
            Text(
              '${row.done}/${row.planned} done',
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    Positioned.fill(child: Container(color: warmBeige)),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * rate,
                      child: Container(color: accentSage),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CategoryStat {
  final String label;
  final int count;
  final Color color;

  const _CategoryStat({
    required this.label,
    required this.count,
    required this.color,
  });
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.stat, required this.max});

  final _CategoryStat stat;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            stat.label,
            style: GoogleFonts.dmSans(fontSize: 13, color: textPrimary),
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
                        width: constraints.maxWidth * (stat.count / max),
                        child: Container(color: stat.color),
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
          '${stat.count}',
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: stat.color,
          ),
        ),
      ],
    );
  }
}
