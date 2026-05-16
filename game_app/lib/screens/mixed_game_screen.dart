import 'dart:math' as math;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import '../data/words.dart';
import '../main.dart' show playCorrectSound, playIncorrectSound, playFinishSound, switchBackgroundMusic,
    startSpeechRecognition, stopSpeechRecognition;

class MixedGameScreen extends StatefulWidget {
  final String difficulty;
  const MixedGameScreen({Key? key, required this.difficulty}) : super(key: key);

  @override
  State<MixedGameScreen> createState() => _MixedGameScreenState();
}

class _MixedGameScreenState extends State<MixedGameScreen> with TickerProviderStateMixin {
  int _currentRound = 0;
  final int _totalRounds = 8;
  int _totalCorrect = 0;
  int _totalQuestions = 0;
  int _totalExperience = 0;
  late DateTime _startTime;
  int _timeSpentSeconds = 0;
  bool _gameOver = false;

  bool _isCardRound = true;

  // Карточный раунд
  List<Word> _cardWords = [];
  int _cardIndex = 0;
  final TextEditingController _cardAnswerController = TextEditingController();
  int _cardAttemptsLeft = 2;
  String _cardFeedback = '';
  bool _cardShowingCorrectAnswer = false;
  bool _cardListening = false;
  late AnimationController _cardScaleController;
  late AnimationController _cardWordFadeController;
  late Animation<double> _cardWordFadeAnimation;
  OverlayEntry? _cardParticleOverlay;
  bool _cardRoundFailed = false;

  // Раунд сопоставления
  List<Word> _matchWords = [];
  List<String> _matchRussian = [];
  String? _selectedEnglish;
  int _matchCorrectInSet = 0;
  int _matchAttemptsLeft = 2;
  Map<String, String> _matchStatus = {};
  List<Word> _matchInitialWords = [];
  OverlayEntry? _matchParticleOverlay;

