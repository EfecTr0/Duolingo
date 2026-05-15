import 'dart:math';
import 'package:flutter/material.dart';
import '../data/words.dart';
import '../main.dart' show playCorrectSound, playIncorrectSound, playFinishSound, switchBackgroundMusic;

class GameScreen extends StatefulWidget {
  final String difficulty;
  const GameScreen({Key? key, required this.difficulty}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late List<Word> _words;
  late int _totalCards;
  bool _bonusRound = false;
  Word? _bonusWord;
  bool _bonusSolved = false;

  int _currentIndex = 0;
  final TextEditingController _answerController = TextEditingController();
  int _attemptsLeft = 2;
  String _feedback = '';
  int _correctCount = 0;
  bool _gameOver = false;
  bool _showingCorrectAnswer = false;

  late DateTime _startTime;
  int _timeSpentSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _startTime = DateTime.now();
  }

  void _initializeGame() {
    final random = Random();
    int minCards, maxCards;
    switch (widget.difficulty) {
      case 'лёгкий':
        minCards = 5; maxCards = 6; break;
      case 'средний':
        minCards = 6; maxCards = 7; break;
      case 'сложный':
        minCards = 7; maxCards = 8; break;
      case 'носитель':
        minCards = 8; maxCards = 8; break;
      default:
        minCards = 5; maxCards = 5;
    }
    _totalCards = minCards + random.nextInt(maxCards - minCards + 1);

    final allWords = getWordsForDifficulty(widget.difficulty);
    allWords.shuffle(random);
    _words = allWords.take(_totalCards).toList();
  }

  void _checkAnswer() {
    if (_gameOver || _showingCorrectAnswer) return;
    final userAnswer = _answerController.text.trim().toLowerCase();
    final correctAnswer = (_bonusRound ? _bonusWord!.russian : _words[_currentIndex].russian).toLowerCase();

    if (userAnswer == correctAnswer) {
      setState(() {
        _feedback = 'Правильно!';
        if (_bonusRound) {
          _bonusSolved = true;
        } else {
          _correctCount++;
        }
      });
      playCorrectSound();
      _nextCard();
    } else {
      _attemptsLeft--;
      playIncorrectSound();
      if (_attemptsLeft > 0) {
        setState(() {
          _feedback = 'Неправильно. Осталось попыток: $_attemptsLeft';
        });
      } else {
        setState(() {
          _feedback = 'Правильный ответ: $correctAnswer';
          _showingCorrectAnswer = true;
        });
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) _nextCard();
        });
      }
    }
  }

  void _nextCard() {
    if (!_bonusRound && _currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _attemptsLeft = 2;
        _answerController.clear();
        _feedback = '';
        _showingCorrectAnswer = false;
      });
      return;
    }

    if (!_bonusRound) {
      if (_correctCount == _words.length && widget.difficulty != 'носитель') {
        String nextDifficulty;
        switch (widget.difficulty) {
          case 'лёгкий': nextDifficulty = 'средний'; break;
          case 'средний': nextDifficulty = 'сложный'; break;
          case 'сложный': nextDifficulty = 'носитель'; break;
          default: nextDifficulty = 'носитель';
        }
        final bonusWords = getWordsForDifficulty(nextDifficulty);
        if (bonusWords.isNotEmpty) {
          bonusWords.shuffle();
          setState(() {
            _bonusRound = true;
            _bonusWord = bonusWords.first;
            _attemptsLeft = 2;
            _answerController.clear();
            _feedback = '';
            _showingCorrectAnswer = false;
          });
          return;
        }
      } else if (_correctCount == _words.length && widget.difficulty == 'носитель') {
        final bonusWords = getWordsForDifficulty('носитель');
        bonusWords.shuffle();
        setState(() {
          _bonusRound = true;
          _bonusWord = bonusWords.first;
          _attemptsLeft = 2;
          _answerController.clear();
          _feedback = '';
          _showingCorrectAnswer = false;
        });
        return;
      }
    }

    // Игра завершена
    _timeSpentSeconds = DateTime.now().difference(_startTime).inSeconds;
    playFinishSound();
    switchBackgroundMusic('finish');
    setState(() => _gameOver = true);
    _showResultDialog();
  }

  void _showResultDialog() {
    final percent = (_totalCards > 0) ? (_correctCount / _totalCards) : 0.0;
    String praise;
    if (percent >= 0.9) {
      praise = 'Потрясающе!';
    } else if (percent >= 0.7) {
      praise = 'Отлично!';
    } else if (percent >= 0.5) {
      praise = 'Хорошо!';
    } else {
      praise = 'Продолжай стараться!';
    }

    final timeString = '${_timeSpentSeconds ~/ 60}:${(_timeSpentSeconds % 60).toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                praise,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.star,
                    value: '${(percent * 100).round()}%',
                    label: 'Точность',
                    color: Colors.blue,
                  ),
                  _buildStatItem(
                    icon: Icons.access_time,
                    value: timeString,
                    label: 'Время',
                    color: Colors.purple,
                  ),
                  _buildStatItem(
                    icon: Icons.emoji_events,
                    value: '${(percent * 100).round()}%',
                    label: 'Опыт',
                    color: Colors.amber,
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, {
                    'correct': _correctCount,
                    'total': _totalCards,
                    'bonusAvailable': _bonusRound,
                    'bonusSolved': _bonusSolved,
                  });
                },
                icon: Icon(Icons.exit_to_app),
                label: Text('В главное меню'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalProgress = _totalCards + (_bonusRound ? 1 : 0);
    int currentProgress = _bonusRound
        ? _totalCards + (_bonusSolved ? 1 : 0)
        : _currentIndex;
    if (_gameOver) currentProgress = totalProgress;

    double progress = totalProgress > 0 ? currentProgress / totalProgress : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Игра – ${widget.difficulty}'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(8.0),
          child: LinearProgressIndicator(value: progress),
        ),
      ),
      body: _gameOver
          ? Center(child: Text('Игра завершена!', style: TextStyle(fontSize: 22)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_bonusRound) ...[
                    Text('Повышенный уровень!',
                        style: TextStyle(fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange)),
                    SizedBox(height: 20),
                  ],
                  Text('Переведите слово:', style: TextStyle(fontSize: 20)),
                  SizedBox(height: 20),
                  Text(
                    _bonusRound ? _bonusWord!.english : _words[_currentIndex].english,
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 30),
                  TextField(
                    controller: _answerController,
                    decoration: InputDecoration(
                      hintText: 'Введите перевод',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_showingCorrectAnswer && !_gameOver,
                    onSubmitted: (_) => _checkAnswer(),
                  ),
                  SizedBox(height: 10),
                  Text(
                    _feedback,
                    style: TextStyle(
                      color: _feedback.startsWith('Правильно') ? Colors.green : Colors.red,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: (_showingCorrectAnswer || _gameOver) ? null : _checkAnswer,
                    child: Text('Проверить'),
                  ),
                ],
              ),
            ),
    );
  }
}