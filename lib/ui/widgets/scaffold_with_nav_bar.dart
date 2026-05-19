import 'package:flutter/material.dart';

import '../../core/constants/design_tokens.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';

/// Shell-виджет с Bottom Navigation: IndexedStack (без пересоздания экранов)
/// и кастомным BottomNavigationBar в стиле проекта.
///
/// ProcessingScreen и ResultScreen пушатся поверх через Navigator.push —
/// они не вкладки.
class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({super.key});

  /// Переключить вкладку программно (например, из баннера HomeScreen).
  static ScaffoldWithNavBarState? of(BuildContext context) =>
      context.findAncestorStateOfType<ScaffoldWithNavBarState>();

  @override
  State<ScaffoldWithNavBar> createState() => ScaffoldWithNavBarState();
}

class ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      backgroundColor: Colors.transparent,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.inkTertiary,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Главная',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          label: 'История',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          label: 'Настройки',
        ),
      ],
    );
  }
}
