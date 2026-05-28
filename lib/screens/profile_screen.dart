import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
        setState(() {
          PlayerData().avatarBytes = file.bytes;
        });
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
      case 'носитель': return Color(0xFF800000);
      case 'случайная': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _modeTitle(String? mode) {
    switch (mode) {
      case 'cards': return 'Карточки';
      case 'matching': return 'Сопоставление';
      case 'mixed': return 'Смешанный';
      default: return 'Неизвестный режим';
    }
  }

  void _showGameDetails(GameResult game) {
    playClickSound();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Center(child: Text(_modeTitle(game.mode), style: TextStyle(fontWeight: FontWeight.bold))),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _buildGameContent(game),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Закрыть'))],
      ),
    );
  }

  Widget _buildGameContent(GameResult game) {
    if (game.mode == 'cards' || game.mode == null) {
      // Карточки – прежний список
      return ListView.builder(
        itemCount: game.attempts.length,
        itemBuilder: (context, index) {
          final att = game.attempts[index];
          return ListTile(
            leading: Icon(
              att.isCorrect ? Icons.check_circle : Icons.cancel,
              color: att.isCorrect ? Colors.green : Colors.red,
            ),
            title: Text(att.english, style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Правильно: ${att.correctRussian}'),
                if (att.userAnswer != null) Text('Ваш ответ: ${att.userAnswer}'),
              ],
            ),
          );
        },
      );
    } else if (game.mode == 'matching') {
      // Сопоставление – только пробованные пары
      final pairs = game.matchPairs ?? [];
      if (pairs.isEmpty) return Center(child: Text('Нет данных о попытках'));
      return ListView.builder(
        itemCount: pairs.length,
        itemBuilder: (context, index) {
          final pair = pairs[index];
          final color = pair.isCorrect ? Colors.green : Colors.red;
          final icon = pair.isCorrect ? Icons.check_circle : Icons.cancel;
          return Container(
            margin: EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(pair.english, style: TextStyle(fontWeight: FontWeight.bold))),
                Icon(Icons.arrow_forward, size: 16),
                Expanded(child: Text(pair.russian)),
              ],
            ),
          );
        },
      );
    } else if (game.mode == 'mixed') {
      // Смешанный – кружки + по раундам
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMiniRoundStat('📇', 'Карточки', game.cardRoundsSuccess ?? 0, game.cardRoundsFailed ?? 0),
              _buildMiniRoundStat('🔗', 'Сопоставление', game.matchRoundsSuccess ?? 0, game.matchRoundsFailed ?? 0),
            ],
          ),
          SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: game.roundDetails?.length ?? 0,
              itemBuilder: (context, index) {
                final round = game.roundDetails![index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Раунд ${index + 1}: ${round.type == 'cards' ? 'Карточки' : 'Сопоставление'}',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (round.type == 'cards')
                          ...round.cardAttempts.map((att) => ListTile(
                                dense: true,
                                leading: Icon(att.isCorrect ? Icons.check_circle : Icons.cancel,
                                    color: att.isCorrect ? Colors.green : Colors.red, size: 18),
                                title: Text(att.english),
                                subtitle: Text('Правильно: ${att.correctRussian}'),
                              ))
                        else
                          ...round.matchPairs.map((pair) => Container(
                                padding: EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(pair.isCorrect ? Icons.check_circle : Icons.cancel,
                                        color: pair.isCorrect ? Colors.green : Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text(pair.english, style: TextStyle(fontWeight: FontWeight.bold)),
                                    Icon(Icons.arrow_forward, size: 16),
                                    Text(pair.russian),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }
    return Center(child: Text('Нет данных'));
  }

  Widget _buildMiniRoundStat(String emoji, String label, int success, int failed) {
    return Column(
      children: [
        Text(emoji, style: TextStyle(fontSize: 24)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        SizedBox(height: 4),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(12)),
              child: Text('$success', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
              child: Text('$failed', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
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
    final statBackgroundColor = brightness == Brightness.light ? Colors.grey[300]! : Colors.grey[800]!;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            Center(child: Text('Профиль', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
            SizedBox(height: 20),
            Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey,
                    backgroundImage: player.avatarBytes != null ? MemoryImage(player.avatarBytes!) : null,
                    child: player.avatarBytes == null ? Icon(Icons.camera_alt, color: Colors.white, size: 30) : null,
                  ),
                ),
                SizedBox(width: 16),
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
            SizedBox(height: 20),
            Row(
              children: [
                Text('Уровень: ${player.level}', style: TextStyle(fontSize: 18)),
                Spacer(),
                Text('${player.experience} XP', style: TextStyle(fontSize: 16)),
              ],
            ),
            LinearProgressIndicator(value: player.progress),
            Divider(thickness: 1, height: 32),
            Text('Друзья', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFriendStat('Подписки', player.subscriptions),
                _buildFriendStat('Подписчики', player.subscribers),
              ],
            ),
            SizedBox(height: 10),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: player.friends.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 24, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white, size: 28)),
                      SizedBox(height: 4),
                      Text(player.friends[index], style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
            Divider(thickness: 1, height: 32),
            Text('История игр', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                final timeStr = '${game.timeSpentSeconds ~/ 60}:${(game.timeSpentSeconds % 60).toString().padLeft(2, '0')}';

                return GestureDetector(
                  onTap: () => _showGameDetails(game),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          flex: 7,
                          child: Center(
                            child: Text(
                              game.difficulty[0].toUpperCase() + game.difficulty.substring(1),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(color: Colors.black38, blurRadius: 2)],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              color: statBackgroundColor,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(6),
                                bottomRight: Radius.circular(6),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
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
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        SizedBox(width: 1),
        Text(value, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}