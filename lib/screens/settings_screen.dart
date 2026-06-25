import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/range_type.dart';
import '../models/sync_message.dart';
import '../models/user_event_source.dart';
import '../services/auth_service.dart';
import '../services/browser_open_url.dart';
import '../services/feed_status_text_service.dart';
import '../services/planner_service.dart' show PlanStyle;
import '../services/text_week_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import 'onboarding_screen.dart';
import 'print_preview_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final user = AuthService.currentUser;
    final signedIn = user != null;
    final displayName = state.displayName?.trim();
    final googleDisplayName = user?.displayName?.trim();
    final email = user?.email?.trim();
    final currentUserId = user?.uid ?? state.userId;
    final accountName = displayName?.isNotEmpty == true
        ? displayName!
        : googleDisplayName?.isNotEmpty == true
            ? googleDisplayName!
            : signedIn
                ? 'Signed in'
                : 'Local-only mode';
    final profileInitial = _profileInitial(accountName, email);
    final ownerLabel = state.calendarOwnerUserId == null
        ? 'Local only'
        : state.calendarOwnerUserId == currentUserId
            ? 'You'
            : _shortId(state.calendarOwnerUserId!);
    final memberLabel = state.calendarMemberDisplayLabels.isEmpty
        ? 'Local only'
        : state.calendarMemberDisplayLabels.join(', ');

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LifeShuffleHeader(
            calendarName: state.calendarTitle,
            profileInitial: profileInitial,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'ACCOUNT'),
                  const SizedBox(height: 10),
                  LsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: warmBeige,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                profileInitial,
                                style: GoogleFonts.dmSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTerracotta,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    accountName,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    signedIn
                                        ? (email?.isNotEmpty == true
                                            ? email!
                                            : 'Google account')
                                        : AuthService.isReady
                                            ? 'Not signed in'
                                            : 'Firebase unavailable; changes stay on this device.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (signedIn) ...[
                          const SizedBox(height: 14),
                          _TextButtonRow(
                            icon: Icons.logout_rounded,
                            label: 'Sign out',
                            onTap: () => AuthService.signOut(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (state.syncMessage != null) ...[
                    const SizedBox(height: 10),
                    _SyncDiagnosticsCard(state: state),
                  ],
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'CALENDAR'),
                  const SizedBox(height: 10),
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        key: const ValueKey('settings-current-calendar-row'),
                        icon: Icons.calendar_today_rounded,
                        label: 'Current calendar',
                        value: state.calendarTitle,
                        hasChevron: true,
                        onTap: () => _showRenameCalendarDialog(
                          context,
                          state,
                        ),
                      ),
                      if (state.canCreateCalendars)
                        _SettingsRow(
                          key: const ValueKey('settings-create-calendar-row'),
                          icon: Icons.add_rounded,
                          label: 'Create calendar',
                          value: '',
                          hasChevron: true,
                          onTap: () => _showCreateCalendarDialog(
                            context,
                            state,
                          ),
                        ),
                      if (state.hasMultipleAccessibleCalendars)
                        _SettingsRow(
                          key: const ValueKey('settings-switch-calendar-row'),
                          icon: Icons.swap_horiz_rounded,
                          label: 'Switch calendar',
                          value:
                              '${state.accessibleCalendars.length} available',
                          hasChevron: true,
                          onTap: () => _showCalendarSwitcherDialog(
                            context,
                            state,
                          ),
                        ),
                      _SettingsRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Owner',
                        value: ownerLabel,
                        hasChevron: false,
                      ),
                      _SettingsRow(
                        icon: Icons.group_outlined,
                        label: 'Members',
                        value: memberLabel,
                        hasChevron: false,
                      ),
                      if (state.canAddCalendarMembers)
                        _SettingsRow(
                          key: const ValueKey('settings-add-member-row'),
                          icon: Icons.person_add_alt_1_rounded,
                          label: 'Add member',
                          value: '',
                          hasChevron: true,
                          onTap: () => _showAddMemberDialog(
                            context,
                            state,
                          ),
                        ),
                      if (state.canLeaveCurrentCalendar)
                        _SettingsRow(
                          key: const ValueKey('settings-leave-calendar-row'),
                          icon: Icons.logout_rounded,
                          label: 'Leave calendar',
                          value: '',
                          hasChevron: true,
                          onTap: () => _showLeaveCalendarDialog(
                            context,
                            state,
                          ),
                        ),
                      if (state.canDeleteCurrentCalendar)
                        _SettingsRow(
                          key: const ValueKey('settings-delete-calendar-row'),
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete calendar',
                          value: '',
                          hasChevron: true,
                          color: Theme.of(context).colorScheme.error,
                          onTap: () => _showDeleteCalendarDialog(
                            context,
                            state,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LsCard(
                    color: warmBeige,
                    child: Text(
                      state.canAddCalendarMembers
                          ? 'Members can view and edit this calendar. Add Laura after she has signed in once.'
                          : 'Members can view and edit calendars they have access to.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        height: 1.35,
                        color: textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const _SectionLabel(label: 'PLANNING'),
                  const SizedBox(height: 10),
                  _PlanStyleCard(state: state),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'ACTIVITY DEFAULTS'),
                  const SizedBox(height: 10),
                  _ActivityDefaultsCard(state: state),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'CATEGORIES'),
                  const SizedBox(height: 10),
                  LsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage the categories used to organise your activities.',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            'Creative',
                            'Outside',
                            'Couple time',
                            'Rest',
                            'Social',
                            'At home',
                          ].map((c) => _EditableChip(label: c)).toList(),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: primaryTerracotta,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Add category',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: primaryTerracotta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'OUTSIDE EVENT SOURCES'),
                  const SizedBox(height: 10),
                  _OutsideEventSourcesCard(state: state),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'PUBLISHING'),
                  const SizedBox(height: 10),
                  _PublishingCard(state: state),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'EXPORT / PRINT'),
                  const SizedBox(height: 10),
                  _ExportPrintCard(state: state),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'PRIVACY / HELP'),
                  const SizedBox(height: 10),
                  const _PrivacyHelpCard(),
                  const SizedBox(height: 16),
                  const _SectionLabel(label: 'ABOUT'),
                  const SizedBox(height: 10),
                  const _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Version',
                        value: '1.0.0',
                        hasChevron: false,
                      ),
                      _SettingsRow(
                        icon: Icons.favorite_border_rounded,
                        label: 'Made for Kwame and Laura',
                        value: '',
                        hasChevron: false,
                      ),
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

  static String _profileInitial(String? displayName, String? email) {
    final source = displayName?.isNotEmpty == true ? displayName! : email;
    if (source == null || source.isEmpty) return 'K';
    return source.characters.first.toUpperCase();
  }

  static String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}...';
  }
}

