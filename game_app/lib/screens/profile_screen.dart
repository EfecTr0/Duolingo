import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../data/player.dart';
import '../main.dart' show playClickSound;

class ProfileScreen extends StatefulWidget {
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
        setState(() => PlayerData().avatarBytes = file.bytes);
      }
    }
  }

  void _saveNickname() {
    playClickSound();
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty) {
      PlayerData().nickname = newName;
      setState(() {});
    }
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'лёгкий': return Colors.green;
      case 'средний': return Colors.yellow;
      case 'сложный': return Colors.red;
      case 'носитель': return const Color(0xFF800000);
      default: return Colors.grey;
    }
  }

  void _showGameDetails(GameResult game) {
    playClickSound();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Детали игры'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: game.attempts.length,
            itemBuilder: (context, index) {
              final att = game.attempts[index];
              return ListTile(
                leading: Icon(
                  att.isCorrect ? Icons.check_circle : Icons.cancel,
                  color: att.isCorrect ? Colors.green : Colors.red,
                ),
                title: Text(att.english, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Правильно: ${att.correctRussian}'),
                    if (att.userAnswer != null) Text('Ваш ответ: ${att.userAnswer}'),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerData();
    final brightness = Theme.of(context).brightness;
    final statBackgroundColor = brightness == Brightness.light
        ? Colors.grey[300]!
        : Colors.grey[800]!;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Center(
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
                        ? const Icon(Icons.camera_alt, color: Colors.white, size: 30)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Имя',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _saveNickname,
                      ),
                    ),
                    onSubmitted: (_) => _saveNickname(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Уровень: ${player.level}', style: const TextStyle(fontSize: 18)),
                const Spacer(),
                Text('${player.experience} XP', style: const TextStyle(fontSize: 16)),
              ],
            ),
            LinearProgressIndicator(value: player.progress),
            const Divider(thickness: 1, height: 32),
            const Text('Друзья', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFriendStat('Подписки', player.subscriptions),
                _buildFriendStat('Подписчики', player.subscribers),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: player.friends.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(player.friends[index], style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(thickness: 1, height: 32),
            const Text('История игр', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.8,
              ),
              itemCount: player.history.length,
              itemBuilder: (context, index) {
                final game = player.history[index];
                final color = _difficultyColor(game.difficulty);
                final percent = game.total > 0 ? (game.correct / game.total) : 0.0;
                final timeStr =
                    '${game.timeSpentSeconds ~/ 60}:${(game.timeSpentSeconds % 60).toString().padLeft(2, '0')}';

                return GestureDetector(
                  onTap: () => _showGameDetails(game),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.6),          // более насыщенный
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Center(
                            child: Stack(
                              children: [
                                // Текст с обводкой
                                Text(
                                  game.difficulty[0].toUpperCase() + game.difficulty.substring(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    foreground: Paint()
                                      ..style = PaintingStyle.stroke
                                      ..strokeWidth = 2
                                      ..color = Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  game.difficulty[0].toUpperCase() + game.difficulty.substring(1),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: statBackgroundColor,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildMiniStat(Icons.star, '${(percent * 100).round()}%', Colors.blue),
                                _buildMiniStat(Icons.access_time, timeStr, Colors.purple),
                                _buildMiniStat(Icons.emoji_events, '${game.experienceEarned}', Colors.amber),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendStat(String label, int count) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 1),
        Text(value, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}