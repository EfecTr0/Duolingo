import 'package:flutter/material.dart';
import 'screens/menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'main.dart' show playClickSound;

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
  int _currentIndex = 0; // 0 - Профиль, 1 - Меню, 2 - Настройки
  final GlobalKey<MenuScreenState> _menuKey = GlobalKey();

  void _onTabChange(int index) {
    playClickSound();
    setState(() => _currentIndex = index);
    if (index == 1) {
      _menuKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ProfileScreen(),
          MenuScreen(key: _menuKey),
          SettingsScreen(
            isDarkMode: widget.isDarkMode,
            onToggleTheme: widget.onToggleTheme,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,                               // достаточно для эмодзи и текста
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _EmojiButton(
              emoji: '👤',
              label: 'Профиль',
              onPressed: () => _onTabChange(0),
            ),
            _EmojiButton(
              emoji: '🎮',
              label: 'Меню',
              onPressed: () => _onTabChange(1),
            ),
            _EmojiButton(
              emoji: '⚙️',
              label: 'Настройки',
              onPressed: () => _onTabChange(2),
            ),
          ],
        ),
      ),
    );
  }
}

// Анимированная кнопка с эмодзи
class _EmojiButton extends StatefulWidget {
  final String emoji;
  final String label;
  final VoidCallback onPressed;

  const _EmojiButton({
    required this.emoji,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward().then((_) => _controller.reverse());
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 30)),  // чуть меньше
            Text(widget.label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}