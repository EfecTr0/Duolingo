import 'dart:async';
import 'dart:convert';
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../data/player.dart';
import '../data/words.dart';
import '../main.dart' show startSpeechRecognition, stopSpeechRecognition, switchBackgroundMusic,
    playFinishSound, playClickSound;

class PvPGameScreen extends StatefulWidget {
  final String sessionId;
  const PvPGameScreen({Key? key, required this.sessionId}) : super(key: key);

  @override
  State<PvPGameScreen> createState() => _PvPGameScreenState();
}

class _PvPGameScreenState extends State<PvPGameScreen> with TickerProviderStateMixin {
  String _state = 'loading';
  Map<String, dynamic>? _gameData;
  Timer? _pollTimer;
  final TextEditingController _answerController = TextEditingController();
  bool _networkError = false;

  // Выбор слов
  bool _wordsSubmitted = false;
  Set<String> _selectedWords = {};

  // Игровой процесс
  List<String> _currentRoundWords = [];
  int _currentWordIndex = 0;
  List<String> _currentRoundAnswers = [];
  bool _roundAnswersSubmitted = false;
  bool _isListening = false;

  // Хранение истории раундов для подсчёта результатов
  final List<RoundData> _roundsHistory = [];

  // Анимации
  late AnimationController _vsAnimController1;
  late AnimationController _vsAnimController2;
  late Animation<Offset> _vsOffset1;
  late Animation<Offset> _vsOffset2;
  bool _vsAnimationStarted = false;

