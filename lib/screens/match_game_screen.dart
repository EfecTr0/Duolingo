import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/words.dart';
import '../data/player.dart';
import '../main.dart' show playCorrectSound, playIncorrectSound, playFinishSound, switchBackgroundMusic;

class MatchGameScreen extends StatefulWidget {
  final String difficulty;
  const MatchGameScreen({Key? key, required this.difficulty}) : super(key: key);

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen> {
  late List<Word> _words; // текущие английские слова
  late List<String> _russianTranslations;
  late int _totalSets;
  int _currentSet = 0;
  int _correctInSet = 0;
  int _totalCorrect = 0;
  int _attemptsLeftInSet = 2;
  String? _selectedEnglishWord;
  bool _gameOver = false;
  late DateTime _startTime;
  int _timeSpentSeconds = 0;

  // Для хранения статуса каждого слова (из исходного набора раунда)
  Map<String, String> _matchStatus = {}; // english -> 'correct', 'incorrect', 'unanswered'
  List<Word> _initialWords = [];

  // Частицы
  OverlayEntry? _particleOverlay;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _totalSets = 4 + math.Random().nextInt(3); // 4–6
    _generateSet();
  }

  void _generateSet() {
    final random = math.Random();
    final allWords = getWordsForDifficulty(widget.difficulty);
    if (allWords.length < 5) {
      _finishGame();
      return;
    }
    allWords.shuffle(random);
    _words = allWords.take(5).toList();
    _initialWords = List.from(_words);
    _russianTranslations = _words.map((w) => w.russian).toList();
    _russianTranslations.shuffle(random);
    _selectedEnglishWord = null;
    _correctInSet = 0;
    _attemptsLeftInSet = 2;
    _matchStatus = {for (var w in _words) w.english: 'unanswered'};
  }

  void _onEnglishTap(String english) {
    if (_gameOver || _attemptsLeftInSet <= 0) return;
    setState(() {
      _selectedEnglishWord = english;
    });
  }

  void _onRussianTap(String russian) {
    if (_gameOver || _attemptsLeftInSet <= 0 || _selectedEnglishWord == null) return;
    final selectedWord = _words.firstWhere((w) => w.english == _selectedEnglishWord);
    if (selectedWord.russian == russian) {
      playCorrectSound();
      // Добавляем слово в коллекцию
      PlayerData().addOrUpdateWord(selectedWord.english, selectedWord.russian, widget.difficulty, true);
      setState(() {
        _matchStatus[selectedWord.english] = 'correct';
        _words.remove(selectedWord);
        _russianTranslations.remove(russian);
        _correctInSet++;
        _totalCorrect++;
        _selectedEnglishWord = null;
      });
      _showParticles(isCorrect: true);
      if (_words.isEmpty) {
        _nextSet();
      }
    } else {
      playIncorrectSound();
      // Добавляем слово в коллекцию как неправильное
      PlayerData().addOrUpdateWord(selectedWord.english, selectedWord.russian, widget.difficulty, false);
      // Помечаем выбранное слово как неправильное (если ещё не correct)
      if (_matchStatus[_selectedEnglishWord] != 'correct') {
        _matchStatus[_selectedEnglishWord!] = 'incorrect';
      }
      _attemptsLeftInSet--;
      _showParticles(isCorrect: false);
      if (_attemptsLeftInSet <= 0) {
        _nextSet();
      }
      setState(() {});
    }
  }

  void _nextSet() {
    if (_currentSet < _totalSets - 1) {
      setState(() {
        _currentSet++;
        _generateSet();
      });
    } else {
      _finishGame();
    }
  }

  void _finishGame() {
    if (_gameOver) return;
    _timeSpentSeconds = DateTime.now().difference(_startTime).inSeconds;
    playFinishSound();
    switchBackgroundMusic('finish');
    setState(() => _gameOver = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog());
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
    return (_totalCorrect / (_totalSets * 5) * baseExp * _totalSets).round();
  }

  void _showResultDialog() {
    final exp = _calculateExperience();
    final timeString = '${_timeSpentSeconds ~/ 60}:${(_timeSpentSeconds % 60).toString().padLeft(2, '0')}';
    final percent = _totalCorrect / (_totalSets * 5) * 100;

    List<Widget> pairWidgets = [];
    for (var word in _initialWords) {
      String status = _matchStatus[word.english] ?? 'unanswered';
      Color borderColor;
      if (status == 'correct') borderColor = Colors.green;
      else if (status == 'incorrect') borderColor = Colors.red;
      else borderColor = Colors.blue;
      pairWidgets.add(
        Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(child: Text(word.english, style: TextStyle(fontWeight: FontWeight.bold))),
              Icon(Icons.arrow_forward, size: 16),
              Expanded(child: Text(word.russian)),
            ],
          ),
        ),
      );
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Результат', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(Icons.star, '${percent.round()}%', 'Точность', Colors.blue),
                      _buildStat(Icons.access_time, timeString, 'Время', Colors.purple),
                      _buildStat(Icons.emoji_events, '$exp', 'Опыт', Colors.amber),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Детали последнего раунда', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ...pairWidgets,
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context, {
                        'correct': _totalCorrect,
                        'total': _totalSets * 5,
                        'bonusAvailable': false,
                        'bonusSolved': false,
                        'experienceEarned': exp,
                        'attempts': [],
                        'timeSpentSeconds': _timeSpentSeconds,
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

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  void dispose() {
    _removeParticles();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Сопоставление – ${widget.difficulty}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(8),
          child: LinearProgressIndicator(value: _currentSet / _totalSets),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _gameOver
            ? const Center(child: Text('Игра завершена!', style: TextStyle(fontSize: 22)))
            : Padding(
                key: ValueKey(_currentSet),
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(child: _buildColumn(true)),
                    const SizedBox(width: 40),
                    Expanded(child: _buildColumn(false)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildColumn(bool isEnglish) {
    final items = isEnglish ? _words.map((w) => w.english).toList() : _russianTranslations;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((text) {
        final selected = isEnglish && text == _selectedEnglishWord;
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

// Частицы
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