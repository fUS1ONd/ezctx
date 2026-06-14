import 'package:flutter/material.dart';

import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import 'liquid_glass_tab_bar.dart';

/// Shell-виджет с Bottom Navigation: IndexedStack (без пересоздания экранов)
/// и плавающая Liquid Glass панель снизу.
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
      // extendBody: true — чтобы под панелью просвечивал градиент/обои.
      extendBody: true,
      // Клавиатура наезжает поверх, а не сжимает body. Иначе на вкладке
      // «История» заглушка «Ничего не найдено» даёт overflow при поиске.
      // Парный флаг на HistoryScreen.Scaffold — нужны оба (вложенные Scaffold).
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          HomeScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: LiquidGlassTabBar(
          activeIndex: _currentIndex,
          onChanged: switchTab,
        ),
      ),
    );
  }
}
