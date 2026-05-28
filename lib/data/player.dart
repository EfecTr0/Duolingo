import 'dart:typed_data';

class WordAttempt {
  final String english;
  final String correctRussian;
  final String? userAnswer;
  final bool isCorrect;
  WordAttempt({
    required this.english,
    required this.correctRussian,
    this.userAnswer,
    required this.isCorrect,
  });
}

class MatchPair {
  final String english;
  final String russian;
  final bool isCorrect;
  MatchPair({required this.english, required this.russian, required this.isCorrect});
}

class RoundDetail {
  final String type; // 'cards' или 'matching'
  final bool success;
  final List<WordAttempt> cardAttempts;
  final List<MatchPair> matchPairs;
  RoundDetail({
    required this.type,
    required this.success,
    this.cardAttempts = const [],
    this.matchPairs = const [],
  });
}

class GameResult {
  final String difficulty;
  final DateTime dateTime;
  final int timeSpentSeconds;
  final int correct;
  final int total;
  final bool bonusAvailable;
  final bool bonusSolved;
  final int experienceEarned;
  final List<WordAttempt> attempts;

  final String? mode; // 'cards', 'matching', 'mixed'
  final List<MatchPair>? matchPairs;
  final List<RoundDetail>? roundDetails;
  final int? cardRoundsSuccess;
  final int? cardRoundsFailed;
  final int? matchRoundsSuccess;
  final int? matchRoundsFailed;

  GameResult({
    required this.difficulty,
    required this.dateTime,
    required this.timeSpentSeconds,
    required this.correct,
    required this.total,
    required this.bonusAvailable,
    required this.bonusSolved,
    required this.experienceEarned,
    required this.attempts,
    this.mode,
    this.matchPairs,
    this.roundDetails,
    this.cardRoundsSuccess,
    this.cardRoundsFailed,
    this.matchRoundsSuccess,
    this.matchRoundsFailed,
  });
}

// ========== КЛАСС ДЛЯ ИЗУЧЕННЫХ СЛОВ (КОЛЛЕКЦИЯ) ==========
class StudiedWord {
  final String english;
  final String russian;
  final String difficulty; // лёгкий, средний, сложный, носитель
  int timesEncountered;     // сколько раз встречалось в играх
  int timesCorrect;         // сколько раз правильно ответили
  DateTime lastSeen;        // когда в последний раз встречалось
  bool isFavorite;          // избранное слово

  StudiedWord({
    required this.english,
    required this.russian,
    required this.difficulty,
    this.timesEncountered = 0,
    this.timesCorrect = 0,
    required this.lastSeen,
    this.isFavorite = false,
  });

  double get successRate => timesEncountered == 0 ? 0 : timesCorrect / timesEncountered;

  Map<String, dynamic> toJson() => {
    'english': english,
    'russian': russian,
    'difficulty': difficulty,
    'timesEncountered': timesEncountered,
    'timesCorrect': timesCorrect,
    'lastSeen': lastSeen.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory StudiedWord.fromJson(Map<String, dynamic> json) => StudiedWord(
    english: json['english'],
    russian: json['russian'],
    difficulty: json['difficulty'],
    timesEncountered: json['timesEncountered'],
    timesCorrect: json['timesCorrect'],
    lastSeen: DateTime.parse(json['lastSeen']),
    isFavorite: json['isFavorite'],
  );
}

class PlayerData {
  static final PlayerData _instance = PlayerData._internal();
  factory PlayerData() => _instance;
  PlayerData._internal();

  int level = 1;
  int experience = 0;
  static const int expPerLevel = 100;

  String nickname = 'Игрок';
  Uint8List? avatarBytes;

  int subscriptions = 0;
  int subscribers = 0;
  List<String> friends = List.generate(5, (i) => 'друн');

  final List<GameResult> history = [];
  
  // Коллекция изученных слов
  final List<StudiedWord> _studiedWords = [];
  List<StudiedWord> get studiedWords => _studiedWords;

  int get experienceForNextLevel => level * expPerLevel;
  int get experienceInCurrentLevel => experience % expPerLevel;
  double get progress => (experienceInCurrentLevel) / expPerLevel;

  void addExperience(int amount) {
    experience += amount;
    level = 1 + (experience ~/ expPerLevel);
  }

  void addGameResult(GameResult result) {
    history.insert(0, result);
  }

  // Добавление или обновление слова в коллекции
  void addOrUpdateWord(String english, String russian, String difficulty, bool wasCorrect) {
    // Ищем существующее слово
    final existingIndex = _studiedWords.indexWhere((w) => w.english == english);
    
    if (existingIndex != -1) {
      // Слово уже есть — обновляем
      final word = _studiedWords[existingIndex];
      word.timesEncountered++;
      if (wasCorrect) word.timesCorrect++;
      word.lastSeen = DateTime.now();
    } else {
      // Новое слово
      _studiedWords.add(StudiedWord(
        english: english,
        russian: russian,
        difficulty: difficulty,
        timesEncountered: 1,
        timesCorrect: wasCorrect ? 1 : 0,
        lastSeen: DateTime.now(),
        isFavorite: false,
      ));
    }
  }

  // Переключение статуса избранного
  void toggleFavorite(String english) {
    final index = _studiedWords.indexWhere((w) => w.english == english);
    if (index != -1) {
      _studiedWords[index].isFavorite = !_studiedWords[index].isFavorite;
    }
  }

  // Получить слово по английскому названию
  StudiedWord? getWordByEnglish(String english) {
    try {
      return _studiedWords.firstWhere((w) => w.english == english);
    } catch (e) {
      return null;
    }
  }

  // Получить количество изученных слов
  int get studiedWordsCount => _studiedWords.length;

  // Получить количество избранных слов
  int get favoriteWordsCount => _studiedWords.where((w) => w.isFavorite).length;

  // Получить слова по уровню сложности
  List<StudiedWord> getWordsByDifficulty(String difficulty) {
    if (difficulty == 'все') {
      return List.from(_studiedWords);
    }
    return _studiedWords.where((w) => w.difficulty == difficulty).toList();
  }

  // Получить слова, требующие повторения (низкий процент успеха)
  List<StudiedWord> getWordsNeedingReview({double threshold = 0.6}) {
    return _studiedWords.where((w) => w.successRate < threshold).toList();
  }

  // Получить недавно изученные слова (последние N дней)
  List<StudiedWord> getRecentWords({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _studiedWords.where((w) => w.lastSeen.isAfter(cutoff)).toList();
  }
}