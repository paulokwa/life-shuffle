import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/mock_data.dart';
import 'category_chip.dart';
import 'check_in_circle.dart';

class ActivityPlanCard extends StatefulWidget {
  const ActivityPlanCard({super.key, required this.activity});

  final ActivityMock activity;

  @override
  State<ActivityPlanCard> createState() => _ActivityPlanCardState();
}

class _ActivityPlanCardState extends State<ActivityPlanCard> {
  late CheckStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.activity.status;
  }

  void _cycleStatus() {
    setState(() {
      _status = switch (_status) {
        CheckStatus.none => CheckStatus.done,
        CheckStatus.done => CheckStatus.partly,
        CheckStatus.partly => CheckStatus.skipped,
        CheckStatus.skipped => CheckStatus.none,
      };
      widget.activity.status = _status;
    });
  }

  IconData get _icon {
    return switch (widget.activity.category) {
      'Creative' => Icons.menu_book_rounded,
      'Outside' => Icons.waves_rounded,
      'Couple time' => Icons.restaurant_rounded,
      'Social' => Icons.people_rounded,
      'At home' => Icons.home_rounded,
      'Rest' => Icons.self_improvement_rounded,
      _ => Icons.star_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isSkipped = _status == CheckStatus.skipped;
    return AnimatedOpacity(
      opacity: isSkipped ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderWarm, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundCream,
              ),
              alignment: Alignment.center,
              child: Icon(
                _icon,
                size: 16,
                color: categoryIconColor(widget.activity.category),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.activity.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      decoration:
                          isSkipped ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        widget.activity.time,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                      CategoryChip(category: widget.activity.category),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CheckInCircle(status: _status, onTap: _cycleStatus),
          ],
        ),
      ),
    );
  }
}
