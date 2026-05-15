import 'package:flutter/material.dart';
import 'game_screen.dart';
import '../data/player.dart';
import '../main.dart' show switchBackgroundMusic, playClickSound;

class MenuScreen extends StatefulWidget {
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  String _selectedDifficulty = 'лёгкий';

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'лёгкий': return Colors.green;
      case 'средний': return Colors.yellow;
      case 'сложный': return Colors.red;
      case 'носитель': return Color(0xFF800000);
      default: return Colors.grey;
    }
  }

  void _showDifficultyDialog() {
    playClickSound();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Выберите уровень сложности'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: ['лёгкий', 'средний', 'сложный', 'носитель'].map((level) {
                return RadioListTile<String>(
                  title: Text(level[0].toUpperCase() + level.substring(1)),
                  value: level,
                  groupValue: _selectedDifficulty,
                  onChanged: (value) {
                    setDialogState(() => _selectedDifficulty = value!);
                    setState(() {});
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _startGame() async {
    playClickSound();
    // Определяем тип музыки по сложности
    String musicType;
    if (_selectedDifficulty == 'лёгкий' || _selectedDifficulty == 'средний') {
      musicType = 'game_easy_medium';
    } else {
      musicType = 'game_hard_native';
    }
    switchBackgroundMusic(musicType);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(difficulty: _selectedDifficulty),
      ),
    );

    // Возвращаем музыку меню
    switchBackgroundMusic('menu');

    if (result != null && result is Map<String, dynamic>) {
      int correct = result['correct'] as int;
      int total = result['total'] as int;
      bool bonusAvailable = result['bonusAvailable'] as bool;
      bool bonusSolved = result['bonusSolved'] as bool;

      int baseExp;
      switch (_selectedDifficulty) {
        case 'лёгкий': baseExp = 10; break;
        case 'средний': baseExp = 20; break;
        case 'сложный': baseExp = 30; break;
        case 'носитель': baseExp = 50; break;
        default: baseExp = 10;
      }

      double percent = total > 0 ? correct / total : 0.0;
      int experienceEarned = (baseExp * percent).round();

      if (bonusAvailable && bonusSolved) {
        int bonusExp = (baseExp * 0.3).round();
        experienceEarned += bonusExp;
      }

      if (experienceEarned > 0) {
        PlayerData().addExperience(experienceEarned);
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerData();
    final color = _difficultyColor(_selectedDifficulty);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Уровень: ${player.level}', style: TextStyle(fontSize: 18)),
                      SizedBox(height: 8),
                      LinearProgressIndicator(value: player.progress),
                      Text(
                        '${player.experienceInCurrentLevel} / ${player.experienceForNextLevel} XP',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Spacer(),
            // Кнопка выбора сложности (уменьшенная и по центру)
            Center(
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _showDifficultyDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size(0, 48),
                  ),
                  child: Text(
                    '${_selectedDifficulty[0].toUpperCase()}${_selectedDifficulty.substring(1)}',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            // Кнопка Играть (уменьшенная и по центру)
            Center(
              child: SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(0, 48),
                  ),
                  child: Text('Играть', style: TextStyle(fontSize: 22)),
                ),
              ),
            ),
            Spacer(),
          ],
        ),
      ),
    );
  }
}