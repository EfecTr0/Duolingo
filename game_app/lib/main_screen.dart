import 'package:flutter/material.dart';
import 'screens/menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleTheme;

  const MainScreen({
    Key? key,
    required this.isDarkMode,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0; // 0 – Меню, 1 – Профиль, 2 – Настройки

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MenuScreen(),
          ProfileScreen(),
          SettingsScreen(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            TextButton(
              onPressed: () => setState(() => _currentIndex = 0),
              child: Text('Меню'),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 1),
              child: Text('Профиль'),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 2),
              child: Text('Настройки'),
            ),
          ],
        ),
      ),
    );
  }
}