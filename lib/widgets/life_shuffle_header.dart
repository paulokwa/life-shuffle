import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/firestore_sync_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';

class LifeShuffleHeader extends StatelessWidget {
  const LifeShuffleHeader({
    super.key,
    this.calendarName,
    this.profileInitial,
  });

  final String? calendarName;
  final String? profileInitial;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    final state = scope?.notifier;
    final resolvedCalendarName = _nonEmpty(calendarName) ??
        _nonEmpty(state?.calendarTitle) ??
        FirestoreSyncService.defaultCalendarTitle;
    final resolvedProfileInitial = _nonEmpty(profileInitial) ??
        _initialFrom(_nonEmpty(state?.displayName)) ??
        'K';
    final calendars = state?.accessibleCalendars ?? const <CalendarMetadata>[];
    final canSwitch = state != null && calendars.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CalendarPill(
            calendarName: resolvedCalendarName,
            canSwitch: canSwitch,
            onTap: canSwitch
                ? () => _showCalendarSwitcher(context, state, calendars)
                : null,
          ),
          _ProfileCircle(initial: resolvedProfileInitial),
        ],
      ),
    );
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _initialFrom(String? value) {
    if (value == null || value.isEmpty) return null;
    return value.characters.first.toUpperCase();
  }

  static void _showCalendarSwitcher(
    BuildContext context,
    AppState state,
    List<CalendarMetadata> calendars,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch calendar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: calendars
              .map(
                (calendar) => ListTile(
                  key:
                      ValueKey('header-calendar-option-${calendar.calendarId}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(calendar.title),
                  subtitle: Text('${calendar.memberUserIds.length} members'),
                  trailing: calendar.calendarId == state.calendarId
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    state.selectCalendar(calendar.calendarId);
                    Navigator.of(dialogContext).pop();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _CalendarPill extends StatelessWidget {
  const _CalendarPill({
    required this.calendarName,
    required this.canSwitch,
    this.onTap,
  });

  final String calendarName;
  final bool canSwitch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: warmBeige,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              calendarName,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
            if (canSwitch) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileCircle extends StatelessWidget {
  const _ProfileCircle({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: warmBeige,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: primaryTerracotta,
        ),
      ),
    );
  }
}
