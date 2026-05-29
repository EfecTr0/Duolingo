import 'dart:convert';
import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'match_game_screen.dart';
import 'mixed_game_screen.dart';
import '../api_service.dart';
import '../data/player.dart';
import '../main.dart' show switchBackgroundMusic, playClickSound, developerMode;

enum GameMode { cards, matching, mixed }

class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  State<MenuScreen> createState() => MenuScreenState();
}

class MenuScreenState extends State<MenuScreen> {
  String _selectedDifficulty = 'лёгкий';
  GameMode _selectedMode = GameMode.cards;

  // Параметры диалога разработчика
  double _devPercent = 1.0;
  bool _devBonus = false;

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
                  title: Text('Карточки'), value: GameMode.cards,
                  groupValue: _selectedMode,
                  onChanged: (val) {
                    setDialogState(() => _selectedMode = val!);
                    setState(() {});
                  },
                ),
                RadioListTile<GameMode>(
                  title: Text('Сопоставление'), value: GameMode.matching,
                  groupValue: _selectedMode,
                  onChanged: (val) {
                    setDialogState(() => _selectedMode = val!);
                    setState(() {});
                  },
                ),
                RadioListTile<GameMode>(
                  title: Text('Смешанный'), value: GameMode.mixed,
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

  /// Показывает диалог настройки результата для режима разработчика.
  Future<Map<String, dynamic>?> _showDeveloperDialog() async {
    double localPercent = _devPercent;
    bool localBonus = _devBonus;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Настройка результата (dev)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Процент правильных ответов: ${(localPercent * 100).round()}%'),
                Slider(
                  value: localPercent,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: (v) {
                    setDialogState(() => localPercent = v);
                  },
                ),
                SwitchListTile(
                  title: Text('Бонусный вопрос решён'),
                  value: localBonus,
                  onChanged: (v) {
                    setDialogState(() => localBonus = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, {
                    'percent': localPercent,
                    'bonus': localBonus,
                  });
                },
                child: Text('Применить'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _startGame() async {
    playClickSound();
    final musicType = (_selectedDifficulty == 'лёгкий' || _selectedDifficulty == 'средний')
        ? 'game_easy_medium'
        : 'game_hard_native';
    switchBackgroundMusic(musicType);

    String modeStr;
    switch (_selectedMode) {
      case GameMode.cards: modeStr = 'cards'; break;
      case GameMode.matching: modeStr = 'matching'; break;
      case GameMode.mixed: modeStr = 'mixed'; break;
    }

    if (developerMode) {
      final settings = await _showDeveloperDialog();
      if (settings == null) {
        switchBackgroundMusic('menu');
        return;
      }
      final double percent = settings['percent'] as double;
      final bool bonus = settings['bonus'] as bool;
      _devPercent = percent;
      _devBonus = bonus;

      // Генерируем результат, как в обычной игре (берём 10 вопросов)
      final int total = 10;
      final int correct = (total * percent).round();
      final int exp = _calculateExperience(_selectedDifficulty, total, correct, bonus);
      _processGameResult({
        'correct': correct,
        'total': total,
        'bonusAvailable': bonus,
        'bonusSolved': bonus,
        'experienceEarned': exp,
        'timeSpentSeconds': 0,
        'attempts': [],
      }, modeStr);
      return;
    }

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
      _processGameResult(result, modeStr);
    }
  }

  void _processGameResult(Map<String, dynamic> result, String modeStr) async {
    final int correct = result['correct'] ?? 0;
    final int total = result['total'] ?? 0;
    final int experienceEarned = result['experienceEarned'] ?? 0;

    if (experienceEarned > 0) {
      await PlayerData().addExperience(experienceEarned);
    }

    PlayerData().onGameCompleted(modeStr, _selectedDifficulty, correct, total);

    try {
      await ApiService.addGameHistory({
        'difficulty': _selectedDifficulty,
        'mode': modeStr,
        'date_time': DateTime.now().toIso8601String(),
        'time_spent_seconds': result['timeSpentSeconds'] ?? 0,
        'correct': correct,
        'total': total,
        'bonus_available': result['bonusAvailable'] ?? false,
        'bonus_solved': result['bonusSolved'] ?? false,
        'experience_earned': experienceEarned,
        'attempts_json': jsonEncode(result['attempts'] ?? []),
        'match_pairs_json': result['matchPairs'] != null ? jsonEncode(result['matchPairs']) : null,
        'round_details_json': result['roundDetails'] != null ? jsonEncode(result['roundDetails']) : null,
      });
    } catch (e) {
      debugPrint('Failed to send game history: $e');
    }

    setState(() {});
  }

  int _calculateExperience(String difficulty, int total, int correct, bool bonusSolved) {
    int baseExp;
    switch (difficulty) {
      case 'лёгкий': baseExp = 10; break;
      case 'средний': baseExp = 20; break;
      case 'сложный': baseExp = 30; break;
      case 'носитель': baseExp = 50; break;
      default: baseExp = 15; break;
    }
    double percent = total > 0 ? correct / total : 0.0;
    int exp = (baseExp * percent * total).round();
    if (bonusSolved) {
      exp += (baseExp * 0.3).round();
    }
    return exp;
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