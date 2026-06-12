import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../screens/today_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/activities_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';

class BottomNavShell extends StatefulWidget {
  const BottomNavShell({super.key});

  @override
  State<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends State<BottomNavShell> {
  int _index = 0;

  static const _items = [
    _NavItem(label: 'Today', icon: Icons.access_time_rounded),
    _NavItem(label: 'Plan', icon: Icons.calendar_today_rounded),
    _NavItem(label: 'Activities', icon: Icons.format_list_bulleted_rounded),
    _NavItem(label: 'Progress', icon: Icons.bar_chart_rounded),
    _NavItem(label: 'Settings', icon: Icons.settings_rounded),
  ];

  static const _screens = [
    TodayScreen(),
    PlanScreen(),
    ActivitiesScreen(),
    ProgressScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: _LifeShuffleBottomNav(
        currentIndex: _index,
        items: _items,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}

class _LifeShuffleBottomNav extends StatelessWidget {
  const _LifeShuffleBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: surfaceWhite,
        border: Border(top: BorderSide(color: borderWarm, width: 1)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      height: 64 + bottomPad,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(
          items.length,
          (i) => _NavTile(
            item: items[i],
            active: i == currentIndex,
            onTap: () => onTap(i),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(
                item.icon,
                size: 22,
                color: active ? primaryTerracotta : textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: active ? primaryTerracotta : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
