import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

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
                    'Plan',
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    'Week of 9 – 15 June',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
                  ),
                  const SizedBox(height: 20),
                  _DayStrip(),
                  const SizedBox(height: 16),
                  _DayBlock(
                    label: 'Monday · 9 June',
                    activities: const [
                      _PlanRow(title: 'Yoga at home', time: '7:00 AM', category: 'Rest'),
                      _PlanRow(title: 'Farmers market', time: '10:00 AM', category: 'Outside', locked: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DayBlock(
                    label: 'Wednesday · 11 June',
                    activities: const [
                      _PlanRow(title: 'Cafe reading', time: '11:00 AM', category: 'Creative'),
                      _PlanRow(title: 'Walk waterfront', time: '6:30 PM', category: 'Outside'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _DayBlock(
                    label: 'Thursday · 12 June',
                    activities: const [
                      _PlanRow(title: 'Cook together', time: '8:00 PM', category: 'Couple time'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryTerracotta,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Regenerate unlocked',
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _OutlineButton(label: 'Export')),
                      const SizedBox(width: 10),
                      Expanded(child: _OutlineButton(label: 'Publish feed')),
                    ],
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

class _DayStrip extends StatelessWidget {
  static const _days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dates = ['9', '10', '11', '12', '13', '14', '15'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final isToday = i == 3;
        return Expanded(
          child: Column(
            children: [
              Text(
                _days[i],
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isToday ? primaryTerracotta : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  _dates[i],
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.label, required this.activities});

  final String label;
  final List<_PlanRow> activities;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...activities
              .map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: row,
                  ))
              .toList(),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.title,
    required this.time,
    required this.category,
    this.locked = false,
  });

  final String title;
  final String time;
  final String category;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    time,
                    style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(width: 8),
                  CategoryChip(category: category),
                ],
              ),
            ],
          ),
        ),
        Icon(
          locked ? Icons.lock_rounded : Icons.lock_open_rounded,
          size: 16,
          color: locked ? textMuted : const Color(0xFFBBB5AC),
        ),
      ],
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderWarmStrong),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}
