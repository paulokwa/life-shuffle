import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/activity.dart';
import '../state/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/category_chip.dart';
import '../widgets/life_shuffle_header.dart';
import '../widgets/ls_card.dart';

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
                      GestureDetector(
                        onTap: () => _showActivityForm(context),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: primaryTerracotta,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
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
                    (activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActivityCard(
                        activity: activity,
                        onEdit: () => _showActivityForm(
                          context,
                          activity: activity,
                        ),
                      ),
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

  void _showActivityForm(BuildContext context, {Activity? activity}) {
    final appState = AppStateScope.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ActivityFormSheet(
          activity: activity,
          onSave: ({
            required String title,
            required String category,
            required int durationMinutes,
            required String preferredTime,
            required int maxPerWeek,
            required List<int> allowedWeekdays,
            required bool noConsecutiveDays,
            required bool enabled,
          }) {
            if (activity == null) {
              appState.addActivity(
                title: title,
                category: category,
                durationMinutes: durationMinutes,
                preferredTime: preferredTime,
                maxPerWeek: maxPerWeek,
                allowedWeekdays: allowedWeekdays,
                noConsecutiveDays: noConsecutiveDays,
                enabled: enabled,
              );
            } else {
              appState.updateActivity(
                activity.id,
                title: title,
                category: category,
                durationMinutes: durationMinutes,
                preferredTime: preferredTime,
                maxPerWeek: maxPerWeek,
                allowedWeekdays: allowedWeekdays,
                noConsecutiveDays: noConsecutiveDays,
                enabled: enabled,
              );
            }
            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onEdit,
  });

  final Activity activity;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedOpacity(
      opacity: activity.enabled ? 1.0 : 0.52,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onEdit,
        behavior: HitTestBehavior.opaque,
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
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CategoryChip(category: activity.category),
                        Text(
                          activity.duration,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                        Text(
                          _preferredTimeLabel(activity.preferredTime),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                        Text(
                          _ruleSummary(activity),
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
                onTap: () => state.setActivityEnabled(
                  activity.id,
                  enabled: !activity.enabled,
                ),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    activity.enabled
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    size: 34,
                    color: activity.enabled ? accentSage : textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.edit_rounded,
                size: 16,
                color: textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _preferredTimeLabel(String value) {
    return switch (value) {
      'morning' => 'Morning',
      'afternoon' => 'Afternoon',
      'evening' => 'Evening',
      _ => 'Anytime',
    };
  }

  static String _ruleSummary(Activity activity) {
    final days = activity.allowedWeekdays.length == 7
        ? 'any day'
        : '${activity.allowedWeekdays.length} days';
    final consecutive = activity.noConsecutiveDays ? ', no back-to-back' : '';
    return 'Max ${activity.maxPerWeek}/week, $days$consecutive';
  }
}

class _ActivityFormSheet extends StatefulWidget {
  const _ActivityFormSheet({
    required this.activity,
    required this.onSave,
  });

  final Activity? activity;
  final void Function({
    required String title,
    required String category,
    required int durationMinutes,
    required String preferredTime,
    required int maxPerWeek,
    required List<int> allowedWeekdays,
    required bool noConsecutiveDays,
    required bool enabled,
  }) onSave;

  @override
  State<_ActivityFormSheet> createState() => _ActivityFormSheetState();
}

class _ActivityFormSheetState extends State<_ActivityFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late final TextEditingController _maxPerWeekController;
  late String _category;
  late String _preferredTime;
  late Set<int> _allowedWeekdays;
  late bool _noConsecutiveDays;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    final activity = widget.activity;
    _titleController = TextEditingController(text: activity?.title ?? '');
    _durationController = TextEditingController(
      text: '${activity?.durationMinutes ?? 45}',
    );
    _maxPerWeekController = TextEditingController(
      text: '${activity?.maxPerWeek ?? 1}',
    );
    _category = activity?.category ?? 'Outside';
    _preferredTime = activity?.preferredTime ?? 'anytime';
    _allowedWeekdays = Set<int>.from(
      activity?.allowedWeekdays ?? Activity.allWeekdays,
    );
    _noConsecutiveDays = activity?.noConsecutiveDays ?? false;
    _enabled = activity?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _maxPerWeekController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: backgroundCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderWarmStrong,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.activity == null ? 'Add activity' : 'Edit activity',
                  style: GoogleFonts.lora(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Title'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _inputDecoration('Category'),
                  items: Activity.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Duration minutes'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Use a number of minutes';
                    }
                    if (parsed > 720) return 'Keep it under 12 hours';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _preferredTime,
                  decoration: _inputDecoration('Preferred time'),
                  items: Activity.preferredTimes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_preferredTimeLabel(value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _preferredTime = value);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _maxPerWeekController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration('Max per week'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Use a number from 1 to 7';
                    }
                    if (parsed > 7) return 'Keep it to 7 or fewer';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _WeekdaySelector(
                  selectedWeekdays: _allowedWeekdays,
                  onChanged: (weekday) {
                    setState(() {
                      if (_allowedWeekdays.contains(weekday)) {
                        if (_allowedWeekdays.length > 1) {
                          _allowedWeekdays.remove(weekday);
                        }
                      } else {
                        _allowedWeekdays.add(weekday);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderWarm),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _noConsecutiveDays,
                    activeThumbColor: accentSage,
                    activeTrackColor: accentSage.withValues(alpha: 0.28),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    title: Text(
                      'Avoid back-to-back days',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'The planner avoids adjacent days when it has another option.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _noConsecutiveDays = value);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: surfaceWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderWarm),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _enabled,
                    activeThumbColor: accentSage,
                    activeTrackColor: accentSage.withValues(alpha: 0.28),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 2,
                    ),
                    title: Text(
                      'Use in future plans',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      'Disabled activities stay here but are skipped by regeneration.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                    onChanged: (value) => setState(() => _enabled = value),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _SheetButton(
                        label: 'Cancel',
                        foreground: textMuted,
                        background: Colors.transparent,
                        hasBorder: true,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SheetButton(
                        label: 'Save',
                        foreground: Colors.white,
                        background: primaryTerracotta,
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.dmSans(color: textMuted),
      filled: true,
      fillColor: surfaceWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: borderWarm),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: borderWarm),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryTerracotta),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: primaryTerracotta),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final duration = int.tryParse(_durationController.text.trim()) ?? 45;
    final maxPerWeek = int.tryParse(_maxPerWeekController.text.trim()) ?? 1;
    widget.onSave(
      title: _titleController.text.trim(),
      category: _category,
      durationMinutes: duration.clamp(5, 720).toInt(),
      preferredTime: _preferredTime,
      maxPerWeek: maxPerWeek.clamp(1, 7).toInt(),
      allowedWeekdays: _allowedWeekdays.toList()..sort(),
      noConsecutiveDays: _noConsecutiveDays,
      enabled: _enabled,
    );
  }

  static String _preferredTimeLabel(String value) {
    return switch (value) {
      'morning' => 'Morning',
      'afternoon' => 'Afternoon',
      'evening' => 'Evening',
      _ => 'Anytime',
    };
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({
    required this.selectedWeekdays,
    required this.onChanged,
  });

  final Set<int> selectedWeekdays;
  final ValueChanged<int> onChanged;

  static const _labels = {
    1: 'M',
    2: 'T',
    3: 'W',
    4: 'T',
    5: 'F',
    6: 'S',
    7: 'S',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Allowed days',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: Activity.allWeekdays.map((weekday) {
              final selected = selectedWeekdays.contains(weekday);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: weekday == Activity.allWeekdays.last ? 0 : 6,
                  ),
                  child: GestureDetector(
                    onTap: () => onChanged(weekday),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected ? primaryTerracotta : backgroundCream,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: selected ? primaryTerracotta : borderWarm,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _labels[weekday]!,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
    this.hasBorder = false,
  });

  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(100),
          border: hasBorder ? Border.all(color: borderWarmStrong) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
