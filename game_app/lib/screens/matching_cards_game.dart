import 'dart:math';
import 'package:flutter/material.dart';
import '../data/words.dart';

class MatchingCardsGameScreen extends StatefulWidget {
  final String difficulty;
  const MatchingCardsGameScreen({Key? key, required this.difficulty}) : super(key: key);

  @override
  State<MatchingCardsGameScreen> createState() => _MatchingCardsGameScreenState();
}

class _MatchingCardsGameScreenState extends State<MatchingCardsGameScreen> {
  static const int PAIRS_PER_LEVEL = 4; // 4 paires = 8 cartes
  List<Word> allWords = [];
  int currentLevel = 1;
  int totalLevels = 0;
  List<String> leftWords = [];
  List<String> rightWords = [];
  Map<String, String> pairMap = {};
  int? selectedLeftIndex;
  bool isError = false;
  int errorRightIndex = -1;
  int score = 0;
  int totalPairsDone = 0;
  int totalPairs = 0;
  Set<int> matchedLeftIndices = {};
  Set<int> matchedRightIndices = {};
  bool gameFinished = false;

  @override
  void initState() {
    super.initState();
    allWords = getWordsForDifficulty(widget.difficulty);
    // Limite à 40 mots maximum (20 paires) pour éviter la lenteur
    if (allWords.length > 40) allWords = allWords.sublist(0, 40);
    totalPairs = allWords.length;
    totalLevels = (allWords.length / PAIRS_PER_LEVEL).ceil();
    if (totalLevels == 0) {
      gameFinished = true;
    } else {
      _loadLevel(currentLevel);
    }
  }

  void _loadLevel(int level) {
    int startIndex = (level - 1) * PAIRS_PER_LEVEL;
    int endIndex = startIndex + PAIRS_PER_LEVEL;
    if (startIndex >= allWords.length) {
      setState(() => gameFinished = true);
      return;
    }
    if (endIndex > allWords.length) endIndex = allWords.length;
    List<Word> batch = allWords.sublist(startIndex, endIndex);
    leftWords = [];
    rightWords = [];
    pairMap.clear();
    for (var w in batch) {
      leftWords.add(w.english);
      rightWords.add(w.russian);
      pairMap[w.english] = w.russian;
    }
    leftWords.shuffle(Random());
    rightWords.shuffle(Random());
    matchedLeftIndices.clear();
    matchedRightIndices.clear();
    selectedLeftIndex = null;
    setState(() {});
  }

  void _onLeftTap(int index) {
    if (gameFinished) return;
    if (matchedLeftIndices.contains(index)) return;
    setState(() => selectedLeftIndex = index);
  }

  void _onRightTap(int index) {
    if (gameFinished) return;
    if (matchedRightIndices.contains(index)) return;
    if (isError) return;
    if (selectedLeftIndex == null) return;

    String selectedEnglish = leftWords[selectedLeftIndex!];
    String selectedRussian = rightWords[index];
    String expectedRussian = pairMap[selectedEnglish]!;

    if (selectedRussian == expectedRussian) {
      setState(() {
        matchedLeftIndices.add(selectedLeftIndex!);
        matchedRightIndices.add(index);
        score += 10;
        totalPairsDone++;
        selectedLeftIndex = null;
      });
      if (matchedLeftIndices.length == leftWords.length) {
        currentLevel++;
        if (currentLevel <= totalLevels) {
          _loadLevel(currentLevel);
        } else {
          setState(() => gameFinished = true);
        }
      }
    } else {
      setState(() {
        isError = true;
        errorRightIndex = index;
        selectedLeftIndex = null;
      });
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            isError = false;
            errorRightIndex = -1;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (gameFinished) {
      return Scaffold(
        appBar: AppBar(title: Text('Пары слов - завершено')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Игра окончена!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              Text('Твой счёт: $score', style: TextStyle(fontSize: 24)),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Вернуться в меню'),
              ),
            ],
          ),
        ),
      );
    }

    if (leftWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Пары слов')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    String difficultyName;
    switch (widget.difficulty) {
      case 'лёгкий': difficultyName = 'Лёгкий'; break;
      case 'средний': difficultyName = 'Средний'; break;
      case 'сложный': difficultyName = 'Сложный'; break;
      case 'носитель': difficultyName = 'Носитель'; break;
      case 'случайная': difficultyName = 'Случайная'; break;
      default: difficultyName = widget.difficulty;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Пары слов ($difficultyName) – Уровень $currentLevel/$totalLevels'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Счёт: $score', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Пар найдено: $totalPairsDone / $totalPairs', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildColumn(leftWords, matchedLeftIndices, isLeft: true)),
                Expanded(child: _buildColumn(rightWords, matchedRightIndices, isLeft: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(List<String> items, Set<int> matchedIndices, {required bool isLeft}) {
    return ListView.builder(
      padding: EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final isMatched = matchedIndices.contains(idx);
        final isSelected = (isLeft && selectedLeftIndex == idx);
        final isErrorRight = (!isLeft && isError && errorRightIndex == idx);
        Color bgColor;
        if (isMatched) bgColor = Colors.green;
        else if (isErrorRight) bgColor = Colors.red;
        else if (isSelected) bgColor = Colors.orange;
        else bgColor = Colors.amber;
        return GestureDetector(
          onTap: () {
            if (isLeft) _onLeftTap(idx);
            else _onRightTap(idx);
          },
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))],
            ),
            child: Center(
              child: Text(
                isMatched ? '✓' : items[idx],
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}