  // Результаты раундов
  int _cardRoundsSuccess = 0;
  int _cardRoundsFailed = 0;
  int _matchRoundsSuccess = 0;
  int _matchRoundsFailed = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _cardScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _cardWordFadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardWordFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_cardWordFadeController);

    js.context['mixedOnSpeechResult'] = (String transcript) {
      setState(() {
        _cardAnswerController.text = transcript;
        _cardListening = false;
      });
    };

    _nextRound();
  }

  void _nextRound() {
    if (_currentRound >= _totalRounds) {
      _finishGame();
      return;
    }
    setState(() {
      _isCardRound = math.Random().nextBool();
      _currentRound++;
      if (_isCardRound) {
        _initCardRound();
      } else {
        _initMatchRound();
      }
    });
  }

  // ---------- Карточный раунд ----------
  void _initCardRound() {
    final random = math.Random();
    final allWords = getWordsForDifficulty(widget.difficulty);
    if (allWords.length < 3) {
      _nextRound();
      return;
    }
    allWords.shuffle(random);
    _cardWords = allWords.take(3).toList();
    _cardIndex = 0;
    _cardAnswerController.clear();
    _cardAttemptsLeft = 2;
    _cardFeedback = '';
    _cardShowingCorrectAnswer = false;
    _cardRoundFailed = false;
    _cardWordFadeController.reset();
  }

  void _toggleCardListening() {
    if (_cardListening) {
      stopSpeechRecognition();
      setState(() => _cardListening = false);
    } else {
      startSpeechRecognition('ru-RU', 'mixedOnSpeechResult');
      setState(() => _cardListening = true);
    }
  }

  void _checkCardAnswer() {
    if (_cardShowingCorrectAnswer || _gameOver) return;
    final userAnswer = _cardAnswerController.text.trim().toLowerCase();
    final correctAnswer = _cardWords[_cardIndex].russian.toLowerCase();

    _cardScaleController.forward().then((_) => _cardScaleController.reverse());

    if (userAnswer == correctAnswer) {
      playCorrectSound();
      setState(() {
        _cardFeedback = 'Правильно!';
        _totalCorrect++;
        _totalQuestions++;
      });
      _showCardParticles(isCorrect: true);
      _animateCardToNextWord();
    } else {
      _cardAttemptsLeft--;
      playIncorrectSound();
      if (_cardAttemptsLeft > 0) {
        setState(() => _cardFeedback = 'Неправильно. Осталось попыток: $_cardAttemptsLeft');
        _showCardParticles(isCorrect: false);
      } else {
        setState(() {
          _cardFeedback = 'Правильный ответ: $correctAnswer';
          _cardShowingCorrectAnswer = true;
          _totalQuestions++;
          _cardRoundFailed = true;
        });
        _showCardParticles(isCorrect: false);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _advanceCard();
        });
      }
    }
  }

  void _animateCardToNextWord() {
    _cardWordFadeController.forward().then((_) {
      _advanceCard();
      _cardWordFadeController.reverse();
    });
  }

  void _advanceCard() {
    if (_cardIndex < _cardWords.length - 1) {
      setState(() {
        _cardIndex++;
        _cardAnswerController.clear();
        _cardAttemptsLeft = 2;
        _cardFeedback = '';
        _cardShowingCorrectAnswer = false;
      });
      _cardWordFadeController.reset();
    } else {
      if (_cardRoundFailed) _cardRoundsFailed++;
      else _cardRoundsSuccess++;
      _nextRound();
    }
  }

  void _showCardParticles({required bool isCorrect}) {
    _removeCardParticles();
    final screenSize = MediaQuery.of(context).size;
    _cardParticleOverlay = OverlayEntry(
      builder: (context) => ParticleEffect(isCorrect: isCorrect, screenSize: screenSize));
    Overlay.of(context)!.insert(_cardParticleOverlay!);
    Future.delayed(const Duration(seconds: 1, milliseconds: 500), _removeCardParticles);
  }

  void _removeCardParticles() {
    _cardParticleOverlay?.remove();
    _cardParticleOverlay = null;
  }

  // ---------- Раунд сопоставления ----------
  void _initMatchRound() {
    final random = math.Random();
    final allWords = getWordsForDifficulty(widget.difficulty);
    if (allWords.length < 4) {
      _nextRound();
      return;
    }
    allWords.shuffle(random);
    _matchWords = allWords.take(4).toList();
    _matchInitialWords = List.from(_matchWords);
    _matchRussian = _matchWords.map((w) => w.russian).toList();
    _matchRussian.shuffle(random);
    _selectedEnglish = null;
    _matchCorrectInSet = 0;
    _matchAttemptsLeft = 2;
    _matchStatus = {for (var w in _matchWords) w.english: 'unanswered'};
  }

  void _onEnglishTap(String english) {
    if (_gameOver || _matchAttemptsLeft <= 0) return;
    setState(() {
      _selectedEnglish = english;
    });
  }

  void _onRussianTap(String russian) {
    if (_gameOver || _matchAttemptsLeft <= 0 || _selectedEnglish == null) return;
    final selectedWord = _matchWords.firstWhere((w) => w.english == _selectedEnglish);
    if (selectedWord.russian == russian) {
      playCorrectSound();
      setState(() {
        _matchStatus[selectedWord.english] = 'correct';
        _matchWords.remove(selectedWord);
        _matchRussian.remove(russian);
        _matchCorrectInSet++;
        _totalCorrect++;
        _totalQuestions++;
        _selectedEnglish = null;
      });
      _showMatchParticles(isCorrect: true);
      if (_matchWords.isEmpty) {
        _endMatchRound(success: true);
      }
    } else {
      playIncorrectSound();
      if (_matchStatus[_selectedEnglish] != 'correct') {
        _matchStatus[_selectedEnglish!] = 'incorrect';
      }
      _matchAttemptsLeft--;
      _totalQuestions++;
      _showMatchParticles(isCorrect: false);
      if (_matchAttemptsLeft <= 0) {
        _endMatchRound(success: false);
      }
      setState(() {});
    }
  }

  void _endMatchRound({required bool success}) {
    if (success) _matchRoundsSuccess++;
    else _matchRoundsFailed++;
    _nextRound();
  }

  void _showMatchParticles({required bool isCorrect}) {
    _removeMatchParticles();
    final screenSize = MediaQuery.of(context).size;
    _matchParticleOverlay = OverlayEntry(
      builder: (context) => ParticleEffect(isCorrect: isCorrect, screenSize: screenSize));
    Overlay.of(context)!.insert(_matchParticleOverlay!);
    Future.delayed(const Duration(seconds: 1, milliseconds: 500), _removeMatchParticles);
  }

  void _removeMatchParticles() {
    _matchParticleOverlay?.remove();
    _matchParticleOverlay = null;
  }

  // ---------- Завершение ----------
  void _finishGame() {
    if (_gameOver) return;
    _timeSpentSeconds = DateTime.now().difference(_startTime).inSeconds;
    playFinishSound();
    switchBackgroundMusic('finish');
    setState(() => _gameOver = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog());
  }

  int _calculateExperience() {
    if (_totalQuestions == 0) return 0;
    final percent = _totalCorrect / _totalQuestions;
    return (15 * percent * _totalQuestions).round();
  }

  void _showResultDialog() {
    final int experienceEarned = _calculateExperience();
    final double percent = _totalQuestions > 0 ? _totalCorrect / _totalQuestions : 0.0;
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
                  const SizedBox(height: 20),
                  _AnimatedStatRow(percent: percent, timeSpentSeconds: _timeSpentSeconds, experienceEarned: experienceEarned),
                  const SizedBox(height: 20),
                  // Статистика по раундам
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRoundStat('📇', 'Карточки', _cardRoundsSuccess, _cardRoundsFailed),
                      _buildRoundStat('🔗', 'Сопоставление', _matchRoundsSuccess, _matchRoundsFailed),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, {
                        'correct': _totalCorrect,
                        'total': _totalQuestions,
                        'bonusAvailable': false,
                        'bonusSolved': false,
                        'experienceEarned': experienceEarned,
                        'attempts': [],
                        'timeSpentSeconds': _timeSpentSeconds,
                      });
                    },
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('В главное меню'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoundStat(String emoji, String label, int success, int failed) {
    return Column(
      children: [
        Text(emoji, style: TextStyle(fontSize: 32)),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$success', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold)),
            ),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$failed', style: TextStyle(color: Colors.red[800], fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _cardAnswerController.dispose();
    if (_cardListening) stopSpeechRecognition();
    _cardScaleController.dispose();
    _cardWordFadeController.dispose();
    _removeCardParticles();
    _removeMatchParticles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Смешанный режим – ${widget.difficulty}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8.0),
          child: LinearProgressIndicator(value: _currentRound / _totalRounds),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _gameOver
            ? const Center(child: Text('Игра завершена!', style: TextStyle(fontSize: 22)))
            : _isCardRound
                ? _buildCardRound(key: ValueKey('card$_currentRound'))
                : _buildMatchRound(key: ValueKey('match$_currentRound')),
      ),
    );
  }

  Widget _buildCardRound({Key? key}) {
    if (_cardWords.isEmpty) return const Center(child: CircularProgressIndicator());
    final word = _cardWords[_cardIndex];
    return Padding(
      key: key,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Раунд $_currentRound / $_totalRounds – Карточки', style: const TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: _cardScaleController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + (_cardScaleController.value * 0.05),
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
                    const Text('Переведи слово:', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                    const SizedBox(height: 12),
                    ListenableBuilder(
                      listenable: _cardWordFadeController,
                      builder: (context, child) => Opacity(
                        opacity: _cardWordFadeAnimation.value,
                        child: Text(
                          word.english,
                          style: const TextStyle(
                            fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87,
                            shadows: [BoxShadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cardAnswerController,
                      decoration: InputDecoration(
                        hintText: 'Введите перевод',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      enabled: !_cardShowingCorrectAnswer && !_gameOver,
                      onSubmitted: (_) => _checkCardAnswer(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56, height: 56,
                    child: ElevatedButton(
                      onPressed: (_cardShowingCorrectAnswer || _gameOver) ? null : _toggleCardListening,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _cardListening
                          ? const Icon(Icons.more_horiz, color: Colors.white, size: 32)
                          : const Icon(Icons.mic, color: Colors.white, size: 32),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(_cardFeedback, style: TextStyle(
            color: _cardFeedback.startsWith('Правильно') ? Colors.green : Colors.red, fontSize: 18)),
          const SizedBox(height: 20),
          SizedBox(
            width: 160, height: 56,
            child: ElevatedButton(
              onPressed: (_cardShowingCorrectAnswer || _gameOver) ? null : _checkCardAnswer,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              child: const Text('Проверить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchRound({Key? key}) {
    if (_matchWords.isEmpty) return const Center(child: CircularProgressIndicator());
    return Padding(
      key: key,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text('Раунд $_currentRound / $_totalRounds – Сопоставление', style: const TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildMatchColumn(true)),
                const SizedBox(width: 40),
                Expanded(child: _buildMatchColumn(false)),
              ],
            ),
          ),
          if (_matchAttemptsLeft < 2)
            Text('Осталось ошибок: $_matchAttemptsLeft', style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildMatchColumn(bool isEnglish) {
    final items = isEnglish ? _matchWords.map((w) => w.english).toList() : _matchRussian;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((text) {
        final selected = isEnglish && text == _selectedEnglish;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: GestureDetector(
            onTap: () => isEnglish ? _onEnglishTap(text) : _onRussianTap(text),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? Colors.blue[300] : Colors.blue[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue),
              ),
              child: Center(
                child: Text(text, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// =================== ВИДЖЕТЫ АНИМИРОВАННОЙ СТАТИСТИКИ ===================
class _AnimatedStatRow extends StatefulWidget {
  final double percent;
  final int timeSpentSeconds;
  final int experienceEarned;
  const _AnimatedStatRow({
    Key? key,
    required this.percent,
    required this.timeSpentSeconds,
    required this.experienceEarned,
  }) : super(key: key);

  @override
  State<_AnimatedStatRow> createState() => __AnimatedStatRowState();
}

class __AnimatedStatRowState extends State<_AnimatedStatRow> with SingleTickerProviderStateMixin {
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
        _AnimatedCounter(animation: _animation, icon: Icons.star, value: (widget.percent * 100).toInt(), suffix: '%', label: 'Точность', color: Colors.blue),
        _AnimatedTimeCounter(animation: _animation, totalSeconds: widget.timeSpentSeconds, color: Colors.purple),
        _AnimatedCounter(animation: _animation, icon: Icons.emoji_events, value: widget.experienceEarned, label: 'Опыт', color: Colors.amber),
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
            Text('$currentValue${suffix ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
    for (int i = 0; i < 60; i++) {
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