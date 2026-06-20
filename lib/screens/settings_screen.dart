import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/planner_service.dart' show PlanStyle;
import '../services/text_week_export_service.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';
import 'onboarding_screen.dart';

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
        : state.calendarOwnerUserId == user?.uid
            ? 'You'
            : _shortId(state.calendarOwnerUserId!);
    final memberLabel = _memberLabel(state.calendarMemberUserIds, user?.uid);

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
                  if (state.lastSyncErrorMessage != null) ...[
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
                    ],
                  ),
                  const SizedBox(height: 10),
                  LsCard(
                    color: warmBeige,
                    child: Text(
                      'Sharing with Laura is coming later. For now this is your default calendar foundation.',
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

  static String _memberLabel(List<String> ids, String? currentUserId) {
    if (ids.isEmpty) return 'Local only';
    if (ids.length == 1 && ids.first == currentUserId) return 'You';
    final labels =
        ids.map((id) => id == currentUserId ? 'You' : _shortId(id)).join(', ');
    return labels;
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
                      'Week text export',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Copies this week as plain text. Private notes are not included.',
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
          _PublishingActionButton(
            key: const ValueKey('settings-copy-week-text-export'),
            icon: Icons.copy_rounded,
            label: 'Copy text',
            onTap: () => _copyWeekTextExport(context, state),
          ),
        ],
      ),
    );
  }
}

void _copyWeekTextExport(BuildContext context, AppState state) {
  final text = TextWeekExportService.generate(
    calendarTitle: state.calendarTitle,
    plan: state.weekPlan,
  );
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Week text copied')),
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

class _SyncDiagnosticsCard extends StatelessWidget {
  const _SyncDiagnosticsCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final attemptedAt = state.lastSyncAttemptAtMillis;
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
              color: primaryTerracotta.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.sync_problem_rounded,
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
                  'Sync diagnostics',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.lastSyncErrorMessage ?? state.lastSyncStatus,
                  key: const ValueKey('settings-sync-error-message'),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryTerracotta,
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (state.feedEnabled) ...[
                  _PublishingActionButton(
                    key: const ValueKey('settings-copy-feed-link'),
                    icon: Icons.copy_rounded,
                    label: 'Copy link',
                    onTap: () => _copyFeedLink(context, state.feedToken!),
                  ),
                  _PublishingActionButton(
                    key: const ValueKey('settings-regenerate-feed-token'),
                    icon: Icons.refresh_rounded,
                    label: 'Regenerate token',
                    onTap: state.regenerateFeedToken,
                  ),
                ],
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

void _copyFeedLink(BuildContext context, String token) {
  Clipboard.setData(ClipboardData(text: _buildCalendarFeedUrl(token)));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Feed link copied')),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => OnboardingScreen(
          onComplete: () => Navigator.of(routeContext).pop(),
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
  });

  final IconData icon;
  final String label;
  final String value;
  final bool hasChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 18, color: textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textPrimary,
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
