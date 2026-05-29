import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../api_service.dart';
import '../data/player.dart';
import '../main.dart' show playClickSound;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: PlayerData().nickname);
  }

  Future<void> _pickAvatar() async {
    playClickSound();
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        final base64 = base64Encode(file.bytes!);
        try {
          await ApiService.updateProfile(avatar: base64);
          setState(() {
            PlayerData().avatarBytes = file.bytes;
            PlayerData().avatarBase64 = base64;
          });
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки аватара')));
        }
      }
    }
  }

  void _saveNickname() async {
    playClickSound();
    final newName = _nameController.text.trim();

    // Валидация: только латиница, цифры, пробелы, подчеркивания
    final regex = RegExp(r'^[a-zA-Z0-9 _]+$');
    if (!regex.hasMatch(newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Никнейм может содержать только латиницу, цифры, пробелы и подчеркивания')),
      );
      return;
    }

    if (newName.isNotEmpty) {
      try {
        await ApiService.updateProfile(nickname: newName);
        PlayerData().nickname = newName;
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerData();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Text('Профиль', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey,
                    backgroundImage: player.avatarBytes != null ? MemoryImage(player.avatarBytes!) : null,
                    child: player.avatarBytes == null
                        ? Icon(Icons.camera_alt, color: Colors.white, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Имя',
                      suffixIcon: IconButton(icon: Icon(Icons.check), onPressed: _saveNickname),
                    ),
                    onSubmitted: (_) => _saveNickname(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Уровень: ${player.level}', style: TextStyle(fontSize: 18)),
                const Spacer(),
                Text('${player.experience} XP', style: TextStyle(fontSize: 16)),
              ],
            ),
            LinearProgressIndicator(value: player.progress),
            const SizedBox(height: 8),
            Text(
              '${player.experienceInCurrentLevel} / ${player.experienceForNextLevel} XP',
              style: TextStyle(fontSize: 12),
            ),
            const Divider(height: 32),
            // Достижения
            Text('Достижения', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAchievement(
                  emoji: '🔥',
                  title: 'Подряд',
                  desc: 'Пройти 3 игры в режиме карточек без ошибок подряд',
                  unlocked: player.achievements.contains(1),
                ),
                _buildAchievement(
                  emoji: '👥',
                  title: 'Социальный',
                  desc: 'Добавить 10 друзей',
                  unlocked: player.achievements.contains(2),
                ),
                _buildAchievement(
                  emoji: '🏆',
                  title: 'Профи',
                  desc: 'Пройти любой режим на 100% на сложности Носитель',
                  unlocked: player.achievements.contains(3),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievement({
    required String emoji,
    required String title,
    required String desc,
    required bool unlocked,
  }) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(unlocked ? 'Получено!' : 'Способ получения:\n$desc'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))],
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: unlocked ? Colors.amber[100] : Colors.grey[300],
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: 30)),
                if (!unlocked) Icon(Icons.lock, size: 40, color: Colors.grey[600]),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}