class _ExportPrintCard extends StatelessWidget {
  const _ExportPrintCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('settings-export-print-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: warmBeige,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.ios_share_rounded,
                  size: 18,
                  color: primaryTerracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _exportHeading(state.viewMode),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_exportSummary(state.viewMode)} Private notes are '
                      'not included.',
                      key: const ValueKey('settings-export-print-summary'),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        height: 1.35,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PublishingActionButton(
                key: const ValueKey('settings-copy-week-text-export'),
                icon: Icons.copy_rounded,
                label: 'Copy text',
                onTap: () => _copyWeekTextExport(context, state),
              ),
              _PublishingActionButton(
                key: const ValueKey('settings-open-print-view'),
                icon: Icons.print_rounded,
                label: 'Open print view',
                onTap: () => _openPrintPreview(context, state),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: borderWarm),
          const SizedBox(height: 12),
          Text(
            'What to include',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: textMuted,
            ),
          ),
          Text(
            'Activity title and the day/date always show.',
            style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
          ),
          _OutputDetailToggleRow(
            toggleKey: const ValueKey('settings-export-toggle-time'),
            label: 'Time',
            value: state.exportPrintOptions.showTime,
            onChanged: (value) => state.setExportPrintOptions(
              state.exportPrintOptions.copyWith(showTime: value),
            ),
          ),
          _OutputDetailToggleRow(
            toggleKey: const ValueKey('settings-export-toggle-duration'),
            label: 'Duration',
            value: state.exportPrintOptions.showDuration,
            onChanged: (value) => state.setExportPrintOptions(
              state.exportPrintOptions.copyWith(showDuration: value),
            ),
          ),
          _OutputDetailToggleRow(
            toggleKey: const ValueKey('settings-export-toggle-category'),
            label: 'Category',
            value: state.exportPrintOptions.showCategory,
            onChanged: (value) => state.setExportPrintOptions(
              state.exportPrintOptions.copyWith(showCategory: value),
            ),
          ),
          _OutputDetailToggleRow(
            toggleKey: const ValueKey('settings-export-toggle-checkin'),
            label: 'Check-in status',
            value: state.exportPrintOptions.showCheckInStatus,
            onChanged: (value) => state.setExportPrintOptions(
              state.exportPrintOptions.copyWith(showCheckInStatus: value),
            ),
          ),
          _OutputDetailToggleRow(
            toggleKey: const ValueKey('settings-export-toggle-locked'),
            label: 'Locked status',
            value: state.exportPrintOptions.showLockedStatus,
            onChanged: (value) => state.setExportPrintOptions(
              state.exportPrintOptions.copyWith(showLockedStatus: value),
            ),
          ),
          _OutputDetailToggleRow(
            toggleKey: const ValueKey('settings-export-toggle-outside-event'),
            label: 'Outside event details',
            value: state.exportPrintOptions.showOutsideEventDetails,
            onChanged: (value) => state.setExportPrintOptions(
              state.exportPrintOptions.copyWith(
                showOutsideEventDetails: value,
              ),
            ),
          ),
          if (state.difficultyEnabled ||
              state.energyEnabled ||
              state.socialEnabled)
            _OutputDetailToggleRow(
              toggleKey: const ValueKey('settings-export-toggle-dimensions'),
              label: 'Enabled planning dimensions',
              value: state.exportPrintOptions.showEnabledDimensions,
              onChanged: (value) => state.setExportPrintOptions(
                state.exportPrintOptions.copyWith(
                  showEnabledDimensions: value,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OutputDetailToggleRow extends StatelessWidget {
  const _OutputDetailToggleRow({
    required this.toggleKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key toggleKey;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
          Switch.adaptive(
            key: toggleKey,
            value: value,
            activeThumbColor: primaryTerracotta,
            activeTrackColor: primaryTerracotta.withValues(alpha: 0.32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Heading for [_ExportPrintCard], by [AppState.viewMode].
String _exportHeading(RangeType mode) => switch (mode) {
      RangeType.week => 'Export / print this week',
      RangeType.twoWeek => 'Export / print this 2-week range',
      RangeType.month => 'Export / print this month',
    };

/// One-line summary of what Copy text/print actually export for the
/// current [AppState.viewMode], so switching views never surprises the
/// user about what they're about to copy or print.
String _exportSummary(RangeType mode) => switch (mode) {
      RangeType.week => 'Exports the visible week.',
      RangeType.twoWeek => 'Copy text exports the generated 2-week range; '
          'print exports the visible week.',
      RangeType.month => 'Exports the generated month range.',
    };

String _exportTextCopiedMessage(RangeType mode) => switch (mode) {
      RangeType.week => 'Week text copied',
      RangeType.twoWeek => '2-week text copied',
      RangeType.month => 'Month text copied',
    };

void _copyWeekTextExport(BuildContext context, AppState state) {
  final exportDays = state.exportDays;
  if (exportDays == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No generated month range yet. Go to Plan, switch to Month, and '
          'tap Generate, then come back here to copy.',
        ),
      ),
    );
    return;
  }

  final text = TextWeekExportService.generate(
    calendarTitle: state.calendarTitle,
    plan: exportDays,
    rangeType: state.viewMode,
    options: state.exportPrintOptions,
    difficultyEnabled: state.difficultyEnabled,
    energyEnabled: state.energyEnabled,
    socialEnabled: state.socialEnabled,
    manualPlanItemsById: {
      for (final item in state.manualPlanItems) item.id: item,
    },
  );
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(_exportTextCopiedMessage(state.viewMode))),
  );
}

void _openPrintPreview(BuildContext context, AppState state) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PrintPreviewScreen(appState: state)),
  );
}

