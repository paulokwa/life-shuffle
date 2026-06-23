import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../screens/today_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/activities_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';

/// Tab indices for [BottomNavShell], matching its `_items`/`_screens` order.
/// Lets descendant screens (via [BottomNavScope]) request a tab switch
/// without hard-coding raw indices at the call site.
abstract final class BottomNavTab {
  static const today = 0;
  static const plan = 1;
  static const activities = 2;
  static const progress = 3;
  static const settings = 4;
}

/// Exposes [BottomNavShell]'s tab switch to descendant screens (e.g. the
/// Today screen's quick actions jumping to Plan/Progress) without a second
/// `Navigator`/route stack. Absent when a screen is hosted outside the
/// shell (e.g. in isolation in a test), so callers should use
/// [BottomNavScope.maybeOf] and treat a null result as "no tab navigation
/// available here" rather than throwing.
class BottomNavScope extends InheritedWidget {
  const BottomNavScope({
    super.key,
    required this.onNavigate,
    required super.child,
  });

  final ValueChanged<int> onNavigate;

  static BottomNavScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BottomNavScope>();

  @override
  bool updateShouldNotify(BottomNavScope oldWidget) =>
      onNavigate != oldWidget.onNavigate;
}

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

  void _goToTab(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      body: BottomNavScope(
        onNavigate: _goToTab,
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: _LifeShuffleBottomNav(
        currentIndex: _index,
        items: _items,
        onTap: _goToTab,
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
