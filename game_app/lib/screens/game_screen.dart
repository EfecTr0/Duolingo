import 'dart:async';
import 'dart:math' as math;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../data/words.dart';
import '../data/player.dart';
import '../main.dart' show playCorrectSound, playIncorrectSound, playFinishSound, switchBackgroundMusic,
    startSpeechRecognition, stopSpeechRecognition;

class GameScreen extends StatefulWidget {
  final String difficulty;
  const GameScreen({Key? key, required this.difficulty}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
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

  final List<WordAttempt> _attemptsHistory = [];   // ← история попыток
  bool _isListening = false;

  late AnimationController _scaleController;
  late AnimationController _wordFadeController;
  late Animation<double> _wordFadeAnimation;
  String _displayedWord = '';

  OverlayEntry? _particleOverlay;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _wordFadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _wordFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_wordFadeController);

    _initializeGame();
    _startTime = DateTime.now();

    if (_words.isEmpty) {
      _gameOver = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context, {
          'correct': 0, 'total': 0, 'bonusAvailable': false, 'bonusSolved': false,
          'experienceEarned': 0, 'timeSpentSeconds': 0, 'attempts': []
        });
      });
      return;
    }
    _displayedWord = _words[_currentIndex].english;

    js.context['onSpeechResult'] = (String transcript) {
      if (!mounted) return;
      setState(() {
        _answerController.text = transcript;
        _isListening = false;
      });
    };
  }

  void _initializeGame() {
    final random = math.Random();
    int minCards, maxCards;
    switch (widget.difficulty) {
      case 'лёгкий': minCards = 8; maxCards = 9; break;
      case 'средний': minCards = 9; maxCards = 10; break;
      case 'сложный': minCards = 10; maxCards = 11; break;
      case 'носитель': minCards = 11; maxCards = 11; break;
      default: minCards = 8; maxCards = 11; break;
    }
    _totalCards = minCards + random.nextInt(maxCards - minCards + 1);

    final allWords = getWordsForDifficulty(widget.difficulty);
    if (allWords.isEmpty) {
      _words = [];
      return;
    }
    if (allWords.length < _totalCards) {
      _totalCards = allWords.length;
    }
    allWords.shuffle(random);
    _words = allWords.take(_totalCards).toList();
  }

  void _toggleListening() {
    if (_isListening) {
      stopSpeechRecognition();
      setState(() => _isListening = false);
    } else {
      startSpeechRecognition('ru-RU', 'onSpeechResult');
      setState(() => _isListening = true);
    }
  }

  void _checkAnswer() {
    if (_gameOver || _showingCorrectAnswer) return;
    final userAnswer = _answerController.text.trim().toLowerCase();
    final correctAnswer = (_bonusRound ? _bonusWord!.russian : _words[_currentIndex].russian).toLowerCase();

    _scaleController.forward().then((_) => _scaleController.reverse());

    if (userAnswer == correctAnswer) {
      setState(() {
        _feedback = 'Правильно!';
        if (_bonusRound) _bonusSolved = true;
        else _correctCount++;
      });
      playCorrectSound();
      _saveAttempt(userAnswer, true);
      _showParticles(isCorrect: true);
      _animateToNextWord();
    } else {
      _attemptsLeft--;
      playIncorrectSound();
      if (_attemptsLeft > 0) {
        setState(() => _feedback = 'Неправильно. Осталось попыток: $_attemptsLeft');
        _showParticles(isCorrect: false);
      } else {
        setState(() {
          _feedback = 'Правильный ответ: $correctAnswer';
          _showingCorrectAnswer = true;
        });
        _saveAttempt(null, false);
        _showParticles(isCorrect: false);
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) _nextCard();
        });
      }
    }
  }

  void _saveAttempt(String? answer, bool isCorrect) {
    final word = _bonusRound ? _bonusWord! : _words[_currentIndex];
    _attemptsHistory.add(WordAttempt(
      english: word.english,
      correctRussian: word.russian,
      userAnswer: answer,
      isCorrect: isCorrect,
    ));
  }

  void _animateToNextWord() {
    _wordFadeController.forward().then((_) {
      if (_bonusRound) {
        _finishGame();
        return;
      }
      _nextCard();
      _wordFadeController.reverse();
    });
  }

  void _nextCard() {
    if (!_bonusRound && _currentIndex < _words.length - 1) {
      setState(() {
        _currentIndex++;
        _attemptsLeft = 2;
        _answerController.clear();
        _feedback = '';
        _showingCorrectAnswer = false;
        _displayedWord = _words[_currentIndex].english;
      });
      _wordFadeController.reset();
      return;
    }

    if (!_bonusRound) {
      if (_correctCount == _words.length && widget.difficulty != 'носитель' && widget.difficulty != 'случайная') {
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
            _displayedWord = _bonusWord!.english;
            _attemptsLeft = 2;
            _answerController.clear();
            _feedback = '';
            _showingCorrectAnswer = false;
          });
          _wordFadeController.reset();
          return;
        }
      } else if (_correctCount == _words.length && widget.difficulty == 'носитель') {
        final bonusWords = getWordsForDifficulty('носитель');
        if (bonusWords.isNotEmpty) {
          bonusWords.shuffle();
          setState(() {
            _bonusRound = true;
            _bonusWord = bonusWords.first;
            _displayedWord = _bonusWord!.english;
            _attemptsLeft = 2;
            _answerController.clear();
            _feedback = '';
            _showingCorrectAnswer = false;
          });
          _wordFadeController.reset();
          return;
        }
      }
    }

    _finishGame();
  }

  void _finishGame() {
    if (_gameOver) return;
    _timeSpentSeconds = DateTime.now().difference(_startTime).inSeconds;
    playFinishSound();
    switchBackgroundMusic('finish');
    setState(() => _gameOver = true);
    _showResultDialog();
  }

  void _showParticles({required bool isCorrect}) {
    _removeParticles();
    final screenSize = MediaQuery.of(context).size;
    _particleOverlay = OverlayEntry(
      builder: (context) => ParticleEffect(isCorrect: isCorrect, screenSize: screenSize));
    Overlay.of(context)!.insert(_particleOverlay!);
    Future.delayed(const Duration(seconds: 1, milliseconds: 500), _removeParticles);
  }

  void _removeParticles() {
    _particleOverlay?.remove();
    _particleOverlay = null;
  }

  int _calculateExperience() {
    int baseExp;
    switch (widget.difficulty) {
      case 'лёгкий': baseExp = 10; break;
      case 'средний': baseExp = 20; break;
      case 'сложный': baseExp = 30; break;
      case 'носитель': baseExp = 50; break;
      default: baseExp = 15; break;
    }
    double percent = _totalCards > 0 ? _correctCount / _totalCards : 0.0;
    int exp = (baseExp * percent).round();
    if (_bonusAvailable && _bonusSolved) exp += (baseExp * 0.3).round();
    return exp;
  }

  bool get _bonusAvailable => (_correctCount == _words.length && widget.difficulty != 'случайная');

  void _showResultDialog() {
    final int experienceEarned = _calculateExperience();
    final double percent = _totalCards > 0 ? _correctCount / _totalCards : 0.0;
    String praise;
    if (percent >= 0.9) praise = 'Потрясающе!';
    else if (percent >= 0.7) praise = 'Отлично!';
    else if (percent >= 0.5) praise = 'Хорошо!';
    else praise = 'Продолжай стараться!';

    final timeString = '${_timeSpentSeconds ~/ 60}:${(_timeSpentSeconds % 60).toString().padLeft(2, '0')}';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(praise, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                  SizedBox(height: 20),
                  AnimatedStatRow(percent: percent, timeSpentSeconds: _timeSpentSeconds, experienceEarned: experienceEarned),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, {
                        'correct': _correctCount,
                        'total': _totalCards,
                        'bonusAvailable': _bonusAvailable,
                        'bonusSolved': _bonusSolved,
                        'experienceEarned': experienceEarned,
                        'timeSpentSeconds': _timeSpentSeconds,
                        'attempts': _attemptsHistory.map((a) => {
                          'english': a.english,
                          'correctRussian': a.correctRussian,
                          'userAnswer': a.userAnswer,
                          'isCorrect': a.isCorrect,
                        }).toList(),
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
      },
    );
  }

  @override
  void dispose() {
    _answerController.dispose();
    if (_isListening) stopSpeechRecognition();
    _scaleController.dispose();
    _wordFadeController.dispose();
    _removeParticles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int totalProgress = _totalCards + (_bonusRound ? 1 : 0);
    int currentProgress = _bonusRound ? _totalCards + (_bonusSolved ? 1 : 0) : _currentIndex;
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_bonusRound) ...[
                    Text('Повышенный уровень!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
                    SizedBox(height: 20),
                  ],
                  ListenableBuilder(
                    listenable: _scaleController,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (_scaleController.value * 0.05),
                      child: child,
                    ),
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.blueGrey.withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        child: Column(
                          children: [
                            Text('Переведи слово:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.blueGrey[800])),
                            SizedBox(height: 12),
                            ListenableBuilder(
                              listenable: _wordFadeController,
                              builder: (context, child) => Opacity(
                                opacity: _wordFadeAnimation.value,
                                child: Text(_displayedWord,
                                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87,
                                        shadows: [BoxShadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)])),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 360),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _answerController,
                              decoration: InputDecoration(
                                hintText: 'Введите перевод',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              enabled: !_showingCorrectAnswer && !_gameOver,
                              onSubmitted: (_) => _checkAnswer(),
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            width: 56, height: 56,
                            child: ElevatedButton(
                              onPressed: (_showingCorrectAnswer || _gameOver) ? null : _toggleListening,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: EdgeInsets.zero,
                              ),
                              child: _isListening
                                  ? Icon(Icons.more_horiz, color: Colors.white, size: 32)
                                  : Icon(Icons.mic, color: Colors.white, size: 32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(_feedback, style: TextStyle(color: _feedback.startsWith('Правильно') ? Colors.green : Colors.red, fontSize: 18)),
                  SizedBox(height: 20),
                  SizedBox(
                    width: 160, height: 56,
                    child: ElevatedButton(
                      onPressed: (_showingCorrectAnswer || _gameOver) ? null : _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      child: Text('Проверить'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ... остальные классы (AnimatedStatRow, ParticleEffect, _Particle) без изменений

// =================== ВИДЖЕТ АНИМИРОВАННОЙ СТАТИСТИКИ ===================
class AnimatedStatRow extends StatefulWidget {
  final double percent;
  final int timeSpentSeconds;
  final int experienceEarned;
  const AnimatedStatRow({
    Key? key,
    required this.percent,
    required this.timeSpentSeconds,
    required this.experienceEarned,
  }) : super(key: key);

  @override
  State<AnimatedStatRow> createState() => _AnimatedStatRowState();
}

class _AnimatedStatRowState extends State<AnimatedStatRow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _AnimatedCounter(
          animation: _animation,
          icon: Icons.star,
          value: (widget.percent * 100).toInt(),
          suffix: '%',
          label: 'Точность',
          color: Colors.blue,
        ),
        _AnimatedTimeCounter(
          animation: _animation,
          totalSeconds: widget.timeSpentSeconds,
          color: Colors.purple,
        ),
        _AnimatedCounter(
          animation: _animation,
          icon: Icons.emoji_events,
          value: widget.experienceEarned,
          label: 'Опыт',
          color: Colors.amber,
        ),
      ],
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  final Animation<double> animation;
  final IconData icon;
  final int value;
  final String? suffix;
  final String label;
  final Color color;
  const _AnimatedCounter({
    required this.animation,
    required this.icon,
    required this.value,
    this.suffix,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: animation,
      builder: (context, child) {
        final currentValue = (value * animation.value).toInt();
        return Column(
          children: [
            Icon(icon, color: color, size: 32),
            Text(
              '$currentValue${suffix ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
      },
    );
  }
}

class _AnimatedTimeCounter extends StatelessWidget {
  final Animation<double> animation;
  final int totalSeconds;
  final Color color;
  const _AnimatedTimeCounter({
    required this.animation,
    required this.totalSeconds,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: animation,
      builder: (context, child) {
        final currentSeconds = (totalSeconds * animation.value).toInt();
        final minutes = currentSeconds ~/ 60;
        final seconds = currentSeconds % 60;
        final timeStr = '${minutes}:${seconds.toString().padLeft(2, '0')}';
        return Column(
          children: [
            Icon(Icons.access_time, color: color, size: 32),
            Text(timeStr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text('Время', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
      },
    );
  }
}

// =================== ЭФФЕКТ ЧАСТИЦ ===================
class ParticleEffect extends StatefulWidget {
  final bool isCorrect;
  final Size screenSize;
  const ParticleEffect({Key? key, required this.isCorrect, required this.screenSize}) : super(key: key);

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _generateParticles();
    _controller.forward();
  }

  void _generateParticles() {
    final w = widget.screenSize.width;
    final h = widget.screenSize.height;
    for (int i = 0; i < 30; i++) {
      final isLeft = _random.nextBool();
      final size = 20.0 + _random.nextDouble() * 20;
      final offset = Offset(
        isLeft ? -size - _random.nextDouble() * 50 : w + size + _random.nextDouble() * 50,
        _random.nextDouble() * h,
      );
      final velocity = Offset(
        isLeft ? (1.0 + _random.nextDouble() * 1.5) : -(1.0 + _random.nextDouble() * 1.5),
        (_random.nextDouble() - 0.5) * 1.0,
      );
      final color = widget.isCorrect
          ? Color.fromARGB(255, 50 + _random.nextInt(100), 150 + _random.nextInt(100), 50)
          : Color.fromARGB(255, 200 + _random.nextInt(50), 50 + _random.nextInt(50), 50);
      _particles.add(_Particle(offset, size, velocity, color));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Stack(
          children: _particles.map((particle) {
            final left = particle.offset.dx + particle.velocity.dx * 120 * progress;
            final top = particle.offset.dy + particle.velocity.dy * 120 * progress;
            return Positioned(
              left: left,
              top: top,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - progress).clamp(0.0, 1.0),
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      color: particle.color.withOpacity(1 - progress),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _Particle {
  Offset offset;
  double size;
  Offset velocity;
  Color color;
  _Particle(this.offset, this.size, this.velocity, this.color);
}