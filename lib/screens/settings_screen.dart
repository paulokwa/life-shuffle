import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                    'Settings',
                    style: GoogleFonts.lora(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (AuthService.isReady) ...[
                    _SectionLabel(label: 'ACCOUNT'),
                    const SizedBox(height: 10),
                    _SettingsGroup(
                      children: [
                        _SettingsRow(
                          icon: Icons.logout_rounded,
                          label: 'Sign out',
                          value: '',
                          hasChevron: false,
                          onTap: () => AuthService.signOut(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  // Profile card
                  LsCard(
                    child: Row(
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
                            'K',
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
                                'Kwame',
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              Text(
                                'Kwame and Laura · Calendar',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
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
                  _SectionLabel(label: 'PLANNING'),
                  const SizedBox(height: 10),
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: Icons.calendar_today_rounded,
                        label: 'Week starts on',
                        value: 'Monday',
                      ),
                      _SettingsRow(
                        icon: Icons.bolt_rounded,
                        label: 'Auto-generate plan',
                        value: 'On Sundays',
                      ),
                      _SettingsRow(
                        icon: Icons.lock_open_rounded,
                        label: 'Locked activities',
                        value: '1 this week',
                      ),
                    ],
                  ),
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
                    children: [
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
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
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
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: valueColor ?? textMuted,
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
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
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
