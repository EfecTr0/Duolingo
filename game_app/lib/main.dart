import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'main_screen.dart';
import 'data/player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

// --- Фоновая музыка ---

/// type: 'menu', 'game_easy_medium', 'game_hard_native', 'finish'
void switchBackgroundMusic(String type) {
  try {
    js.context.callMethod('switchBGM', [type]);
  } catch (e) {
    debugPrint('Ошибка смены музыки: $e');
  }
}

/// Громкость фоновой музыки (0.0 - 1.0)
void setBackgroundMusicVolume(double volume) {
  try {
    js.context.callMethod('setBGMVolume', [volume]);
  } catch (e) {
    debugPrint('Ошибка изменения громкости музыки: $e');
  }
}

/// Громкость звуковых эффектов
void setSFXVolume(double volume) {
  try {
    js.context.callMethod('setSFXVolume', [volume]);
  } catch (e) {
    debugPrint('Ошибка изменения громкости звуков: $e');
  }
}

// --- Звуковые эффекты ---
void playSound(String id) {
  try {
    js.context.callMethod('playSound', [id]);
  } catch (e) {
    debugPrint('Ошибка звука "$id": $e');
  }
}

void playClickSound() => playSound('click');
void playCorrectSound() => playSound('correct');
void playIncorrectSound() => playSound('incorrect');
void playFinishSound() => playSound('finish');

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Игровое приложение',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      home: MainScreen(
        isDarkMode: _isDarkMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}