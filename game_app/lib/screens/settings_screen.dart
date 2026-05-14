import 'package:flutter/material.dart';

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
  double _volume = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Громкость
          ListTile(
            title: const Text('Громкость'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _volume,
                min: 0,
                max: 1,
                divisions: 10,
                label: '${(_volume * 100).round()}%',
                onChanged: (value) {
                  setState(() {
                    _volume = value;
                  });
                },
              ),
            ),
          ),
          const Divider(),
          // Тема
          SwitchListTile(
            title: const Text('Тёмная тема'),
            value: widget.isDarkMode,
            onChanged: widget.onToggleTheme,
          ),
        ],
      ),
    );
  }
}