import 'package:flutter/material.dart';
import 'screens/menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/collection_screen.dart';   // <-- новый импорт
import 'login_screen.dart';
import 'main.dart' show playClickSound;

class MainScreen extends StatefulWidget {
  final ValueChanged<bool> onToggleTheme;

  const MainScreen({
    Key? key,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // 0 - Профиль, 1 - Друзья, 2 - Меню, 3 - Коллекция, 4 - Настройки

  void _onTabChange(int index) {
    playClickSound();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: [
            ProfileScreen(),
            FriendsScreen(),
            MenuScreen(),
            CollectionScreen(),       // <-- новая вкладка
            SettingsScreen(
              onToggleTheme: widget.onToggleTheme,
              onLogout: () {
                widget.onToggleTheme(false);
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      onToggleTheme: widget.onToggleTheme,
                      onResetTheme: () => widget.onToggleTheme(false),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _EmojiButton(emoji: '👤', label: 'Профиль', onPressed: () => _onTabChange(0)),
            _EmojiButton(emoji: '👥', label: 'Друзья', onPressed: () => _onTabChange(1)),
            _EmojiButton(emoji: '🎮', label: 'Меню', onPressed: () => _onTabChange(2)),
            _EmojiButton(emoji: '📚', label: 'Коллекция', onPressed: () => _onTabChange(3)),
            _EmojiButton(emoji: '⚙️', label: 'Настройки', onPressed: () => _onTabChange(4)),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final String label;
  final VoidCallback onPressed;
  const _EmojiButton({required this.emoji, required this.label, required this.onPressed});

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
            Text(widget.emoji, style: const TextStyle(fontSize: 30)),
            Text(widget.label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}