  @override
  void initState() {
    super.initState();
    switchBackgroundMusic('game_easy_medium');
    _vsAnimController1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _vsAnimController2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _vsOffset1 = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(_vsAnimController1);
    _vsOffset2 = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(_vsAnimController2);

    _startPolling();
    js.context['pvpSpeechResult'] = (String transcript) {
      if (!mounted) return;
      setState(() {
        _answerController.text = transcript;
        _isListening = false;
      });
    };
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchGameState());
  }

  Future<void> _fetchGameState() async {
    if (_networkError) return;
    try {
      final data = await ApiService.getGameState(widget.sessionId);
      if (!mounted) return;
      setState(() {
        final prevState = _state;
        _gameData = data;
        final newState = data['state'] ?? 'waiting';

        // Сброс при входе в words_select
        if (newState == 'words_select' && prevState != 'words_select') {
          _wordsSubmitted = false;
          _selectedWords = {};
        }

        // Новый раунд
        if (newState == 'playing' && prevState != 'playing') {
          _currentWordIndex = 0;
          _currentRoundAnswers = [];
          _roundAnswersSubmitted = false;
          final opponentSelected = List<String>.from(data['opponent_selected'] ?? []);
          if (opponentSelected.isNotEmpty) {
            _currentRoundWords = opponentSelected;
            _roundsHistory.add(RoundData(opponentWords: opponentSelected));
          }
        }

        // Запуск анимации VS
        if (newState == 'accepted' && !_vsAnimationStarted) {
          _vsAnimationStarted = true;
          _vsAnimController1.forward();
          _vsAnimController2.forward();
        }

        _state = newState;

        if (_state == 'finished') {
          _pollTimer?.cancel();
          playFinishSound();
          switchBackgroundMusic('finish');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _networkError = true);
      _pollTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка соединения: $e')),
      );
    }
  }

  void _toggleWord(String word) {
    if (_wordsSubmitted) return;
    playClickSound();
    setState(() {
      if (_selectedWords.contains(word)) {
        _selectedWords.remove(word);
      } else {
        if (_selectedWords.length < 3) {
          _selectedWords.add(word);
        }
      }
    });
  }

  void _submitSelectedWords() {
    if (_selectedWords.length != 3) return;
    playClickSound();
    _wordsSubmitted = true;
    ApiService.selectWords(widget.sessionId, _selectedWords.toList());
  }

  void _toggleListening() {
    playClickSound();
    if (_isListening) {
      stopSpeechRecognition();
      setState(() => _isListening = false);
    } else {
      startSpeechRecognition('ru-RU', 'pvpSpeechResult');
      setState(() => _isListening = true);
    }
  }

  void _onNextWord() {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    playClickSound();
    if (_currentWordIndex < _currentRoundWords.length - 1) {
      setState(() {
        _currentRoundAnswers.add(answer);
        _answerController.clear();
        _currentWordIndex++;
      });
    } else {
      _currentRoundAnswers.add(answer);
      _answerController.clear();
      _submitRoundAnswers();
    }
  }

  void _submitRoundAnswers() {
    if (_roundAnswersSubmitted) return;
    _roundAnswersSubmitted = true;
    if (_roundsHistory.isNotEmpty) {
      _roundsHistory.last.playerAnswers = List.from(_currentRoundAnswers);
    }
    ApiService.submitAnswer(widget.sessionId, List<String>.from(_currentRoundAnswers));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _answerController.dispose();
    _vsAnimController1.dispose();
    _vsAnimController2.dispose();
    switchBackgroundMusic('menu');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_networkError) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ошибка')),
        body: const Center(child: Text('Не удалось подключиться к серверу')),
      );
    }
    if (_gameData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_state) {
      case 'waiting':
        return _buildWaitingScreen();
      case 'accepted':
        return _buildVsScreen();
      case 'words_select':
        return _buildWordsSelectScreen();
      case 'playing':
        return _buildPlayingScreen();
      case 'finished':
        return _buildResultScreen();
      default:
        return const Scaffold(body: Center(child: Text('Загрузка...')));
    }
  }

  Widget _buildWaitingScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Ожидание соперника')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildVsScreen() {
    final player = PlayerData();
    final opponent = _gameData!;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('VS', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SlideTransition(
              position: _vsOffset1,
              child: _buildPlayerCard(
                player.nickname,
                player.avatarBytes != null ? base64Encode(player.avatarBytes!) : null,
                player.level,
              ),
            ),
            const SizedBox(height: 20),
            SlideTransition(
              position: _vsOffset2,
              child: _buildPlayerCard(
                opponent['opponent_nickname'] ?? 'Противник',
                opponent['opponent_avatar'],
                opponent['opponent_level'] ?? 0,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard(String name, String? avatarBase64, int level) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey,
              backgroundImage: avatarBase64 != null && avatarBase64.isNotEmpty
                  ? MemoryImage(Uint8List.fromList(base64Decode(avatarBase64)))
                  : null,
              child: avatarBase64 == null || avatarBase64.isEmpty
                  ? const Icon(Icons.person, size: 30, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Уровень: $level'),
          ],
        ),
      ),
    );
  }

  Widget _buildWordsSelectScreen() {
    final words9 = List<String>.from(_gameData!['words9'] ?? []);
    return Scaffold(
      appBar: AppBar(title: const Text('Выберите 3 слова для соперника')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                children: words9.map((word) => GestureDetector(
                  onTap: () => _toggleWord(word),
                  child: AnimatedScale(
                    scale: _selectedWords.contains(word) ? 1.05 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Card(
                      color: _selectedWords.contains(word) ? Colors.blue[100] : Colors.white,
                      child: Center(child: Text(word, style: const TextStyle(fontSize: 18))),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _wordsSubmitted ? null : _submitSelectedWords,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
              child: Text('Отправить (${_selectedWords.length}/3)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayingScreen() {
    if (_currentRoundWords.isEmpty) {
      return const Center(child: Text('Ожидание слов соперника...'));
    }
    if (_roundAnswersSubmitted) {
      return _buildWaitingForOpponent();
    }
    final word = _currentRoundWords[_currentWordIndex];
    return Scaffold(
      appBar: AppBar(title: Text('Слово ${_currentWordIndex + 1} из ${_currentRoundWords.length}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(word, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _answerController,
                    decoration: const InputDecoration(labelText: 'Ваш перевод'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56, height: 56,
                  child: ElevatedButton(
                    onPressed: _toggleListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isListening
                        ? const Icon(Icons.more_horiz, color: Colors.white, size: 32)
                        : const Icon(Icons.mic, color: Colors.white, size: 32),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _onNextWord,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
              child: Text(_currentWordIndex < _currentRoundWords.length - 1 ? 'Далее' : 'Отправить все ответы'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForOpponent() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(strokeWidth: 6),
            ),
            const SizedBox(height: 24),
            const Text('Ожидание игрока...', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    // Подсчёт правильных ответов
    int playerCorrect = 0;
    int totalQuestions = 0;
    for (final round in _roundsHistory) {
      if (round.playerAnswers.isEmpty || round.opponentWords.isEmpty) continue;
      for (int i = 0; i < round.opponentWords.length; i++) {
        totalQuestions++;
        final correctRussian = getRussianTranslation(round.opponentWords[i]);
        if (correctRussian != null && round.playerAnswers.length > i) {
          final userAnswer = round.playerAnswers[i].trim().toLowerCase();
          if (userAnswer == correctRussian.toLowerCase()) {
            playerCorrect++;
          }
        }
      }
    }

    // Данные оппонента – заглушка (берём из ответов)
    final opponentAnswers = (_gameData!['opponent_answers'] as List).cast<List>();
    int opponentCorrect = opponentAnswers.length * 3;   // пока без проверки, можно доработать
    final playerTime = (_gameData!['player_time'] as num).toDouble();
    final opponentTime = (_gameData!['opponent_time'] as num).toDouble();
    final opponentNickname = _gameData!['opponent_nickname'] ?? 'Соперник';

    String winner;
    if (playerCorrect > opponentCorrect) {
      winner = 'Вы победили!';
    } else if (opponentCorrect > playerCorrect) {
      winner = '$opponentNickname победил!';
    } else {
      winner = playerTime < opponentTime ? 'Вы победили по времени!' : '$opponentNickname победил по времени!';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Вы', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Правильных: $playerCorrect / $totalQuestions'),
            Text('Время: ${playerTime.toStringAsFixed(1)}с'),
            const SizedBox(height: 20),
            Text(opponentNickname, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Правильных: $opponentCorrect / $totalQuestions'),
            Text('Время: ${opponentTime.toStringAsFixed(1)}с'),
            const SizedBox(height: 40),
            Text(winner, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                playClickSound();
                Navigator.pop(context);
              },
              child: const Text('В главное меню'),
            ),
          ],
        ),
      ),
    );
  }

  String? getRussianTranslation(String english) {
    for (final word in allWords) {
      if (word.english == english) return word.russian;
    }
    return null;
  }
}

class RoundData {
  List<String> opponentWords;
  List<String> playerAnswers = [];
  RoundData({required this.opponentWords});
}