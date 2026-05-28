import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'match_game_screen.dart';
import 'mixed_game_screen.dart';
import '../data/player.dart';
import '../main.dart' show switchBackgroundMusic, playClickSound;

enum GameMode { cards, matching, mixed }

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> {
  String _selectedDifficulty = 'лёгкий';
  GameMode _selectedMode = GameMode.cards;

  void refresh() => setState(() {});

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

  String _difficultyEmoji(String difficulty) {
    switch (difficulty) {
      case 'лёгкий': return '😊';
      case 'средний': return '😁';
      case 'сложный': return '🤔';
      case 'носитель': return '😈';
      case 'случайная': return '🎲';
      default: return '❓';
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
              children: ['лёгкий', 'средний', 'сложный', 'носитель', 'случайная'].map((level) {
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
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Закрыть'))],
      ),
    );
  }

  void _showModeDialog() {
    playClickSound();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Выберите режим'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<GameMode>(
                  title: Text('Карточки'),
                  value: GameMode.cards,
                  groupValue: _selectedMode,
                  onChanged: (val) {
                    setDialogState(() => _selectedMode = val!);
                    setState(() {});
                  },
                ),
                RadioListTile<GameMode>(
                  title: Text('Сопоставление'),
                  value: GameMode.matching,
                  groupValue: _selectedMode,
                  onChanged: (val) {
                    setDialogState(() => _selectedMode = val!);
                    setState(() {});
                  },
                ),
                RadioListTile<GameMode>(
                  title: Text('Смешанный'),
                  value: GameMode.mixed,
                  groupValue: _selectedMode,
                  onChanged: (val) {
                    setDialogState(() => _selectedMode = val!);
                    setState(() {});
                  },
                ),
              ],
            );
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Закрыть'))],
      ),
    );
  }

  Future<void> _startGame() async {
    playClickSound();
    final musicType = (_selectedDifficulty == 'лёгкий' || _selectedDifficulty == 'средний')
        ? 'game_easy_medium'
        : 'game_hard_native';
    switchBackgroundMusic(musicType);

    Widget gameScreen;
    switch (_selectedMode) {
      case GameMode.cards:
        gameScreen = GameScreen(difficulty: _selectedDifficulty);
        break;
      case GameMode.matching:
        gameScreen = MatchGameScreen(difficulty: _selectedDifficulty);
        break;
      case GameMode.mixed:
        gameScreen = MixedGameScreen(difficulty: _selectedDifficulty);
        break;
    }

    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => gameScreen));
    switchBackgroundMusic('menu');

    if (result != null && result is Map<String, dynamic>) {
      final String modeStr = _selectedMode == GameMode.cards ? 'cards' : (_selectedMode == GameMode.matching ? 'matching' : 'mixed');
      final gameResult = GameResult(
        difficulty: _selectedDifficulty,
        dateTime: DateTime.now(),
        timeSpentSeconds: result['timeSpentSeconds'],
        correct: result['correct'],
        total: result['total'],
        bonusAvailable: result['bonusAvailable'] ?? false,
        bonusSolved: result['bonusSolved'] ?? false,
        experienceEarned: result['experienceEarned'],
        attempts: (result['attempts'] as List?)?.cast<WordAttempt>() ?? [],
        mode: modeStr,
        matchPairs: (result['matchPairs'] as List?)?.cast<MatchPair>(),
        roundDetails: (result['roundDetails'] as List?)?.cast<RoundDetail>(),
        cardRoundsSuccess: result['cardRoundsSuccess'],
        cardRoundsFailed: result['cardRoundsFailed'],
        matchRoundsSuccess: result['matchRoundsSuccess'],
        matchRoundsFailed: result['matchRoundsFailed'],
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
        : CircleAvatar(radius: 40, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 48, color: Colors.white));

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
                          Text(player.nickname, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Уровень: ${player.level}', style: TextStyle(fontSize: 18)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: player.progress),
                          Text('${player.experienceInCurrentLevel} / ${player.experienceForNextLevel} XP',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              height: 1,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                boxShadow: [BoxShadow(color: Colors.black12, offset: Offset(0, 1), blurRadius: 2)],
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
                        onPressed: _showModeDialog,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size(modeButtonSize, modeButtonSize),
                        ),
                        child: Text('Режим', style: TextStyle(fontSize: 20)),
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
                            child: const Icon(Icons.play_arrow, size: 48),
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
                            child: Text(_difficultyEmoji(_selectedDifficulty), style: TextStyle(fontSize: 32)),
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