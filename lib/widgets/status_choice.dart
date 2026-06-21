import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mock_data.dart' show CheckStatus;
import '../theme/app_colors.dart';

/// A single check-in status pill that fills in when it matches
/// [selectedStatus]. Shared by the Plan day-sheet and the week review screen
/// so both present check-in choices identically.
class StatusChoice extends StatelessWidget {
  const StatusChoice({
    super.key,
    required this.activityId,
    required this.status,
    required this.selectedStatus,
    required this.label,
    required this.selectedColor,
    required this.onTap,
  });

  final String activityId;
  final CheckStatus status;
  final CheckStatus selectedStatus;
  final String label;
  final Color selectedColor;
  final ValueChanged<CheckStatus> onTap;

  @override
  Widget build(BuildContext context) {
    final selected = status == selectedStatus;
    return GestureDetector(
      key: ValueKey('day-sheet-status-$activityId-${status.name}'),
      onTap: () => onTap(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? selectedColor : borderWarmStrong,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : textMuted,
          ),
        ),
      ),
    );
  }
}