Future<void> _showRenameCalendarDialog(
  BuildContext context,
  AppState state,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _RenameCalendarDialog(
        state: state,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );

Future<void> _showAddMemberDialog(
  BuildContext context,
  AppState state,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddMemberDialog(
        state: state,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );

Future<void> _showCreateCalendarDialog(
  BuildContext context,
  AppState state,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CreateCalendarDialog(
        state: state,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );

Future<void> _showLeaveCalendarDialog(
  BuildContext context,
  AppState state,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _LeaveCalendarDialog(
        state: state,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );

Future<void> _showDeleteCalendarDialog(
  BuildContext context,
  AppState state,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _DeleteCalendarDialog(
        state: state,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );

Future<void> _showCalendarSwitcherDialog(
  BuildContext context,
  AppState state,
) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _CalendarSwitcherDialog(
        state: state,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );

Future<void> _showOutsideSourceDialog(
  BuildContext context,
  AppState state, {
  UserEventSource? source,
}) async {
  final nameController = TextEditingController(text: source?.displayName ?? '');
  final urlController = TextEditingController(text: source?.url ?? '');
  var kind = source?.kind ?? UserEventSourceKind.autoDetect;
  String? errorText;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(source == null ? 'Add event source' : 'Edit source'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      hintText: 'Central Library events',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: 'Source URL',
                      hintText: 'https://example.com/events',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserEventSourceKind>(
                    value: kind,
                    decoration: const InputDecoration(labelText: 'Source type'),
                    items: UserEventSourceKind.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => kind = value);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final url = urlController.text.trim();
                  final uri = Uri.tryParse(url);
                  if (uri == null ||
                      !uri.hasScheme ||
                      !(uri.scheme == 'http' || uri.scheme == 'https') ||
                      uri.host.trim().isEmpty) {
                    setDialogState(() {
                      errorText = 'Use a public http or https URL.';
                    });
                    return;
                  }
                  if (source == null) {
                    state.addOutsideEventSource(
                      displayName: nameController.text,
                      url: url,
                      kind: kind,
                    );
                  } else {
                    state.updateOutsideEventSource(
                      source.copyWith(
                        displayName: nameController.text.trim().isEmpty
                            ? uri.host
                            : nameController.text.trim(),
                        url: url,
                        kind: kind,
                        clearLastError: true,
                      ),
                    );
                  }
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  nameController.dispose();
  urlController.dispose();
}

Future<void> _confirmDeleteOutsideSource(
  BuildContext context,
  AppState state,
  UserEventSource source,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete source?'),
        content: Text(
          'Delete ${source.displayName}? Cached suggestions from this source '
          'will be removed from Outside Events, but items already added to '
          'your plan stay there.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed == true) {
    state.deleteOutsideEventSource(source.id);
  }
}

class _RenameCalendarDialog extends StatefulWidget {
  const _RenameCalendarDialog({
    required this.state,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onClose;

  @override
  State<_RenameCalendarDialog> createState() => _RenameCalendarDialogState();
}

class _RenameCalendarDialogState extends State<_RenameCalendarDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.calendarTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final renamed = widget.state.renameCalendarTitle(_controller.text);
    if (!renamed) {
      setState(() {
        _errorText = 'Enter a calendar name.';
      });
      return;
    }
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename calendar'),
      content: TextField(
        key: const ValueKey('rename-calendar-text-field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Calendar name',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText == null) return;
          setState(() {
            _errorText = null;
          });
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: widget.onClose,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('rename-calendar-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CreateCalendarDialog extends StatefulWidget {
  const _CreateCalendarDialog({
    required this.state,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onClose;

  @override
  State<_CreateCalendarDialog> createState() => _CreateCalendarDialogState();
}

class _CreateCalendarDialogState extends State<_CreateCalendarDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final result = await widget.state.createCalendar(_controller.text);
    if (!mounted) return;
    if (result.succeeded) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.status)),
      );
      return;
    }
    setState(() {
      _saving = false;
      _errorText = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create calendar'),
      content: TextField(
        key: const ValueKey('create-calendar-text-field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Calendar name',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText == null) return;
          setState(() {
            _errorText = null;
          });
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : widget.onClose,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('create-calendar-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({
    required this.state,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onClose;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final result = await widget.state.addMemberByEmail(_controller.text);
    if (!mounted) return;
    if (result.succeeded) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.status)),
      );
      return;
    }
    setState(() {
      _saving = false;
      _errorText = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member'),
      content: TextField(
        key: const ValueKey('add-member-email-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Email address',
          errorText: _errorText,
        ),
        onChanged: (_) {
          if (_errorText == null) return;
          setState(() {
            _errorText = null;
          });
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : widget.onClose,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('add-member-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Adding...' : 'Add'),
        ),
      ],
    );
  }
}

class _LeaveCalendarDialog extends StatefulWidget {
  const _LeaveCalendarDialog({
    required this.state,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onClose;

  @override
  State<_LeaveCalendarDialog> createState() => _LeaveCalendarDialogState();
}

class _LeaveCalendarDialogState extends State<_LeaveCalendarDialog> {
  String? _errorText;
  bool _leaving = false;

  Future<void> _leave() async {
    if (_leaving) return;
    setState(() {
      _leaving = true;
      _errorText = null;
    });
    final result = await widget.state.leaveCurrentCalendar();
    if (!mounted) return;
    if (result.succeeded) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.status)),
      );
      return;
    }
    setState(() {
      _leaving = false;
      _errorText = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Leave this calendar?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "You won't see or edit this calendar anymore. Other members can "
            'still use it.',
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _leaving ? null : widget.onClose,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('leave-calendar-confirm'),
          onPressed: _leaving ? null : _leave,
          child: Text(_leaving ? 'Leaving...' : 'Leave'),
        ),
      ],
    );
  }
}

class _DeleteCalendarDialog extends StatefulWidget {
  const _DeleteCalendarDialog({
    required this.state,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onClose;

  @override
  State<_DeleteCalendarDialog> createState() => _DeleteCalendarDialogState();
}

class _DeleteCalendarDialogState extends State<_DeleteCalendarDialog> {
  late final TextEditingController _controller;
  String? _errorText;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matchesCalendarName =>
      _controller.text == widget.state.calendarTitle;

  Future<void> _delete() async {
    if (_deleting || !_matchesCalendarName) return;
    setState(() {
      _deleting = true;
      _errorText = null;
    });
    final result = await widget.state.deleteCurrentCalendar();
    if (!mounted) return;
    if (result.succeeded) {
      widget.onClose();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.status)),
      );
      return;
    }
    setState(() {
      _deleting = false;
      _errorText = result.status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('Delete this calendar?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This deletes it for everyone and turns off its calendar feed.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('delete-calendar-name-field'),
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Type the calendar name',
              helperText: widget.state.calendarTitle,
              errorText: _errorText,
            ),
            onChanged: (_) => setState(() {
              _errorText = null;
            }),
            onSubmitted: (_) => _delete(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : widget.onClose,
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('delete-calendar-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: errorColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _deleting || !_matchesCalendarName ? null : _delete,
          child: Text(_deleting ? 'Deleting...' : 'Delete'),
        ),
      ],
    );
  }
}

class _CalendarSwitcherDialog extends StatelessWidget {
  const _CalendarSwitcherDialog({
    required this.state,
    required this.onClose,
  });

  final AppState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final calendars = state.accessibleCalendars;
    return AlertDialog(
      title: const Text('Switch calendar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: calendars
            .map(
              (calendar) => ListTile(
                key:
                    ValueKey('settings-calendar-option-${calendar.calendarId}'),
                contentPadding: EdgeInsets.zero,
                title: Text(calendar.title),
                subtitle: Text('${calendar.memberUserIds.length} members'),
                trailing: calendar.calendarId == state.calendarId
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () {
                  state.selectCalendar(calendar.calendarId);
                  onClose();
                },
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SyncDiagnosticsCard extends StatelessWidget {
  const _SyncDiagnosticsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final message = state.syncMessage;
    if (message == null) return const SizedBox.shrink();
    final attemptedAt = state.lastSyncAttemptAtMillis;
    final accent = switch (message.severity) {
      SyncMessageSeverity.error => primaryTerracotta,
      SyncMessageSeverity.warning => primaryTerracotta,
      SyncMessageSeverity.info => accentSage,
    };
    return LsCard(
      key: const ValueKey('settings-sync-diagnostics-card'),
      color: const Color(0xFFFAF0EC),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              message.severity == SyncMessageSeverity.info
                  ? Icons.info_outline_rounded
                  : Icons.sync_problem_rounded,
              size: 17,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.body,
                  key: const ValueKey('settings-sync-error-message'),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  attemptedAt == null
                      ? 'No sync attempt timestamp yet.'
                      : 'Last attempt: $attemptedAt',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    height: 1.3,
                    color: textMuted,
                  ),
                ),
                if (message.actionLabel != null) ...[
                  const SizedBox(height: 8),
                  _PublishingActionButton(
                    key: const ValueKey('settings-sync-retry'),
                    icon: Icons.refresh_rounded,
                    label: message.actionLabel!,
                    onTap: () => unawaited(state.syncWithFirestore()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishingCard extends StatelessWidget {
  const _PublishingCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('settings-publishing-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: warmBeige,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.rss_feed_rounded,
                  size: 18,
                  color: primaryTerracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar feed',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      state.feedEnabled ? 'Feed is live' : 'Not enabled yet',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: state.feedEnabled ? accentSage : textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch.adaptive(
                key: const ValueKey('settings-feed-switch'),
                value: state.feedEnabled,
                activeThumbColor: primaryTerracotta,
                activeTrackColor: primaryTerracotta.withValues(alpha: 0.32),
                onChanged: state.setFeedEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.feedEnabled
                ? 'Your calendar feed is live. Copy the link below into Apple Calendar, Google Calendar, or Outlook to subscribe.'
                : 'Turn this on to create a private link you can subscribe to from Apple Calendar, Google Calendar, or Outlook.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.35,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _FeedLinkDisplay(
            feedEnabled: state.feedEnabled,
            feedToken: state.feedToken,
          ),
          const SizedBox(height: 8),
          Text(
            FeedStatusTextService.lastUpdatedLabel(
              state.cachedIcsUpdatedAtMillis,
            ),
            key: const ValueKey('settings-feed-last-updated'),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          if (state.feedEnabled) ...[
            const SizedBox(height: 8),
            Text(
              'Google Calendar may take a while to show changes from a '
              "subscribed feed. Refreshing here updates Life Shuffle's "
              'feed, but Google decides when to fetch it.',
              key: const ValueKey('settings-feed-google-delay-note'),
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.35,
                color: textMuted,
              ),
            ),
          ],
          if (state.feedToken != null) ...[
            const SizedBox(height: 10),
            _TokenPreview(tokenPreview: state.feedTokenPreview),
          ],
          const SizedBox(height: 12),
          Text(
            'The feed is read-only. Anyone with the link may be able to view it, and outside calendar apps may take a while to refresh after changes.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              height: 1.35,
              color: textMuted,
            ),
          ),
          if (state.feedToken != null) ...[
            if (state.feedEnabled) ...[
              const SizedBox(height: 14),
              const _PublishingGroupLabel(label: 'FEED ACTIONS'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PublishingActionButton(
                    key: const ValueKey('settings-copy-feed-link'),
                    icon: Icons.copy_rounded,
                    label: 'Copy link',
                    onTap: () => _copyFeedLink(context, state.feedToken!),
                  ),
                  _PublishingActionButton(
                    key: const ValueKey('settings-refresh-feed-now'),
                    icon: Icons.sync_rounded,
                    label: 'Refresh feed',
                    onTap: () => unawaited(_refreshFeedNow(context, state)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _PublishingGroupLabel(label: 'ADVANCED DIAGNOSTICS'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PublishingActionButton(
                    key: const ValueKey('settings-download-raw-ics'),
                    icon: Icons.download_rounded,
                    label: 'Download raw ICS',
                    onTap: () => _downloadRawIcs(context, state.feedToken!),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Download raw ICS is only for checking whether Life '
                "Shuffle's feed has updated before Google Calendar "
                'refreshes.',
                key: const ValueKey('settings-download-raw-ics-note'),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  height: 1.35,
                  color: textMuted,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const _PublishingGroupLabel(label: 'TOKEN'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (state.feedEnabled)
                  _PublishingActionButton(
                    key: const ValueKey('settings-regenerate-feed-token'),
                    icon: Icons.refresh_rounded,
                    label: 'Regenerate token',
                    onTap: state.regenerateFeedToken,
                  ),
                _PublishingActionButton(
                  key: const ValueKey('settings-revoke-feed-token'),
                  icon: Icons.link_off_rounded,
                  label: 'Revoke token',
                  onTap: state.revokeFeedToken,
                  quiet: true,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OutsideEventSourcesCard extends StatelessWidget {
  const _OutsideEventSourcesCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sources = state.outsideEventSources;
    return LsCard(
      key: const ValueKey('settings-outside-event-sources-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: warmBeige,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.travel_explore_rounded,
                  size: 18,
                  color: primaryTerracotta,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outside event sources',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sources.isEmpty
                          ? 'No user sources yet'
                          : '${sources.length} saved source${sources.length == 1 ? '' : 's'}',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Add public event pages or RSS/Atom feeds. Results are cached on '
            'this device and suggestions stay separate from Activities.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.35,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PublishingActionButton(
                key: const ValueKey('settings-add-outside-event-source'),
                icon: Icons.add_link_rounded,
                label: 'Add source',
                onTap: () => _showOutsideSourceDialog(context, state),
              ),
              _PublishingActionButton(
                key: const ValueKey('settings-refresh-outside-event-sources'),
                icon: Icons.sync_rounded,
                label: 'Fetch latest events',
                onTap: () => unawaited(_refreshOutsideSources(context, state)),
              ),
            ],
          ),
          if (state.cachedOutsideEventsFetchedAtMillis != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last fetched: ${_formatLocalTimestamp(state.cachedOutsideEventsFetchedAtMillis!)}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textMuted,
              ),
            ),
          ],
          if (sources.isEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: warmBeige,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Start with a venue, library, city events page, or a feed URL. '
                'Private network and localhost URLs are blocked by the fetcher.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  height: 1.35,
                  color: textMuted,
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            const Divider(height: 1, thickness: 1, color: borderWarm),
            ...sources.map((source) {
              return _OutsideEventSourceRow(
                source: source,
                onToggle: (enabled) =>
                    state.setOutsideEventSourceEnabled(source.id, enabled),
                onEdit: () => _showOutsideSourceDialog(
                  context,
                  state,
                  source: source,
                ),
                onDelete: () => _confirmDeleteOutsideSource(
                  context,
                  state,
                  source,
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshOutsideSources(
    BuildContext context,
    AppState state,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await state.refreshOutsideEventSources();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Fetched ${result.events.length} outside event suggestion${result.events.length == 1 ? '' : 's'}.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _OutsideEventSourceRow extends StatelessWidget {
  const _OutsideEventSourceRow({
    required this.source,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final UserEventSource source;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: source.enabled
                              ? const Color(0xFFEEF6F2)
                              : warmBeige,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          source.kind.label,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: source.enabled ? accentSage : textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _SourceHealthPill(status: source.healthStatus),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    source.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _sourceHealthDetailLine(source),
                    style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                  ),
                  if (source.lastError?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      source.lastError!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sand,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: source.enabled,
            activeThumbColor: primaryTerracotta,
            activeTrackColor: primaryTerracotta.withValues(alpha: 0.32),
            onChanged: onToggle,
          ),
          IconButton(
            tooltip: 'Delete source',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: textMuted),
          ),
        ],
      ),
    );
  }
}

/// Last-attempt/last-success/events-found summary line for a source's
/// health (Settings > Outside event sources). See [UserEventSource.healthStatus]
/// for the status pill shown alongside this.
String _sourceHealthDetailLine(UserEventSource source) {
  final attempted = source.lastFetchedAtMillis;
  if (attempted == null) return 'Not checked yet.';
  final parts = <String>[
    'Last attempt: ${_formatLocalTimestamp(attempted)}',
  ];
  final success = source.lastSuccessAtMillis;
  if (success != null) {
    parts.add('Last success: ${_formatLocalTimestamp(success)}');
  }
  final count = source.lastEventCount;
  if (count != null) {
    parts.add('$count event${count == 1 ? '' : 's'} found');
  }
  return parts.join(' · ');
}

class _SourceHealthPill extends StatelessWidget {
  const _SourceHealthPill({required this.status});

  final SourceHealthStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      SourceHealthStatus.unknown => (warmBeige, textMuted),
      SourceHealthStatus.healthy => (const Color(0xFFEEF6F2), accentSage),
      SourceHealthStatus.warning => (const Color(0xFFFFF7E8), sand),
      SourceHealthStatus.failed => (const Color(0xFFFAF0EC), primaryTerracotta),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// Builds the public, token-gated feed URL served by
/// `netlify/functions/calendar-feed.js`. Uses [Uri.base] so the link is
/// correct on any deploy domain (localhost, Netlify preview, production).
/// [Uri.origin] throws outside http/https (e.g. the file: scheme `flutter
/// test` runs under), so non-web/test contexts fall back to a relative path.
String _buildCalendarFeedUrl(String token) {
  final base = Uri.base;
  final origin =
      (base.scheme == 'http' || base.scheme == 'https') ? base.origin : '';
  return '$origin/.netlify/functions/calendar-feed?token=$token';
}

String _formatLocalTimestamp(int millis) {
  final value = DateTime.fromMillisecondsSinceEpoch(millis);
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.year}-$month-$day $hour:$minute $period';
}

void _copyFeedLink(BuildContext context, String token) {
  Clipboard.setData(ClipboardData(text: _buildCalendarFeedUrl(token)));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Feed link copied')),
  );
}

/// Opens the raw feed URL (a downloadable .ics file, not a readable
/// calendar preview) in a new tab on web so the user can check directly
/// whether Life Shuffle's side already has the current plan (vs. Google
/// Calendar simply taking a while to re-fetch it). Falls back to copying
/// the link on platforms with no browser tab to open (mobile, `flutter
/// test`'s VM target) - the fallback message deliberately avoids saying
/// anything "opened" since nothing did.
void _downloadRawIcs(BuildContext context, String token) {
  final url = _buildCalendarFeedUrl(token);
  if (triggerBrowserOpenUrl(url)) return;
  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Couldn't open the raw feed. Link copied instead."),
    ),
  );
}

/// Awaits the real outcome before reporting anything, so "Feed refreshed"
/// is never shown while the Firestore save backing the public feed is
/// still in flight or has failed - see [AppState.refreshPublishedFeedNow].
Future<void> _refreshFeedNow(BuildContext context, AppState state) async {
  final result = await state.refreshPublishedFeedNow();
  if (!context.mounted) return;
  final message = switch (result) {
    FeedRefreshResult.unavailable => 'Turn on the feed to refresh it',
    FeedRefreshResult.success => 'Feed refreshed',
    FeedRefreshResult.syncFailed =>
      "Feed updated on this device, but couldn't sync to the published "
          'feed. Try again.',
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class _FeedLinkDisplay extends StatelessWidget {
  const _FeedLinkDisplay({required this.feedEnabled, required this.feedToken});

  final bool feedEnabled;
  final String? feedToken;

  @override
  Widget build(BuildContext context) {
    final token = feedToken;
    final url =
        feedEnabled && token != null ? _buildCalendarFeedUrl(token) : null;

    return Container(
      key: const ValueKey('settings-feed-link-display'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: warmBeige,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        url ??
            'No feed link exists yet. Turning this on creates a private link you can subscribe to from Apple Calendar, Google Calendar, or Outlook.',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          height: 1.35,
          fontWeight: url != null ? FontWeight.w600 : FontWeight.normal,
          color: url != null ? textPrimary : textMuted,
        ),
      ),
    );
  }
}

class _TokenPreview extends StatelessWidget {
  const _TokenPreview({required this.tokenPreview});

  final String tokenPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('settings-feed-token-preview'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Private token: $tokenPreview',
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: accentSage,
        ),
      ),
    );
  }
}

/// Small sub-heading inside the publishing card that separates feed
/// actions, diagnostics, and token/security actions into distinct groups
/// instead of one long row of equal-looking buttons. Deliberately quieter
/// than [_SectionLabel] (smaller, no letter-spacing) since it labels a
/// group within a card, not a top-level Settings section.
class _PublishingGroupLabel extends StatelessWidget {
  const _PublishingGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: textMuted,
      ),
    );
  }
}

class _PublishingActionButton extends StatelessWidget {
  const _PublishingActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.quiet = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final foreground = quiet ? textMuted : primaryTerracotta;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: quiet ? warmBeige : const Color(0xFFFAF0EC),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 2,
          children: [
            Icon(icon, size: 16, color: foreground),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyHelpCard extends StatelessWidget {
  const _PrivacyHelpCard();

  @override
  Widget build(BuildContext context) {
    return LsCard(
      key: const ValueKey('settings-privacy-help'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PrivacyHelpItem(
            icon: Icons.lock_outline_rounded,
            text: 'Life Shuffle calendars are private to signed-in members.',
          ),
          const SizedBox(height: 12),
          const _PrivacyHelpItem(
            icon: Icons.group_outlined,
            text: 'Shared members can see and edit the shared calendar.',
          ),
          const SizedBox(height: 12),
          const _PrivacyHelpItem(
            icon: Icons.rss_feed_rounded,
            text: 'Published calendar feeds will be read-only.',
          ),
          const SizedBox(height: 12),
          const _PrivacyHelpItem(
            icon: Icons.link_rounded,
            text:
                'Anyone with a published feed link may be able to view that feed.',
          ),
          const SizedBox(height: 12),
          const _PrivacyHelpItem(
            icon: Icons.refresh_rounded,
            text: 'Feed links can be revoked or regenerated later.',
          ),
          const SizedBox(height: 12),
          const _PrivacyHelpItem(
            icon: Icons.schedule_rounded,
            text: 'External calendar apps may not refresh immediately.',
          ),
          const SizedBox(height: 14),
          _TextButtonRow(
            key: const ValueKey('settings-replay-intro'),
            icon: Icons.replay_rounded,
            label: 'Replay intro',
            onTap: () => _replayIntro(context),
          ),
        ],
      ),
    );
  }

  void _replayIntro(BuildContext context) {
    final state = AppStateScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => AppStateScope(
          state: state,
          child: OnboardingScreen(
            onComplete: () => Navigator.of(routeContext).pop(),
          ),
        ),
      ),
    );
  }
}

class _PrivacyHelpItem extends StatelessWidget {
  const _PrivacyHelpItem({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: warmBeige,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: primaryTerracotta),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              height: 1.35,
              color: textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityDefaultsCard extends StatelessWidget {
  const _ActivityDefaultsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _DimensionToggleRow(
            icon: Icons.speed_rounded,
            label: 'Difficulty',
            helper: 'How hard an activity feels to start.',
            valueLabel: 'Default ${state.defaultDifficulty}/5',
            enabled: state.difficultyEnabled,
            onChanged: state.setDifficultyEnabled,
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: borderWarm,
            indent: 16,
            endIndent: 16,
          ),
          _DimensionToggleRow(
            icon: Icons.battery_4_bar_rounded,
            label: 'Energy',
            helper: 'The physical or mental load.',
            valueLabel: 'Default ${state.defaultEnergyLabel}',
            enabled: state.energyEnabled,
            onChanged: state.setEnergyEnabled,
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: borderWarm,
            indent: 16,
            endIndent: 16,
          ),
          _DimensionToggleRow(
            icon: Icons.groups_2_rounded,
            label: 'Social',
            helper: 'Solo, together, group, or flexible.',
            valueLabel: 'Default ${state.defaultSocialLabel}',
            enabled: state.socialEnabled,
            onChanged: state.setSocialEnabled,
          ),
        ],
      ),
    );
  }
}

class _DimensionToggleRow extends StatelessWidget {
  const _DimensionToggleRow({
    required this.icon,
    required this.label,
    required this.helper,
    required this.valueLabel,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String helper;
  final String valueLabel;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: warmBeige,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: primaryTerracotta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: enabled ? const Color(0xFFEEF6F2) : warmBeige,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        enabled ? 'On' : 'Off',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: enabled ? accentSage : textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  helper,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    height: 1.25,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valueLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: enabled,
            activeThumbColor: primaryTerracotta,
            activeTrackColor: primaryTerracotta.withValues(alpha: 0.32),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.0,
        color: textMuted,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(children.length, (i) {
          final isLast = i == children.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: children[i],
              ),
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: borderWarm,
                  indent: 16,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.hasChevron = true,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool hasChevron;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 18, color: color ?? textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color ?? textPrimary,
            ),
          ),
        ),
        if (value.isNotEmpty)
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textMuted,
              ),
            ),
          ),
        if (hasChevron) ...[
          const SizedBox(width: 6),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: textMuted,
          ),
        ],
      ],
    );
    if (onTap == null) return row;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

class _TextButtonRow extends StatelessWidget {
  const _TextButtonRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryTerracotta),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryTerracotta,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStyleCard extends StatelessWidget {
  const _PlanStyleCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return LsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan style',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Controls how many activities the planner targets each week.',
            style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 12),
          _PlanStylePicker(
            current: state.planStyle,
            onChanged: state.setPlanStyle,
          ),
        ],
      ),
    );
  }
}

class _PlanStylePicker extends StatelessWidget {
  const _PlanStylePicker({required this.current, required this.onChanged});

  final PlanStyle current;
  final ValueChanged<PlanStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (PlanStyle.gentle, 'Gentle', '~3/week', '4 rest days'),
      (PlanStyle.balanced, 'Balanced', '~5/week', '2 rest days'),
      (PlanStyle.push, 'Push me', '~7/week', '2 rest days'),
    ];
    return Row(
      children: options.indexed
          .map(((int, (PlanStyle, String, String, String)) pair) {
        final i = pair.$1;
        final (style, label, activities, restDays) = pair.$2;
        final selected = current == style;
        final isLast = i == options.length - 1;
        final mutedColor =
            selected ? Colors.white.withValues(alpha: 0.75) : textMuted;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(style),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? primaryTerracotta : warmBeige,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : textPrimary,
                    ),
                  ),
                  Text(
                    activities,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: mutedColor,
                    ),
                  ),
                  Text(
                    restDays,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EditableChip extends StatelessWidget {
  const _EditableChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: warmBeige,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
      ),
    );
  }
}
