import 'package:flutter/material.dart';
import 'dart:js' as js;
import 'login_screen.dart';
import 'data/player.dart';
import 'api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

// ---------- Фоновая музыка ----------
void switchBackgroundMusic(String type) {
  try { js.context.callMethod('switchBGM', [type]); } catch (e) { debugPrint('Ошибка смены музыки: $e'); }
}
void setBackgroundMusicVolume(double volume) {
  try { js.context.callMethod('setBGMVolume', [volume]); } catch (e) { debugPrint('Ошибка громкости музыки: $e'); }
}
void setSFXVolume(double volume) {
  try { js.context.callMethod('setSFXVolume', [volume]); } catch (e) { debugPrint('Ошибка громкости звуков: $e'); }
}

// ---------- Звуковые эффекты ----------
void playSound(String id) {
  try { js.context.callMethod('playSound', [id]); } catch (e) { debugPrint('Ошибка звука "$id": $e'); }
}
void playClickSound() => playSound('click');
void playCorrectSound() => playSound('correct');
void playIncorrectSound() => playSound('incorrect');
void playFinishSound() => playSound('finish');

// ---------- Голосовой ввод ----------
void startSpeechRecognition(String lang, String callbackName) {
  try { js.context.callMethod('startSpeechRecognition', [lang, callbackName]); } catch (e) { debugPrint('Ошибка старта распознавания: $e'); }
}
void stopSpeechRecognition() {
  try { js.context.callMethod('stopSpeechRecognition', []); } catch (e) { debugPrint('Ошибка остановки распознавания: $e'); }
}

// ---------- Микрофон ----------
void getMicrophoneDevices(String callbackName) {
  try { js.context.callMethod('getMicrophoneDevices', [callbackName]); } catch (e) { debugPrint('Ошибка получения устройств: $e'); }
}
void startMicMonitor(String deviceId, double volume, double bgmLowVolume, String callbackName) {
  try { js.context.callMethod('startMicMonitor', [deviceId, volume, bgmLowVolume, callbackName]); } catch (e) { debugPrint('Ошибка запуска мониторинга: $e'); }
}
void stopMicMonitor() {
  try { js.context.callMethod('stopMicMonitor', []); } catch (e) { debugPrint('Ошибка остановки мониторинга: $e'); }
}
void setMicMonitorVolume(double vol) {
  try { js.context.callMethod('setMicMonitorVolume', [vol]); } catch (e) { debugPrint('Ошибка громкости монитора: $e'); }
}

bool developerMode = false;

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme(bool value) {
    setState(() => _isDarkMode = value);
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
      home: LoginScreen(
        onToggleTheme: _toggleTheme,
        onResetTheme: () => setState(() => _isDarkMode = false),
      ),
    );
  }
}