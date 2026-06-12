import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  static const _activities = [
    _ActivityEntry(title: 'Cafe reading', category: 'Creative', duration: '1–2 hrs'),
    _ActivityEntry(title: 'Walk waterfront', category: 'Outside', duration: '45 min'),
    _ActivityEntry(title: 'Cook together', category: 'Couple time', duration: '1 hr'),
    _ActivityEntry(title: 'Yoga at home', category: 'Rest', duration: '30 min'),
    _ActivityEntry(title: 'Farmers market', category: 'Outside', duration: '1 hr'),
    _ActivityEntry(title: 'Board games night', category: 'Social', duration: '2 hrs'),
    _ActivityEntry(
      title: 'Reorganise pantry',
      category: 'At home',
      duration: '1 hr',
      enabled: false,
    ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Activities',
                        style: GoogleFonts.lora(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                          height: 1.2,
                        ),
                      ),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: primaryTerracotta,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Starter library prompt
                  LsCard(
                    color: const Color(0xFFFFF8F5),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryTerracotta.withOpacity(0.12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: primaryTerracotta,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Browse starter activities',
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Pick from a built-in library to get started quickly',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: textMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'YOUR ACTIVITIES',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._activities.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityCard(entry: a),
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

class _ActivityEntry {
  final String title;
  final String category;
  final String duration;
  final bool enabled;

  const _ActivityEntry({
    required this.title,
    required this.category,
    required this.duration,
    this.enabled = true,
  });
}

class _ActivityCard extends StatefulWidget {
  const _ActivityCard({required this.entry});

  final _ActivityEntry entry;

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.entry.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: LsCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      CategoryChip(category: widget.entry.category),
                      Text(
                        widget.entry.duration,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => setState(() => _enabled = !_enabled),
              child: Icon(
                _enabled
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                size: 32,
                color: _enabled ? accentSage : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
