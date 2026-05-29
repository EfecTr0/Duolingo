import 'dart:convert';
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../main.dart' show setBackgroundMusicVolume, setSFXVolume, playClickSound,
    getMicrophoneDevices, startMicMonitor, stopMicMonitor, setMicMonitorVolume, developerMode;

class SettingsScreen extends StatefulWidget {
  final ValueChanged<bool> onToggleTheme;
  final VoidCallback? onLogout;

  const SettingsScreen({
    Key? key,
    required this.onToggleTheme,
    this.onLogout,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _musicVolume = 0.5;
  double _sfxVolume = 0.5;

  double _micVolume = 1.0;
  List<MicDevice> _micDevices = [];
  String? _selectedMicId;
  bool _isMonitoring = false;
  String _monitorButtonLabel = 'Проверить звук';

  bool _developerMode = developerMode;

  @override
  void initState() {
    super.initState();
    _loadMicDevices();
  }

  Future<void> _loadMicDevices() async {
    js.context['onMicDevices'] = (String jsonStr) {
      final List<dynamic> list = jsonDecode(jsonStr);
      setState(() {
        _micDevices = list.map((d) => MicDevice(d['id'], d['label'])).toList();
        if (_micDevices.isNotEmpty && _selectedMicId == null) {
          _selectedMicId = _micDevices[0].id;
        }
      });
    };
    getMicrophoneDevices('onMicDevices');
  }

  void _toggleMonitoring() async {
    if (_isMonitoring) {
      stopMicMonitor();
      setBackgroundMusicVolume(_musicVolume);
      setState(() {
        _isMonitoring = false;
        _monitorButtonLabel = 'Проверить звук';
      });
    } else {
      if (_selectedMicId == null) return;
      setState(() {
        _isMonitoring = true;
        _monitorButtonLabel = '...';
      });
      js.context['onMicMonitorStart'] = (bool success) {
        if (!success) {
          setState(() {
            _isMonitoring = false;
            _monitorButtonLabel = 'Проверить звук';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось запустить мониторинг микрофона')),
          );
        }
      };
      startMicMonitor(_selectedMicId!, _micVolume, 0.1, 'onMicMonitorStart');
    }
  }

  @override
  void dispose() {
    if (_isMonitoring) {
      stopMicMonitor();
      setBackgroundMusicVolume(_musicVolume);
    }
    super.dispose();
  }

  String _volumeEmoji(double volume) {
    if (volume >= 0.8) return '🔊';
    if (volume >= 0.2) return '🔉';
    return '🔈';
  }

  void _logout() async {
    await ApiService.deleteToken();
    widget.onLogout?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeEmoji = isDark ? '🌕' : '☀️';

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(height: 20),
          Center(child: Text('Настройки', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          SizedBox(height: 20),
          ListTile(
            leading: Text(_volumeEmoji(_musicVolume), style: TextStyle(fontSize: 28)),
            title: const Text('Музыка'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _musicVolume,
                min: 0, max: 1, divisions: 10,
                label: '${(_musicVolume * 100).round()}%',
                onChanged: (value) {
                  setState(() => _musicVolume = value);
                  setBackgroundMusicVolume(value);
                },
              ),
            ),
          ),
          ListTile(
            leading: Text(_volumeEmoji(_sfxVolume), style: TextStyle(fontSize: 28)),
            title: const Text('Звуки'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _sfxVolume,
                min: 0, max: 1, divisions: 10,
                label: '${(_sfxVolume * 100).round()}%',
                onChanged: (value) {
                  setState(() => _sfxVolume = value);
                  setSFXVolume(value);
                },
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Text('🎙️', style: TextStyle(fontSize: 28)),
                SizedBox(width: 8),
                Text('Микрофон', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (_micDevices.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _selectedMicId,
              decoration: InputDecoration(labelText: 'Устройство'),
              items: _micDevices.map((d) => DropdownMenuItem(
                value: d.id,
                child: Text(d.label, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) {
                setState(() => _selectedMicId = val);
                if (_isMonitoring) {
                  stopMicMonitor();
                  startMicMonitor(val!, _micVolume, 0.1, 'onMicMonitorStart');
                }
              },
            ),
          SizedBox(height: 10),
          ListTile(
            leading: Text('🎚️', style: TextStyle(fontSize: 24)),
            title: const Text('Громкость микрофона'),
            trailing: SizedBox(
              width: 200,
              child: Slider(
                value: _micVolume,
                min: 0, max: 2, divisions: 10,
                label: '${(_micVolume * 100).round()}%',
                onChanged: (value) {
                  setState(() => _micVolume = value);
                  setMicMonitorVolume(value);
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          Center(
            child: ElevatedButton(
              onPressed: _toggleMonitoring,
              child: Text(_monitorButtonLabel),
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: Text(themeEmoji, style: TextStyle(fontSize: 28)),
            title: const Text('Тёмная тема'),
            value: isDark,
            onChanged: (value) {
              playClickSound();
              widget.onToggleTheme(value);
            },
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Text('🛠️', style: TextStyle(fontSize: 28)),
            title: const Text('Режим разработчика'),
            value: _developerMode,
            onChanged: (value) {
              playClickSound();
              setState(() => _developerMode = value);
              developerMode = value;
            },
          ),
          const Divider(),
          Center(
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Text('❌', style: TextStyle(fontSize: 20)),
              label: const Text('Выйти из аккаунта', style: TextStyle(color: Colors.red, fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

class MicDevice {
  final String id;
  final String label;
  MicDevice(this.id, this.label);
}