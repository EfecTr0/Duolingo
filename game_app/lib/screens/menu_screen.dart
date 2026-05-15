import 'package:flutter/material.dart';
import 'game_screen.dart';
import '../data/player.dart';
import '../main.dart' show switchBackgroundMusic, playClickSound;

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);
  @override
  State<MenuScreen> createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> {
  String _selectedDifficulty = 'лёгкий';

  void refresh() => setState(() {});

  Color _difficultyColor(String difficulty) {
    switch (difficulty) {
      case 'лёгкий': return Colors.green;
      case 'средний': return Colors.yellow;
      case 'сложный': return Colors.red;
      case 'носитель': return const Color(0xFF800000);
      default: return Colors.grey;
    }
  }

  void _showDifficultyDialog() {
    playClickSound();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выберите уровень сложности'),
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
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть'))],
      ),
    );
  }

  void _showModeSelection() {
    playClickSound();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выбор режима'),
        content: const Text('Пока доступен только режим карточек слов.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _startGame() async {
    playClickSound();
    String musicType = (_selectedDifficulty == 'лёгкий' || _selectedDifficulty == 'средний')
        ? 'game_easy_medium'
        : 'game_hard_native';
    switchBackgroundMusic(musicType);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(difficulty: _selectedDifficulty)),
    );

    switchBackgroundMusic('menu');

    if (result != null && result is Map<String, dynamic>) {
      final gameResult = GameResult(
        difficulty: _selectedDifficulty,
        dateTime: DateTime.now(),
        timeSpentSeconds: result['timeSpentSeconds'],
        correct: result['correct'],
        total: result['total'],
        bonusAvailable: result['bonusAvailable'],
        bonusSolved: result['bonusSolved'],
        experienceEarned: result['experienceEarned'],
        attempts: List<WordAttempt>.from(result['attempts']),
      );
      PlayerData().addGameResult(gameResult);
      if (gameResult.experienceEarned > 0) {
        PlayerData().addExperience(gameResult.experienceEarned);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerData();
    final color = _difficultyColor(_selectedDifficulty);
    final avatar = player.avatarBytes != null
        ? CircleAvatar(radius: 40, backgroundImage: MemoryImage(player.avatarBytes!))
        : CircleAvatar(radius: 40, backgroundColor: Colors.grey,
            child: const Icon(Icons.person, size: 48, color: Colors.white));

    const double playAndDifficultySize = 96.0;
    const double gap = 8.0;
    const double modeButtonSize = playAndDifficultySize * 2 + gap;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Card(
              elevation: 4,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(player.nickname,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Уровень: ${player.level}', style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: player.progress),
                          Text(
                            '${player.experienceInCurrentLevel} / ${player.experienceForNextLevel} XP',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: modeButtonSize,
                      height: modeButtonSize,
                      child: ElevatedButton(
                        onPressed: _showModeSelection,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(modeButtonSize, modeButtonSize),
                        ),
                        child: const Text('Режим', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: playAndDifficultySize,
                          height: playAndDifficultySize,
                          child: ElevatedButton(
                            onPressed: _startGame,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, playAndDifficultySize),
                            ),
                            child: const Icon(Icons.play_arrow, size: 48),  // треугольник вправо
                          ),
                        ),
                        const SizedBox(width: gap),
                        SizedBox(
                          width: playAndDifficultySize,
                          height: playAndDifficultySize,
                          child: ElevatedButton(
                            onPressed: _showDifficultyDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: const Size(0, playAndDifficultySize),
                            ),
                            child: Text(
                              _selectedDifficulty[0].toUpperCase() + _selectedDifficulty.substring(1),
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}