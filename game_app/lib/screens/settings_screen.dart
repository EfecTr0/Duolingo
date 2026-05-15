import 'package:flutter/material.dart';
import '../main.dart' show setBackgroundMusicVolume, setSFXVolume, playClickSound;

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onToggleTheme;

  const SettingsScreen({
    Key? key,
    required this.isDarkMode,
    required this.onToggleTheme,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _musicVolume = 0.5;
  double _sfxVolume = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Громкость музыки
          ListTile(
            title: const Text('Музыка'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _musicVolume,
                min: 0,
                max: 1,
                divisions: 10,
                label: '${(_musicVolume * 100).round()}%',
                onChanged: (value) {
                  setState(() => _musicVolume = value);
                  setBackgroundMusicVolume(value);
                },
              ),
            ),
          ),
          // Громкость звуков
          ListTile(
            title: const Text('Звуки'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _sfxVolume,
                min: 0,
                max: 1,
                divisions: 10,
                label: '${(_sfxVolume * 100).round()}%',
                onChanged: (value) {
                  setState(() => _sfxVolume = value);
                  setSFXVolume(value);
                },
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Тёмная тема'),
            value: widget.isDarkMode,
            onChanged: (value) {
              playClickSound();
              widget.onToggleTheme(value);
            },
          ),
        ],
      ),
    );
  }
}