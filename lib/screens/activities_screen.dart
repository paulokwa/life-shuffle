import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/activity.dart';
import '../state/app_state.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import '../widgets/category_chip.dart';

class ActivitiesScreen extends StatelessWidget {
  const ActivitiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final activities = state.activities;

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
                  LsCard(
                    color: const Color(0xFFFFF8F5),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryTerracotta.withValues(alpha: 0.12),
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
                  ...activities.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityCard(activity: a),
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return AnimatedOpacity(
      opacity: activity.enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: LsCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
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
                      CategoryChip(category: activity.category),
                      Text(
                        activity.duration,
                        style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => state.setActivityEnabled(
                activity.id,
                enabled: !activity.enabled,
              ),
              child: Icon(
                activity.enabled
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                size: 32,
                color: activity.enabled ? accentSage : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
