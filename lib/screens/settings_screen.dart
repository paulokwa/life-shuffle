import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/planner_service.dart' show PlanStyle;
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

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
                  _SectionLabel(label: 'ACCOUNT'),
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
                  const SizedBox(height: 20),
                  _SectionLabel(label: 'CALENDAR'),
                  const SizedBox(height: 10),
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Current calendar',
                        value: state.calendarTitle,
                        hasChevron: false,
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
                  _SectionLabel(label: 'PLANNING'),
                  const SizedBox(height: 10),
                  _PlanStyleCard(state: state),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'CATEGORIES'),
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
                  _SectionLabel(label: 'SHARING'),
                  const SizedBox(height: 10),
                  _SettingsGroup(
                    children: const [
                      _SettingsRow(
                        icon: Icons.rss_feed_rounded,
                        label: 'ICS feed',
                        value: 'Not published',
                        valueColor: textMuted,
                      ),
                      _SettingsRow(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'Export PDF',
                        value: 'Tap to export',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(label: 'ABOUT'),
                  const SizedBox(height: 10),
                  _SettingsGroup(
                    children: const [
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
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.hasChevron = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool hasChevron;

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
                color: valueColor ?? textMuted,
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
    return row;
  }
}

class _TextButtonRow extends StatelessWidget {
  const _TextButtonRow({
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
